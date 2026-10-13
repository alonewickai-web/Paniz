import { CanActivate, ExecutionContext, ForbiddenException, Injectable, UnauthorizedException } from "@nestjs/common";
import { createHash } from "node:crypto";
import type { Request } from "express";
import { PrismaService } from "../database/prisma.service";

export type AuthenticatedAdmin = {
  id: bigint;
  fullName: string;
  username: string;
  phone: string | null;
  avatarPath: string | null;
  role: string;
  permissions: string[];
  mustChangePassword: boolean;
};

export type AdminRequest = Request & {
  admin?: AuthenticatedAdmin;
  adminSessionId?: bigint;
};

@Injectable()
export class AdminSessionGuard implements CanActivate {
  constructor(private readonly prisma: PrismaService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<AdminRequest>();
    const authorization = request.headers.authorization;
    const [scheme, token, extra] = authorization?.split(" ") ?? [];
    if (scheme?.toLowerCase() !== "bearer" || !token || extra || token.length > 100) {
      throw new UnauthorizedException({ code: "ADMIN_SESSION_REQUIRED", message: "نشست مدیر معتبر نیست" });
    }

    const tokenHash = createHash("sha256").update(token).digest("hex");
    const session = await this.prisma.adminSession.findUnique({
      where: { tokenHash },
      include: { admin: { include: { permissions: true } } },
    });
    const now = new Date();
    if (!session || session.revokedAt || session.expiresAt <= now || !session.admin.isActive) {
      throw new UnauthorizedException({ code: "ADMIN_SESSION_EXPIRED", message: "نشست مدیر منقضی یا غیرفعال است" });
    }

    request.admin = {
      id: session.admin.id,
      fullName: session.admin.fullName,
      username: session.admin.username,
      phone: session.admin.phone,
      avatarPath: session.admin.avatarPath,
      role: session.admin.role,
      permissions: session.admin.permissions
        .filter((grant) => !grant.expiresAt || grant.expiresAt > now)
        .map((grant) => grant.permissionKey),
      mustChangePassword: session.admin.mustChangePassword,
    };
    request.adminSessionId = session.id;
    if (session.admin.mustChangePassword) {
      const path = request.path.replace(/^\/api\/v1/, "");
      const allowed = new Set(["GET /admin/auth/me", "POST /admin/auth/logout", "PATCH /admin/auth/credentials"]);
      if (!allowed.has(`${request.method} ${path}`)) {
        throw new ForbiddenException({ code: "ADMIN_PASSWORD_CHANGE_REQUIRED", message: "ابتدا گذرواژهٔ موقت حساب خود را تغییر دهید." });
      }
    }
    await this.prisma.adminSession.update({ where: { id: session.id }, data: { lastUsedAt: now } });
    return true;
  }
}
