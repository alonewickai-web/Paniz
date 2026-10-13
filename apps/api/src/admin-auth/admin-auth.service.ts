import {
  ConflictException,
  BadRequestException,
  Injectable,
  Logger,
  OnModuleInit,
  UnauthorizedException,
} from "@nestjs/common";
import { Prisma } from "@prisma/client";
import * as argon2 from "argon2";
import {
  createHash,
  randomBytes,
  scrypt as scryptCallback,
  timingSafeEqual,
} from "node:crypto";
import { AdminLoginDto } from "./dto/admin-login.dto";
import { UpdateAdminCredentialsDto } from "./dto/update-admin-credentials.dto";
import { AdminRequest } from "./admin-session.guard";
import { PrismaService } from "../database/prisma.service";
import { ALL_ADMIN_PERMISSION_KEYS } from "./admin-permissions";
import { UpdateAdminProfileDto } from "../admin/dto/update-admin-profile.dto";

const SESSION_DAYS = 7;
const TEST_ADMIN_USERNAME = "erfan";
const TEST_ADMIN_PASSWORD = "2018";
const TEST_ADMIN_SEEDED_SETTING = "security.test_admin_seeded";
const ADMIN_BOOTSTRAP_SETTING = "security.admin_bootstrap_code";

@Injectable()
export class AdminAuthService implements OnModuleInit {
  private readonly logger = new Logger(AdminAuthService.name);

  constructor(private readonly prisma: PrismaService) {}

  async onModuleInit(): Promise<void> {
    if (process.env.ENABLE_TEST_ADMIN !== "true" || process.env.NODE_ENV === "production") return;
    if (await this.prisma.storeSetting.findUnique({ where: { settingKey: TEST_ADMIN_SEEDED_SETTING } })) {
      await this.prisma.storeSetting.deleteMany({ where: { settingKey: ADMIN_BOOTSTRAP_SETTING } });
      return;
    }

    const passwordHash = await hashPassword(TEST_ADMIN_PASSWORD);
    try {
      await this.prisma.$transaction(async (tx) => {
        if (await tx.storeSetting.findUnique({ where: { settingKey: TEST_ADMIN_SEEDED_SETTING } })) return;

        const existingAdmin = await tx.adminUser.findUnique({ where: { username: TEST_ADMIN_USERNAME } });
        const admin = existingAdmin
          ? await tx.adminUser.update({ where: { id: existingAdmin.id }, data: { passwordHash } })
          : await tx.adminUser.create({
              data: {
                fullName: "مدیر آزمایشی",
                username: TEST_ADMIN_USERNAME,
                phone: null,
                passwordHash,
                role: "owner",
              },
            });

        if (existingAdmin) {
          await tx.adminSession.updateMany({
            where: { adminId: admin.id, revokedAt: null },
            data: { revokedAt: new Date() },
          });
        }
        await tx.adminAuditLog.create({
          data: {
            adminId: admin.id,
            action: "admin.test_account_seeded",
            entityType: "admin_user",
            entityId: admin.id,
            details: { username: TEST_ADMIN_USERNAME },
          },
        });
        await tx.storeSetting.create({
          data: {
            settingKey: TEST_ADMIN_SEEDED_SETTING,
            settingValue: { seeded: true },
            isPublic: false,
          },
        });
        await tx.storeSetting.deleteMany({ where: { settingKey: ADMIN_BOOTSTRAP_SETTING } });
      });
      this.logger.warn(`Temporary test admin is available with username "${TEST_ADMIN_USERNAME}".`);
    } catch (error) {
      if (!(error instanceof Prisma.PrismaClientKnownRequestError) || !["P2002", "P2034"].includes(error.code)) throw error;
    }
  }

