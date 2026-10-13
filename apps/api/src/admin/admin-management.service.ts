import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { Prisma } from "@prisma/client";
import { randomBytes } from "node:crypto";
import * as argon2 from "argon2";
import { ALL_ADMIN_PERMISSION_KEYS, hasAdminPermission, requireAdminPermission, serializePermissionGroups } from "../admin-auth/admin-permissions";
import { AuthenticatedAdmin } from "../admin-auth/admin-session.guard";
import { PrismaService } from "../database/prisma.service";
import { CreateAdminStaffDto } from "./dto/create-admin-staff.dto";
import { UpdateAdminStaffDto } from "./dto/update-admin-staff.dto";

const permissionKeys = new Set<string>(ALL_ADMIN_PERMISSION_KEYS);
const managedRoles = new Set(["owner", "admin"]);

@Injectable()
export class AdminManagementService {
  constructor(private readonly prisma: PrismaService) {}

  permissionCatalog() {
    return { data: serializePermissionGroups() };
  }

  async listStaff(admin: AuthenticatedAdmin, query: Record<string, string | undefined>) {
    requireAdminPermission(admin, "staff.manage");
    const page = boundedInt(query.page, 1, 1, 10_000);
    const pageSize = boundedInt(query.pageSize, 30, 1, 100);
    const search = query.q?.trim();
    const activeFilter = query.active === "true" ? true : query.active === "false" ? false : undefined;
    const where: Prisma.AdminUserWhereInput = {
      role: { not: "owner" },
      ...(activeFilter === undefined ? {} : { isActive: activeFilter }),
      ...(search ? { OR: [{ fullName: { contains: search } }, { username: { contains: search } }, { phone: { contains: search } }] } : {}),
    };
    const [rows, total] = await Promise.all([
      this.prisma.adminUser.findMany({
        where,
        orderBy: [{ isActive: "desc" }, { lastLoginAt: "desc" }, { createdAt: "desc" }],
        skip: (page - 1) * pageSize,
        take: pageSize,
        include: { permissions: true },
      }),
      this.prisma.adminUser.count({ where }),
    ]);
    const ids = rows.map((row) => row.id);
    const latestActions = ids.length
      ? await this.prisma.adminAuditLog.groupBy({
          by: ["adminId"],
          where: { adminId: { in: ids } },
          _max: { createdAt: true },
        })
      : [];
    const lastActionById = new Map(latestActions.map((item) => [item.adminId?.toString() ?? "", item._max.createdAt]));
    return {
      data: rows.map((row) => this.toStaff(row, lastActionById.get(row.id.toString()) ?? row.lastLoginAt)),
      meta: { page, pageSize, total, pageCount: Math.ceil(total / pageSize) },
    };
  }

  async getStaff(admin: AuthenticatedAdmin, idText: string) {
    requireAdminPermission(admin, "staff.manage");
    const id = parseId(idText);
    const staff = await this.prisma.adminUser.findUnique({ where: { id }, include: { permissions: true } });
    if (!staff || staff.role === "owner") throw new NotFoundException({ code: "ADMIN_STAFF_NOT_FOUND", message: "حساب کارمند پیدا نشد." });
    return { data: this.toStaff(staff, staff.lastLoginAt) };
  }

