import { Injectable, Logger, OnModuleInit } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { PrismaService } from "../database/prisma.service";

type PushPayload = {
  title: string;
  body: string;
  type: string;
  entityType?: string;
  entityId?: bigint;
};

@Injectable()
export class FirebasePushService implements OnModuleInit {
  private readonly logger = new Logger(FirebasePushService.name);
  private messaging: import("firebase-admin/messaging").Messaging | null = null;

  constructor(
    private readonly config: ConfigService,
    private readonly prisma: PrismaService,
  ) {}

  async onModuleInit() {
    const encoded = this.config.get<string>("FIREBASE_SERVICE_ACCOUNT_BASE64")?.trim();
    if (!encoded) {
      this.logger.warn("Firebase push is disabled until FIREBASE_SERVICE_ACCOUNT_BASE64 is configured.");
      return;
    }

    try {
      const serviceAccount = JSON.parse(Buffer.from(encoded, "base64").toString("utf8")) as {
        project_id?: string;
        client_email?: string;
        private_key?: string;
      };
      if (!serviceAccount.project_id || !serviceAccount.client_email || !serviceAccount.private_key) {
        throw new Error("Firebase service account fields are incomplete.");
      }
      const { cert, getApps, initializeApp } = await import("firebase-admin/app");
      const { getMessaging } = await import("firebase-admin/messaging");
      const existing = getApps().find((app) => app.name === "panizstyle-admin-push");
      const app = existing ?? initializeApp({
        credential: cert({
          projectId: serviceAccount.project_id,
          clientEmail: serviceAccount.client_email,
          privateKey: serviceAccount.private_key,
        }),
      }, "panizstyle-admin-push");
      this.messaging = getMessaging(app);
      this.logger.log("Firebase push is ready.");
    } catch {
      this.logger.error("Firebase push could not be initialized; check the private service account setting.");
    }
  }

  async sendToOwners(payload: PushPayload) {
    if (!this.messaging) return;
    try {
      const devices = await this.prisma.adminPushDevice.findMany({
        where: { admin: { role: "owner", isActive: true } },
        select: { token: true },
      });
      if (!devices.length) return;

      const data: Record<string, string> = { type: payload.type };
      if (payload.entityType) data.entityType = payload.entityType;
      if (payload.entityId !== undefined) data.entityId = payload.entityId.toString();

      for (let offset = 0; offset < devices.length; offset += 500) {
        const batch = devices.slice(offset, offset + 500);
        try {
          const result = await this.messaging.sendEachForMulticast({
            tokens: batch.map((device) => device.token),
            notification: {
              title: payload.title,
              body: payload.type === "new_order"
                ? "یک سفارش تازه ثبت شده است؛ برای جزئیات برنامه را باز کنید."
                : payload.type === "rubika_message"
                  ? "پیام تازه‌ای در روبیکا دریافت شد؛ برای جزئیات برنامه را باز کنید."
                  : "پیام تازه‌ای از سایت رسیده است؛ برای جزئیات برنامه را باز کنید.",
            },
            data,
            android: { priority: "high", notification: { channelId: "paniz_admin_alerts" } },
          });
          const invalidTokens = result.responses.flatMap((response, index) =>
            !response.success && response.error && [
              "messaging/invalid-registration-token",
              "messaging/registration-token-not-registered",
            ].includes(response.error.code)
              ? [batch[index].token]
              : [],
          );
          if (invalidTokens.length) {
            await this.prisma.adminPushDevice.deleteMany({ where: { token: { in: invalidTokens } } });
          }
          if (result.failureCount) {
            this.logger.warn(`Firebase rejected ${result.failureCount} admin push message(s).`);
          }
        } catch {
          this.logger.warn("Firebase push delivery failed; the in-app notification remains saved.");
        }
      }
    } catch {
      this.logger.warn("Firebase push delivery failed; the in-app notification remains saved.");
    }
  }
}
