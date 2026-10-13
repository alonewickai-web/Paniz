import { Injectable, Logger } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { createHash } from "node:crypto";
import webPush from "web-push";
import { PrismaService } from "../database/prisma.service";

@Injectable()
export class WebPushService {
  private readonly logger = new Logger(WebPushService.name);

  constructor(private readonly prisma: PrismaService, private readonly config: ConfigService) {}

  publicKey(): string | null {
    const key = this.config.get<string>("WEB_PUSH_VAPID_PUBLIC_KEY")?.trim();
    return key || null;
  }

  async saveSubscription(customerId: bigint, subscription: { endpoint: string; keys: { p256dh: string; auth: string } }) {
    const endpoint = subscription.endpoint.trim();
    let parsed: URL;
    try { parsed = new URL(endpoint); } catch { throw new Error("نشانی اعلان معتبر نیست."); }
    if (parsed.protocol !== "https:" || endpoint.length > 2048) throw new Error("نشانی امن اعلان معتبر نیست.");
    const endpointHash = createHash("sha256").update(endpoint).digest("hex");
    await this.prisma.customerWebPushSubscription.upsert({
      where: { endpointHash },
      create: { customerId, endpoint, endpointHash, p256dh: subscription.keys.p256dh, auth: subscription.keys.auth },
      update: { customerId, endpoint, p256dh: subscription.keys.p256dh, auth: subscription.keys.auth },
    });
    return { enabled: Boolean(this.publicKey()) };
  }

  async removeSubscription(customerId: bigint, endpoint: string) {
    await this.prisma.customerWebPushSubscription.deleteMany({ where: { customerId, endpoint } });
  }

  async notifyCustomer(customerId: bigint, title: string, body: string, url = "/account") {
    await this.send(await this.prisma.customerWebPushSubscription.findMany({ where: { customerId } }), { title, body, url });
  }

  async notifyVariantSubscribers(variantId: bigint, productName: string) {
    const subscribers = await this.prisma.backInStockSubscription.findMany({
      where: { variantId, notifiedAt: null }, select: { customerId: true },
    });
    await Promise.all(subscribers.map(async ({ customerId }) => {
      await this.notifyCustomer(customerId, "محصول دوباره موجود شد", `«${productName}» دوباره در فروشگاه موجود است.`, "/products");
    }));
    if (subscribers.length) await this.prisma.backInStockSubscription.updateMany({
      where: { variantId, notifiedAt: null }, data: { notifiedAt: new Date() },
    });
  }

  async notifyMarketingCustomers(title: string, body: string, url = "/") {
    const subscriptions = await this.prisma.customerWebPushSubscription.findMany({ where: { customer: { marketingOptIn: true } } });
    await this.send(subscriptions, { title, body, url });
  }

  private async send(subscriptions: Array<{ id: bigint; endpoint: string; p256dh: string; auth: string }>, payload: { title: string; body: string; url: string }) {
    const publicKey = this.config.get<string>("WEB_PUSH_VAPID_PUBLIC_KEY")?.trim();
    const privateKey = this.config.get<string>("WEB_PUSH_VAPID_PRIVATE_KEY")?.trim();
    const subject = this.config.get<string>("WEB_PUSH_SUBJECT")?.trim() || "mailto:support@panizstyle.ir";
    if (!publicKey || !privateKey || !subscriptions.length) return;
    webPush.setVapidDetails(subject, publicKey, privateKey);
    await Promise.all(subscriptions.map(async (subscription) => {
      try {
        await webPush.sendNotification({ endpoint: subscription.endpoint, keys: { p256dh: subscription.p256dh, auth: subscription.auth } }, JSON.stringify(payload), { TTL: 60 * 60 });
      } catch (error) {
        const status = (error as { statusCode?: number }).statusCode;
        if (status === 404 || status === 410) await this.prisma.customerWebPushSubscription.deleteMany({ where: { id: subscription.id } });
        else this.logger.warn(`Customer web push delivery failed (HTTP ${status ?? "unknown"}).`);
      }
    }));
  }
}
