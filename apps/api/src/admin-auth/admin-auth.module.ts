import { Module } from "@nestjs/common";
import { AdminAuthController } from "./admin-auth.controller";
import { AdminAuthService } from "./admin-auth.service";
import { AdminSessionGuard } from "./admin-session.guard";
import { AdminPermissionGuard } from "./admin-permission.guard";

@Module({
  controllers: [AdminAuthController],
  providers: [AdminAuthService, AdminSessionGuard, AdminPermissionGuard],
  exports: [AdminSessionGuard, AdminPermissionGuard],
})
export class AdminAuthModule {}