  async createStaff(admin: AuthenticatedAdmin, input: CreateAdminStaffDto) {
    requireAdminPermission(admin, "staff.manage");
    this.ensureCanGrant(admin, input.permissions);
    const username = normalizeUsername(input.username);
    const fullName = input.fullName.trim();
    const phone = input.phone?.trim() || null;
    const temporaryPassword = randomBytes(15).toString("base64url");
    const passwordHash = await argon2.hash(temporaryPassword, { type: argon2.argon2id, memoryCost: 65_536, timeCost: 3, parallelism: 1 });

    try {
      const staff = await this.prisma.$transaction(async (tx) => {
        const created = await tx.adminUser.create({
          data: { fullName, username, phone, passwordHash, role: "staff", isActive: true, mustChangePassword: true },
        });
        if (input.permissions.length) {
          await tx.adminUserPermission.createMany({
            data: input.permissions.map((permissionKey) => ({ adminId: created.id, permissionKey, grantedByAdminId: admin.id })),
          });
        }
        await tx.adminAuditLog.create({
          data: {
            adminId: admin.id,
            action: "admin.staff_created",
            entityType: "admin_user",
            entityId: created.id,
            details: { username, permissions: [...input.permissions] },
          },
        });
        return tx.adminUser.findUniqueOrThrow({ where: { id: created.id }, include: { permissions: true } });
      });
      return { data: { staff: this.toStaff(staff, staff.lastLoginAt), temporaryPassword } };
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === "P2002") {
        throw new ConflictException({ code: "ADMIN_STAFF_IDENTITY_TAKEN", message: "نام کاربری یا شمارهٔ تماس قبلاً استفاده شده است." });
      }
      throw error;
    }
  }

  async updateStaff(admin: AuthenticatedAdmin, idText: string, input: UpdateAdminStaffDto) {
    requireAdminPermission(admin, "staff.manage");
    const id = parseId(idText);
    if (id === admin.id) throw new ForbiddenException({ code: "ADMIN_SELF_PERMISSION_CHANGE_BLOCKED", message: "برای امنیت، تغییر دسترسی یا غیرفعال‌کردن حساب خودتان مجاز نیست." });
    const current = await this.prisma.adminUser.findUnique({ where: { id }, include: { permissions: true } });
    if (!current || current.role !== "staff") throw new NotFoundException({ code: "ADMIN_STAFF_NOT_FOUND", message: "حساب کارمند پیدا نشد." });
    if (input.permissions) this.ensureCanGrant(admin, input.permissions);
    const fullName = input.fullName?.trim();
    const phone = input.phone === undefined ? undefined : input.phone?.trim() || null;

    try {
      const staff = await this.prisma.$transaction(async (tx) => {
        const updated = await tx.adminUser.update({
          where: { id },
          data: {
            ...(fullName ? { fullName } : {}),
            ...(phone !== undefined ? { phone } : {}),
            ...(input.isActive !== undefined ? { isActive: input.isActive } : {}),
          },
        });
        if (input.permissions) {
          await tx.adminUserPermission.deleteMany({ where: { adminId: id } });
          if (input.permissions.length) {
            await tx.adminUserPermission.createMany({
              data: input.permissions.map((permissionKey) => ({ adminId: id, permissionKey, grantedByAdminId: admin.id })),
            });
          }
        }
        const revoked = input.isActive === false || input.permissions !== undefined
          ? await tx.adminSession.updateMany({ where: { adminId: id, revokedAt: null }, data: { revokedAt: new Date() } })
          : { count: 0 };
        await tx.adminAuditLog.create({
          data: {
            adminId: admin.id,
            action: input.isActive === false ? "admin.staff_deactivated" : input.permissions ? "admin.permissions_changed" : "admin.staff_updated",
            entityType: "admin_user",
            entityId: id,
            details: {
              changedFields: [
                ...(fullName ? ["fullName"] : []),
                ...(phone !== undefined ? ["phone"] : []),
                ...(input.isActive !== undefined ? ["isActive"] : []),
                ...(input.permissions ? ["permissions"] : []),
              ],
              previousActive: current.isActive,
              isActive: updated.isActive,
              previousPermissions: current.permissions.map((item) => item.permissionKey),
              permissions: input.permissions ?? current.permissions.map((item) => item.permissionKey),
              sessionsRevoked: revoked.count,
            },
          },
        });
        return tx.adminUser.findUniqueOrThrow({ where: { id }, include: { permissions: true } });
      });
      return { data: this.toStaff(staff, staff.lastLoginAt) };
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === "P2002") {
        throw new ConflictException({ code: "ADMIN_STAFF_IDENTITY_TAKEN", message: "شمارهٔ تماس قبلاً استفاده شده است." });
      }
      throw error;
    }
  }

  async resetStaffPassword(admin: AuthenticatedAdmin, idText: string) {
    requireAdminPermission(admin, "staff.manage");
    const id = parseId(idText);
    if (id === admin.id) throw new ForbiddenException({ code: "ADMIN_SELF_RESET_BLOCKED", message: "برای تغییر گذرواژهٔ خودتان از تنظیمات حساب استفاده کنید." });
    const staff = await this.prisma.adminUser.findUnique({ where: { id } });
    if (!staff || staff.role !== "staff") throw new NotFoundException({ code: "ADMIN_STAFF_NOT_FOUND", message: "حساب کارمند پیدا نشد." });
    const temporaryPassword = randomBytes(15).toString("base64url");
    const passwordHash = await argon2.hash(temporaryPassword, { type: argon2.argon2id, memoryCost: 65_536, timeCost: 3, parallelism: 1 });
    await this.prisma.$transaction([
      this.prisma.adminUser.update({ where: { id }, data: { passwordHash, mustChangePassword: true } }),
      this.prisma.adminSession.updateMany({ where: { adminId: id, revokedAt: null }, data: { revokedAt: new Date() } }),
      this.prisma.adminAuditLog.create({
        data: { adminId: admin.id, action: "admin.staff_password_reset", entityType: "admin_user", entityId: id, details: { sessionsRevoked: true } },
      }),
    ]);
    return { data: { temporaryPassword } };
  }

  async listAuditLogs(admin: AuthenticatedAdmin, query: Record<string, string | undefined>) {
    requireAdminPermission(admin, "staff.activity");
    const page = boundedInt(query.page, 1, 1, 10_000);
    const pageSize = boundedInt(query.pageSize, 30, 1, 100);
    const where = this.auditWhere(query);
    const [rows, total] = await Promise.all([
      this.prisma.adminAuditLog.findMany({
        where,
        orderBy: [{ createdAt: "desc" }, { id: "desc" }],
        skip: (page - 1) * pageSize,
        take: pageSize,
        include: { admin: { select: { id: true, fullName: true, username: true, avatarPath: true, role: true } } },
      }),
      this.prisma.adminAuditLog.count({ where }),
    ]);
    return {
      data: rows.map((row) => this.toAudit(row, admin)),
      meta: { page, pageSize, total, pageCount: Math.ceil(total / pageSize) },
    };
  }

  async getAuditLog(admin: AuthenticatedAdmin, idText: string) {
    requireAdminPermission(admin, "staff.activity");
    const row = await this.prisma.adminAuditLog.findUnique({
      where: { id: parseId(idText) },
      include: { admin: { select: { id: true, fullName: true, username: true, avatarPath: true, role: true } } },
    });
    if (!row) throw new NotFoundException({ code: "ADMIN_AUDIT_LOG_NOT_FOUND", message: "جزئیات این فعالیت پیدا نشد." });
    return { data: this.toAudit(row, admin) };
  }

  private auditWhere(query: Record<string, string | undefined>): Prisma.AdminAuditLogWhereInput {
    const where: Prisma.AdminAuditLogWhereInput = {};
    if (query.adminId) where.adminId = parseId(query.adminId);
    if (query.entityType?.trim()) where.entityType = query.entityType.trim().slice(0, 64);
    if (query.result === "success" || query.result === "failed") where.result = query.result;
    if (query.from || query.to) {
      const from = query.from ? new Date(query.from) : undefined;
      const to = query.to ? new Date(query.to) : undefined;
      if ((from && !Number.isFinite(from.getTime())) || (to && !Number.isFinite(to.getTime()))) {
        throw new BadRequestException({ code: "ADMIN_AUDIT_DATE_INVALID", message: "بازهٔ زمانی معتبر نیست." });
      }
      where.createdAt = { ...(from ? { gte: from } : {}), ...(to ? { lte: to } : {}) };
    }
    return where;
  }

  private ensureCanGrant(admin: AuthenticatedAdmin, requested: string[]) {
    const unknown = requested.filter((permission) => !permissionKeys.has(permission));
    if (unknown.length) throw new BadRequestException({ code: "ADMIN_PERMISSION_UNKNOWN", message: "یکی از دسترسی‌های انتخاب‌شده معتبر نیست." });
    if (managedRoles.has(admin.role)) return;
    const own = new Set(admin.permissions);
    if (requested.some((permission) => !own.has(permission))) {
      throw new ForbiddenException({ code: "ADMIN_PERMISSION_ESCALATION_BLOCKED", message: "نمی‌توانید دسترسی‌ای را واگذار کنید که خودتان ندارید." });
    }
  }

  private toStaff(row: {
    id: bigint; fullName: string; username: string; phone: string | null; avatarPath: string | null;
    role: string; isActive: boolean; mustChangePassword: boolean; lastLoginAt: Date | null;
    createdAt: Date; permissions: { permissionKey: string; expiresAt: Date | null }[];
  }, lastActivityAt: Date | null) {
    const now = new Date();
    return {
      id: row.id.toString(), fullName: row.fullName, username: row.username, phone: row.phone,
      avatarPath: row.avatarPath, role: row.role, isActive: row.isActive,
      mustChangePassword: row.mustChangePassword, lastLoginAt: row.lastLoginAt?.toISOString() ?? null,
      lastActivityAt: lastActivityAt?.toISOString() ?? null, createdAt: row.createdAt.toISOString(),
      permissions: row.permissions.filter((item) => !item.expiresAt || item.expiresAt > now).map((item) => item.permissionKey),
    };
  }

  private toAudit(row: {
    id: bigint; adminId: bigint | null; action: string; entityType: string; entityId: bigint | null;
    details: Prisma.JsonValue | null; result: string; requestIp: Uint8Array | null; createdAt: Date;
    admin: { id: bigint; fullName: string; username: string; avatarPath: string | null; role: string } | null;
  }, viewer: AuthenticatedAdmin) {
    return {
      id: row.id.toString(), adminId: row.adminId?.toString() ?? null, action: row.action,
      entityType: row.entityType, entityId: row.entityId?.toString() ?? null,
      details: redactSensitive(row.details, viewer), result: row.result,
      requestIp: row.requestIp?.length === 4 ? [...row.requestIp].join(".") : null,
      createdAt: row.createdAt.toISOString(),
      admin: row.admin ? { ...row.admin, id: row.admin.id.toString() } : null,
    };
  }
}