  async login(input: AdminLoginDto) {
    const username = normalizeUsername(input.username);
    const admin = await this.prisma.adminUser.findUnique({ where: { username }, include: { permissions: true } });
    const validPassword = admin ? await verifyPassword(input.password, admin.passwordHash) : false;
    if (!admin || !admin.isActive || !validPassword) {
      await this.prisma.adminAuditLog.create({
        data: {
          adminId: admin?.id ?? null,
          action: "admin.login_failed",
          result: "failed",
          entityType: "admin_user",
          entityId: admin?.id ?? null,
          details: { identifierHash: createHash("sha256").update(username).digest("hex") },
        },
      });
      throw new UnauthorizedException({ code: "INVALID_ADMIN_CREDENTIALS", message: "نام کاربری یا گذرواژه درست نیست" });
    }

    const accessToken = randomBytes(32).toString("base64url");
    const expiresAt = new Date(Date.now() + SESSION_DAYS * 24 * 60 * 60 * 1000);
    if (admin.passwordHash.startsWith("scrypt$")) {
      const upgradedHash = await hashPassword(input.password);
      await this.prisma.adminUser.update({ where: { id: admin.id }, data: { passwordHash: upgradedHash } });
    }
    await this.prisma.$transaction([
      this.prisma.adminUser.update({ where: { id: admin.id }, data: { lastLoginAt: new Date() } }),
      this.prisma.adminSession.create({
        data: { adminId: admin.id, tokenHash: hashToken(accessToken), expiresAt, lastUsedAt: new Date() },
      }),
      this.prisma.adminAuditLog.create({
        data: { adminId: admin.id, action: "admin.login_succeeded", entityType: "admin_user", entityId: admin.id, details: { expiresAt: expiresAt.toISOString() } },
      }),
    ]);
    return sessionResponse(accessToken, expiresAt, admin);
  }

  me(request: AdminRequest) {
    return {
      data: {
        id: request.admin!.id.toString(),
        fullName: request.admin!.fullName,
        username: request.admin!.username,
        phone: request.admin!.phone,
        avatarPath: request.admin!.avatarPath,
        role: request.admin!.role,
        permissions: request.admin!.permissions,
        mustChangePassword: request.admin!.mustChangePassword,
      },
    };
  }

  async logout(request: AdminRequest) {
    await this.prisma.$transaction([
      this.prisma.adminSession.updateMany({
        where: { id: request.adminSessionId, revokedAt: null },
        data: { revokedAt: new Date() },
      }),
      this.prisma.adminAuditLog.create({
        data: { adminId: request.admin!.id, action: "admin.logout", entityType: "admin_session", details: { sessionId: request.adminSessionId!.toString() } },
      }),
    ]);
    return { data: { revoked: true } };
  }

  async updateCredentials(input: UpdateAdminCredentialsDto, request: AdminRequest) {
    if (!input.username && !input.newPassword) {
      throw new ConflictException({ code: "ADMIN_CREDENTIALS_EMPTY", message: "نام کاربری یا گذرواژهٔ جدید را وارد کنید" });
    }

    const admin = await this.prisma.adminUser.findUnique({ where: { id: request.admin!.id } });
    const validPassword = admin ? await verifyPassword(input.currentPassword, admin.passwordHash) : false;
    if (!admin || !validPassword) {
      await this.prisma.adminAuditLog.create({
        data: {
          adminId: request.admin!.id,
          action: "admin.credentials_reauthentication_failed",
          result: "failed",
          entityType: "admin_user",
          entityId: request.admin!.id,
        },
      });
      throw new UnauthorizedException({ code: "ADMIN_REAUTHENTICATION_FAILED", message: "گذرواژهٔ فعلی درست نیست" });
    }
    if (admin.mustChangePassword && !input.newPassword) {
      throw new BadRequestException({ code: "ADMIN_NEW_PASSWORD_REQUIRED", message: "گذرواژهٔ جدید را وارد کنید." });
    }

    const username = input.username ? normalizeUsername(input.username) : undefined;
    if (username && username === admin.username && !input.newPassword) {
      throw new ConflictException({ code: "ADMIN_CREDENTIALS_UNCHANGED", message: "اطلاعات جدید با اطلاعات فعلی تفاوتی ندارد" });
    }
    const passwordHash = input.newPassword ? await hashPassword(input.newPassword) : undefined;

    try {
      return await this.prisma.$transaction(async (tx) => {
        const updated = await tx.adminUser.update({
          where: { id: admin.id },
          data: {
            ...(username ? { username } : {}),
            ...(passwordHash ? { passwordHash } : {}),
            mustChangePassword: false,
          },
        });
        const revoked = await tx.adminSession.updateMany({
          where: { adminId: admin.id, revokedAt: null, id: { not: request.adminSessionId } },
          data: { revokedAt: new Date() },
        });
        await tx.adminAuditLog.create({
          data: {
            adminId: admin.id,
            action: "admin.credentials_changed",
            entityType: "admin_user",
            entityId: admin.id,
            details: { usernameChanged: Boolean(username && username !== admin.username), passwordChanged: Boolean(passwordHash), sessionsRevoked: revoked.count },
          },
        });
        return { data: { updated: true, username: updated.username, sessionsRevoked: revoked.count } };
      });
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === "P2002") {
        throw new ConflictException({ code: "ADMIN_USERNAME_TAKEN", message: "این نام کاربری قبلاً انتخاب شده است" });
      }
      throw error;
    }
  }

  async updateProfile(input: UpdateAdminProfileDto, request: AdminRequest, avatarPath?: string | null) {
    try {
      const result = await this.prisma.$transaction(async (tx) => {
        const current = await tx.adminUser.findUniqueOrThrow({ where: { id: request.admin!.id } });
        const updated = await tx.adminUser.update({
          where: { id: current.id },
          data: {
            ...(input.fullName !== undefined ? { fullName: input.fullName.trim() } : {}),
            ...(input.phone !== undefined ? { phone: input.phone?.trim() || null } : {}),
            ...(avatarPath !== undefined ? { avatarPath } : {}),
          },
        });
        await tx.adminAuditLog.create({ data: {
          adminId: current.id, action: "admin.profile_updated", entityType: "admin_user", entityId: current.id,
          details: { changedFields: [...Object.keys(input), ...(avatarPath !== undefined ? ["avatarPath"] : [])] },
        } });
        return updated;
      });
      return { data: { id: result.id.toString(), fullName: result.fullName, phone: result.phone, avatarPath: result.avatarPath } };
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === "P2002") {
        throw new ConflictException({ code: "ADMIN_PHONE_TAKEN", message: "این شماره برای حساب دیگری ثبت شده است." });
      }
      throw error;
    }
  }
}

