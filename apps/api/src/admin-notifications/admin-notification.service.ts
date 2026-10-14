import { BadRequestException, ConflictException, Injectable } from "@nestjs/common";
import { createHash, randomBytes } from "node:crypto";
import { Prisma } from "@prisma/client";
import { PrismaService } from "../database/prisma.service";
import { AuthenticatedAdmin } from "../admin-auth/admin-session.guard";
import { RegisterNotificationDeviceDto } from "./dto/register-notification-device.dto";
import { UpdateNotificationPreferencesDto } from "./dto/update-notification-preferences.dto";

export type AdminNotificationInput = {
  type: "new_order" | "rubika_message" | "customer_message" | "app_update" | "admin_message" |
    "payment_success" | "payment_failed" | "low_stock" | "security_alert" | "server_alert";
  title: string;
  body: string;
  entityType?: string;
  entityId?: bigint;
  externalRef?: string;
  dedupeKey?: string;
};

const preferenceForType: Record<AdminNotificationInput["type"], string> = {
  new_order: "newOrdersEnabled",
  payment_success: "paymentsEnabled",
  payment_failed: "paymentsEnabled",
  low_stock: "lowStockEnabled",
  security_alert: "securityAlertsEnabled",
  server_alert: "serverAlertsEnabled",
  customer_message: "customerMessagesEnabled",
  rubika_message: "customerMessagesEnabled",
  admin_message: "adminMessagesEnabled",
  app_update: "appUpdatesEnabled",
};

const preferenceDefaults = {
  newOrdersEnabled: true,
  paymentsEnabled: true,
  lowStockEnabled: true,
  securityAlertsEnabled: true,
  serverAlertsEnabled: true,
  customerMessagesEnabled: true,
  adminMessagesEnabled: true,
  appUpdatesEnabled: true,
  soundEnabled: false,
  vibrationEnabled: true,
  backgroundMonitoringEnabled: false,
};

@Injectable()
export class AdminNotificationService {
  constructor(private readonly prisma: PrismaService) {}

  async createForOwners(tx: Prisma.TransactionClient, input: AdminNotificationInput) {
    const owners = await tx.adminUser.findMany({
      where: { role: "owner", isActive: true },
      select: { id: true, notificationPreferences: true },
    });
    const recipients = owners.filter((owner) => preferenceEnabled(owner.notificationPreferences, input.type));
    if (!recipients.length) return;
    await tx.adminNotification.createMany({
      data: recipients.map((owner) => notificationData(owner.id, input)),
      skipDuplicates: true,
    });
  }

  async notifyOwners(input: AdminNotificationInput) {
    await this.prisma.$transaction((tx) => this.createForOwners(tx, input));
  }

  async notifyAdmins(input: AdminNotificationInput) {
    await this.prisma.$transaction(async (tx) => {
      const admins = await tx.adminUser.findMany({ where: { isActive: true }, select: { id: true, notificationPreferences: true } });
      const recipients = admins.filter((admin) => preferenceEnabled(admin.notificationPreferences, input.type));
      if (!recipients.length) return;
      await tx.adminNotification.createMany({ data: recipients.map((admin) => notificationData(admin.id, input)), skipDuplicates: true });
    });
  }

  async notifyAdmin(adminId: bigint, input: AdminNotificationInput) {
    await this.prisma.$transaction(async (tx) => {
      const admin = await tx.adminUser.findUnique({ where: { id: adminId }, select: { notificationPreferences: true, isActive: true } });
      if (!admin?.isActive || !preferenceEnabled(admin.notificationPreferences, input.type)) return;
      await tx.adminNotification.createMany({ data: [notificationData(adminId, input)], skipDuplicates: true });
    });
  }

