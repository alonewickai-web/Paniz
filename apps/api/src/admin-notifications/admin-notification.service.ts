import { ForbiddenException, Injectable } from "@nestjs/common";
import { Prisma } from "@prisma/client";
import { PrismaService } from "../database/prisma.service";
import { AuthenticatedAdmin } from "../admin-auth/admin-session.guard";

export type AdminNotificationInput = {
  type: "new_order" | "rubika_message" | "customer_message";
  title: string;
  body: string;
  entityType?: string;
  entityId?: bigint;
  externalRef?: string;
  dedupeKey?: string;
};

@Injectable()
export class AdminNotificationService {
  constructor(
    private readonly prisma: PrismaService,
  ) {}

  async createForOwners(tx: Prisma.TransactionClient, input: AdminNotificationInput) {
    const owners = await tx.adminUser.findMany({
      where: { role: "owner", isActive: true },
      select: { id: true },
    });
    if (!owners.length) return;

    await tx.adminNotification.createMany({
      data: owners.map((owner) => ({
        adminId: owner.id,
        type: input.type,
        title: input.title,
        body: input.body.slice(0, 500),
        entityType: input.entityType ?? null,
        entityId: input.entityId ?? null,
        externalRef: input.externalRef?.slice(0, 128) ?? null,
        dedupeKey: input.dedupeKey ? `${input.dedupeKey}:admin:${owner.id}`.slice(0, 160) : null,
      })),
      skipDuplicates: true,
    });
  }

  async notifyOwners(input: AdminNotificationInput) {
    await this.prisma.$transaction((tx) => this.createForOwners(tx, input));
  }

  async list(admin: AuthenticatedAdmin, pageValue?: string, pageSizeValue?: string) {
    this.requireOwner(admin);
    const page = boundedInteger(pageValue, 1, 1_000_000, 1);
    const pageSize = boundedInteger(pageSizeValue, 1, 50, 30);
    const where = { adminId: admin.id };
    const [rows, total, unreadCount] = await Promise.all([
      this.prisma.adminNotification.findMany({
        where,
        orderBy: [{ createdAt: "desc" }, { id: "desc" }],
        skip: (page - 1) * pageSize,
        take: pageSize,
      }),
      this.prisma.adminNotification.count({ where }),
      this.prisma.adminNotification.count({ where: { ...where, readAt: null } }),
    ]);
    return {
      data: rows.map(serializeNotification),
      unreadCount,
      pagination: { page, pageSize, total, totalPages: Math.ceil(total / pageSize) },
    };
  }

  async markRead(admin: AuthenticatedAdmin, value: string) {
    this.requireOwner(admin);
    const id = parseId(value);
    const result = await this.prisma.adminNotification.updateMany({
      where: { id, adminId: admin.id, readAt: null },
      data: { readAt: new Date() },
    });
    return { data: { updated: result.count } };
  }

  async markAllRead(admin: AuthenticatedAdmin) {
    this.requireOwner(admin);
    const result = await this.prisma.adminNotification.updateMany({
      where: { adminId: admin.id, readAt: null },
      data: { readAt: new Date() },
    });
    return { data: { updated: result.count } };
  }

  private requireOwner(admin: AuthenticatedAdmin) {
    if (admin.role !== "owner") {
      throw new ForbiddenException({
        code: "SUPER_ADMIN_REQUIRED",
        message: "اعلان‌های سیستمی فقط برای سوپرادمین در دسترس است.",
      });
    }
  }
}

function boundedInteger(value: string | undefined, min: number, max: number, fallback: number) {
  if (value === undefined || value === "") return fallback;
  const parsed = Number(value);
  return Number.isInteger(parsed) && parsed >= min && parsed <= max ? parsed : fallback;
}

function parseId(value: string): bigint {
  if (!/^\d{1,20}$/.test(value) || BigInt(value) < 1n) {
    throw new ForbiddenException({ code: "NOTIFICATION_NOT_FOUND", message: "اعلان پیدا نشد." });
  }
  return BigInt(value);
}

function serializeNotification(row: {
  id: bigint;
  type: string;
  title: string;
  body: string;
  entityType: string | null;
  entityId: bigint | null;
  externalRef: string | null;
  readAt: Date | null;
  createdAt: Date;
}) {
  return {
    id: row.id.toString(),
    type: row.type,
    title: row.title,
    body: row.body,
    entityType: row.entityType,
    entityId: row.entityId?.toString() ?? null,
    externalRef: row.externalRef,
    readAt: row.readAt?.toISOString() ?? null,
    createdAt: row.createdAt.toISOString(),
  };
}