function sessionResponse(
  accessToken: string,
  expiresAt: Date,
  admin: {
    id: bigint;
    fullName: string;
    username: string;
    phone: string | null;
    avatarPath: string | null;
    role: string;
    mustChangePassword: boolean;
    permissions: { permissionKey: string; expiresAt: Date | null }[];
  },
) {
  const now = new Date();
  const permissions = admin.role === "owner" || admin.role === "admin"
    ? [...ALL_ADMIN_PERMISSION_KEYS]
    : admin.permissions.filter((grant) => !grant.expiresAt || grant.expiresAt > now).map((grant) => grant.permissionKey);
  return {
    data: {
      accessToken,
      tokenType: "Bearer",
      expiresAt: expiresAt.toISOString(),
      admin: {
        id: admin.id.toString(),
        fullName: admin.fullName,
        username: admin.username,
        phone: admin.phone,
        avatarPath: admin.avatarPath,
        role: admin.role,
        permissions,
        mustChangePassword: admin.mustChangePassword,
      },
    },
  };
}

function hashToken(token: string): string {
  return createHash("sha256").update(token).digest("hex");
}

function normalizeUsername(value: string): string {
  return value.trim().toLowerCase();
}

async function hashPassword(password: string): Promise<string> {
  return argon2.hash(password, {
    type: argon2.argon2id,
    memoryCost: 65_536,
    timeCost: 3,
    parallelism: 1,
  });
}

async function verifyPassword(password: string, encoded: string): Promise<boolean> {
  if (encoded.startsWith("$argon2id$")) {
    return argon2.verify(encoded, password);
  }
  const [algorithm, costText, blockText, parallelText, saltHex, keyHex] = encoded.split("$");
  if (algorithm !== "scrypt" || !costText || !blockText || !parallelText || !saltHex || !keyHex || keyHex.length !== 128) {
    return false;
  }
  const candidate = await deriveKey(password, Buffer.from(saltHex, "hex"), Number(costText), Number(blockText), Number(parallelText));
  return timingSafeEqual(candidate, Buffer.from(keyHex, "hex"));
}

function deriveKey(password: string, salt: Buffer, cost: number, blockSize: number, parallelization: number): Promise<Buffer> {
  return new Promise((resolve, reject) => {
    scryptCallback(password, salt, 64, {
      N: cost,
      r: blockSize,
      p: parallelization,
      maxmem: 64 * 1024 * 1024,
    }, (error, derivedKey) => error ? reject(error) : resolve(derivedKey));
  });
}