  async list(admin: AuthenticatedAdmin, pageValue?: string, pageSizeValue?: string) {
    const page = boundedInteger(pageValue, 1, 1_000_000, 1);
    const pageSize = boundedInteger(pageSizeValue, 1, 50, 30);
    const where = { adminId: admin.id };
    const [rows, total, unreadCount] = await Promise.all([
      this.prisma.adminNotification.findMany({ where, orderBy: [{ createdAt: "desc" }, { id: "desc" }], skip: (page - 1) * pageSize, take: pageSize }),
      this.prisma.adminNotification.count({ where }),
      this.prisma.adminNotification.count({ where: { ...where, readAt: null } }),
    ]);
    return { data: rows.map(serializeNotification), unreadCount, pagination: { page, pageSize, total, totalPages: Math.ceil(total / pageSize) } };
  }

  async unreadCount(admin: AuthenticatedAdmin) {
    return { data: { count: await this.prisma.adminNotification.count({ where: { adminId: admin.id, readAt: null } }) } };
  }

  async markRead(admin: AuthenticatedAdmin, value: string) {
    const id = parseId(value);
    const result = await this.prisma.adminNotification.updateMany({ where: { id, adminId: admin.id, readAt: null }, data: { readAt: new Date() } });
    return { data: { updated: result.count } };
  }

  async markAllRead(admin: AuthenticatedAdmin) {
    const result = await this.prisma.adminNotification.updateMany({ where: { adminId: admin.id, readAt: null }, data: { readAt: new Date() } });
    return { data: { updated: result.count } };
  }

  async getPreferences(admin: AuthenticatedAdmin) {
    const preferences = await this.prisma.adminNotificationPreference.upsert({
      where: { adminId: admin.id }, create: { adminId: admin.id }, update: {},
    });
    return { data: serializePreferences(preferences as unknown as Record<string, unknown>) };
  }

  async updatePreferences(admin: AuthenticatedAdmin, input: UpdateNotificationPreferencesDto) {
    const preferences = await this.prisma.adminNotificationPreference.upsert({
      where: { adminId: admin.id }, create: { adminId: admin.id, ...input }, update: input,
    });
    return { data: serializePreferences(preferences as unknown as Record<string, unknown>) };
  }

  async registerDevice(admin: AuthenticatedAdmin, sessionId: bigint, input: RegisterNotificationDeviceDto) {
    const deviceId = normalizeDeviceId(input.deviceId);
    const latest = await this.prisma.adminNotification.findFirst({ where: { adminId: admin.id }, orderBy: { id: "desc" }, select: { id: true } });
    const device = await this.prisma.$transaction(async (tx) => {
      await tx.adminNotificationPreference.upsert({ where: { adminId: admin.id }, create: { adminId: admin.id }, update: {} });
      return tx.adminNotificationDevice.upsert({
        where: { adminId_deviceId: { adminId: admin.id, deviceId } },
        create: {
          adminId: admin.id, sessionId, deviceId,
          deviceName: normalizeDeviceName(input.deviceName),
          lastSeenAt: new Date(), lastNotificationId: latest?.id ?? 0n,
        },
        update: { sessionId, deviceName: normalizeDeviceName(input.deviceName), lastSeenAt: new Date(), revokedAt: null },
      });
    });
    return { data: serializeDevice(device) };
  }

  async listDevices(admin: AuthenticatedAdmin) {
    const rows = await this.prisma.adminNotificationDevice.findMany({ where: { adminId: admin.id }, orderBy: { updatedAt: "desc" } });
    return { data: rows.map(serializeDevice) };
  }

  async revokeDevice(admin: AuthenticatedAdmin, value: string) {
    const deviceId = normalizeDeviceId(value);
    const result = await this.prisma.adminNotificationDevice.updateMany({
      where: { adminId: admin.id, deviceId, revokedAt: null },
      data: { revokedAt: new Date() },
    });
    return { data: { revoked: result.count > 0 } };
  }