function normalizeUsername(value: string) {
  return value.trim().toLowerCase();
}

function parseId(value: string): bigint {
  if (!/^\d{1,20}$/.test(value)) throw new BadRequestException({ code: "ADMIN_ID_INVALID", message: "شناسه معتبر نیست." });
  const id = BigInt(value);
  if (id < 1n) throw new BadRequestException({ code: "ADMIN_ID_INVALID", message: "شناسه معتبر نیست." });
  return id;
}

function boundedInt(value: string | undefined, fallback: number, min: number, max: number) {
  const number = Number(value ?? fallback);
  return Number.isInteger(number) ? Math.min(max, Math.max(min, number)) : fallback;
}

function redactSensitive(value: Prisma.JsonValue | null, viewer: AuthenticatedAdmin): Prisma.JsonValue | null {
  if (value === null || typeof value !== "object") return value;
  if (Array.isArray(value)) return value.map((item) => redactSensitive(item, viewer) as Prisma.JsonValue);
  const result: Record<string, Prisma.JsonValue> = {};
  for (const [key, item] of Object.entries(value)) {
    const financialHidden = !hasAdminPermission(viewer, "reports.financial") && /price|cost|toman|amount|sales|revenue/i.test(key);
    const contactHidden = !hasAdminPermission(viewer, "orders.view_contact") && /phone|address|recipientName|customerNote/i.test(key);
    result[key] = /password|token|secret|api.?key|authorization|credential/i.test(key) || financialHidden || contactHidden
      ? "[حذف‌شده]"
      : redactSensitive(item as Prisma.JsonValue, viewer) as Prisma.JsonValue;
  }
  return result;
}
