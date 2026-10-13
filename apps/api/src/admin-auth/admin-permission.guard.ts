import { CanActivate, ExecutionContext, ForbiddenException, Injectable, SetMetadata } from "@nestjs/common";
import { Reflector } from "@nestjs/core";
import { AdminRequest } from "./admin-session.guard";
import { hasAdminPermission } from "./admin-permissions";

const REQUIRED_PERMISSIONS = "admin:required-permissions";
type PermissionRequirements = { all: string[]; any: string[] };

export function RequireAdminPermission(...permissions: string[]) {
  return SetMetadata(REQUIRED_PERMISSIONS, { all: permissions, any: [] } satisfies PermissionRequirements);
}

export function RequireAnyAdminPermission(...permissions: string[]) {
  return SetMetadata(REQUIRED_PERMISSIONS, { all: [], any: permissions } satisfies PermissionRequirements);
}

@Injectable()
export class AdminPermissionGuard implements CanActivate {
  constructor(private readonly reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const requirements = this.reflector.getAllAndOverride<PermissionRequirements>(REQUIRED_PERMISSIONS, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (!requirements) return true;

    const request = context.switchToHttp().getRequest<AdminRequest>();
    const admin = request.admin;
    if (!admin) return false;

    const allowed = requirements.all.every((permission) => hasAdminPermission(admin, permission)) &&
      (requirements.any.length === 0 || requirements.any.some((permission) => hasAdminPermission(admin, permission)));
    if (!allowed) throw new ForbiddenException({ code: "ADMIN_PERMISSION_REQUIRED", message: "دسترسی انجام این کار را ندارید." });
    return true;
  }
}