  async createSocketTicket(admin: AuthenticatedAdmin, sessionId: bigint, value: string) {
    const deviceId = normalizeDeviceId(value);
    const [device, preferences] = await Promise.all([
      this.prisma.adminNotificationDevice.findFirst({ where: { adminId: admin.id, deviceId, revokedAt: null, sessionId } }),
      this.prisma.adminNotificationPreference.findUnique({ where: { adminId: admin.id } }),
    ]);
    if (!device) throw new ConflictException({ code: "NOTIFICATION_DEVICE_NOT_REGISTERED", message: "دستگاه اعلان ثبت نشده است." });
    if (!preferences?.backgroundMonitoringEnabled) throw new ConflictException({ code: "BACKGROUND_MONITORING_DISABLED", message: "مانیتورینگ پس‌زمینه فعال نیست." });
    const token = randomBytes(32).toString("base64url");
    const now = new Date();
    const expiresAt = new Date(now.getTime() + 60_000);
    await this.prisma.adminNotificationSocketTicket.deleteMany({ where: { expiresAt: { lt: now } } });
    await this.prisma.adminNotificationSocketTicket.create({
      data: { adminId: admin.id, deviceId: device.id, sessionId, tokenHash: hashTicket(token), expiresAt },
    });
    await this.prisma.adminNotificationDevice.update({ where: { id: device.id }, data: { lastSeenAt: new Date() } });
    return { data: { ticket: token, expiresAt: expiresAt.toISOString() } };
  }

  async consumeSocketTicket(token: string) {
    if (token.length < 32 || token.length > 128) return null;
    const ticket = await this.prisma.adminNotificationSocketTicket.findUnique({
      where: { tokenHash: hashTicket(token) },
      include: { admin: { include: { notificationPreferences: true } }, device: true, session: true },
    });
    const now = new Date();
    if (
      !ticket || ticket.consumedAt || ticket.expiresAt <= now || ticket.device.revokedAt ||
      ticket.device.sessionId !== ticket.sessionId || ticket.session.adminId !== ticket.adminId ||
      ticket.session.revokedAt || ticket.session.expiresAt <= now || !ticket.admin.isActive ||
      ticket.admin.notificationPreferences?.backgroundMonitoringEnabled !== true
    ) return null;
    const consumed = await this.prisma.adminNotificationSocketTicket.updateMany({
      where: { id: ticket.id, consumedAt: null, expiresAt: { gt: now } }, data: { consumedAt: now },
    });
    if (!consumed.count) return null;
    return { adminId: ticket.adminId, deviceId: ticket.deviceId, sessionId: ticket.sessionId };
  }

  async syncDevice(admin: AuthenticatedAdmin, value: string, limitValue?: string) {
    const deviceId = normalizeDeviceId(value);
    const device = await this.prisma.adminNotificationDevice.findFirst({ where: { adminId: admin.id, deviceId, revokedAt: null } });
    if (!device) throw new ConflictException({ code: "NOTIFICATION_DEVICE_NOT_REGISTERED", message: "دستگاه اعلان ثبت نشده است." });
    const limit = boundedInteger(limitValue, 1, 100, 50);
    const rows = await this.prisma.adminNotification.findMany({
      where: { adminId: admin.id, id: { gt: device.lastNotificationId } },
      orderBy: { id: "asc" }, take: limit,
    });
    if (rows.length) {
      const now = new Date();
      await this.prisma.$transaction(async (tx) => {
        for (const row of rows) {
          await tx.adminNotificationDelivery.upsert({
            where: { notificationId_deviceId: { notificationId: row.id, deviceId: device.id } },
            create: { notificationId: row.id, deviceId: device.id, status: "sent", attempts: 1, lastAttemptAt: now },
            update: { attempts: { increment: 1 }, lastAttemptAt: now, status: "sent" },
          });
        }
      });
    }
    const unreadCount = await this.prisma.adminNotification.count({ where: { adminId: admin.id, readAt: null } });
    return { data: rows.map(serializeNotification), cursor: device.lastNotificationId.toString(), unreadCount };
  }

  async acknowledge(admin: AuthenticatedAdmin, idValue: string, deviceValue: string) {
    const id = parseId(idValue);
    const deviceId = normalizeDeviceId(deviceValue);
    const [device, notification] = await Promise.all([
      this.prisma.adminNotificationDevice.findFirst({ where: { adminId: admin.id, deviceId, revokedAt: null } }),
      this.prisma.adminNotification.findFirst({ where: { id, adminId: admin.id }, select: { id: true } }),
    ]);
    if (!device || !notification) throw new BadRequestException({ code: "NOTIFICATION_NOT_FOUND", message: "اعلان یا دستگاه پیدا نشد." });
    const now = new Date();
    await this.prisma.$transaction(async (tx) => {
      await tx.adminNotificationDelivery.upsert({
        where: { notificationId_deviceId: { notificationId: id, deviceId: device.id } },
        create: { notificationId: id, deviceId: device.id, status: "acknowledged", deliveredAt: now, lastAttemptAt: now },
        update: { status: "acknowledged", deliveredAt: now, lastAttemptAt: now },
      });
      await tx.adminNotificationDevice.updateMany({ where: { id: device.id, lastNotificationId: { lt: id } }, data: { lastNotificationId: id, lastSeenAt: now } });
    });
    return { data: { acknowledged: true } };
  }
}

function notificationData(adminId: bigint, input: AdminNotificationInput) {
  return {
    adminId, type: input.type, title: input.title.slice(0, 160), body: input.body.slice(0, 500),
    entityType: input.entityType?.slice(0, 48) ?? null, entityId: input.entityId ?? null,
    externalRef: input.externalRef?.slice(0, 128) ?? null,
    dedupeKey: input.dedupeKey ? `${input.dedupeKey}:admin:${adminId}`.slice(0, 160) : null,
  };
}

function preferenceEnabled(preference: unknown, type: AdminNotificationInput["type"]) {
  if (!preference || typeof preference !== "object") return true;
  return (preference as Record<string, unknown>)[preferenceForType[type]] !== false;
}

function serializePreferences(row: Record<string, unknown>) {
  const result: Record<string, unknown> = {};
  for (const key of Object.keys(preferenceDefaults)) result[key] = row[key] ?? preferenceDefaults[key as keyof typeof preferenceDefaults];
  return result;
}

function normalizeDeviceId(value: string) {
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value)) {
    throw new BadRequestException({ code: "INVALID_NOTIFICATION_DEVICE", message: "شناسه دستگاه معتبر نیست." });
  }
  return value.toLowerCase();
}

function normalizeDeviceName(value?: string) {
  const name = value?.trim().replace(/[\u0000-\u001f]/g, "").slice(0, 120);
  return name || "مدیر اندروید";
}

function boundedInteger(value: string | undefined, min: number, max: number, fallback: number) {
  if (value === undefined || value === "") return fallback;
  const parsed = Number(value);
  return Number.isInteger(parsed) && parsed >= min && parsed <= max ? parsed : fallback;
}

function parseId(value: string): bigint {
  if (!/^\d{1,20}$/.test(value) || BigInt(value) < 1n) throw new BadRequestException({ code: "NOTIFICATION_NOT_FOUND", message: "اعلان پیدا نشد." });
  return BigInt(value);
}

function hashTicket(token: string) { return createHash("sha256").update(token).digest("hex"); }

function serializeDevice(row: { id: bigint; deviceId: string; deviceName: string; platform: string; lastSeenAt: Date | null; revokedAt: Date | null; lastNotificationId: bigint; updatedAt: Date }) {
  return { id: row.id.toString(), deviceId: row.deviceId, deviceName: row.deviceName, platform: row.platform,
    lastSeenAt: row.lastSeenAt?.toISOString() ?? null, revokedAt: row.revokedAt?.toISOString() ?? null,
    lastNotificationId: row.lastNotificationId.toString(), updatedAt: row.updatedAt.toISOString() };
}

function serializeNotification(row: { id: bigint; type: string; title: string; body: string; entityType: string | null; entityId: bigint | null; externalRef: string | null; readAt: Date | null; createdAt: Date }) {
  return { id: row.id.toString(), type: row.type, title: row.title, body: row.body, entityType: row.entityType,
    entityId: row.entityId?.toString() ?? null, externalRef: row.externalRef, readAt: row.readAt?.toISOString() ?? null, createdAt: row.createdAt.toISOString() };
}
