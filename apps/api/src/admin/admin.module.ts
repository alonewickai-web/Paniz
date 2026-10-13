import { Module } from "@nestjs/common";
import { AdminAuthModule } from "../admin-auth/admin-auth.module";
import { AdminController } from "./admin.controller";
import { AdminService } from "./admin.service";
import { StoreManagementController } from "./store-management.controller";
import { StoreManagementService } from "./store-management.service";
import { AdminToolsController } from "./admin-tools.controller";
import { AdminToolsService } from "./admin-tools.service";
import { RubikaModule } from "../integrations/rubika/rubika.module";
import { AdminManagementController } from "./admin-management.controller";
import { AdminManagementService } from "./admin-management.service";
import { AdminAppReleaseController } from "./admin-app-release.controller";
import { AdminAppReleaseService } from "./admin-app-release.service";

@Module({
  imports: [AdminAuthModule, RubikaModule],
  controllers: [AdminController, StoreManagementController, AdminToolsController, AdminManagementController, AdminAppReleaseController],
  providers: [AdminService, StoreManagementService, AdminToolsService, AdminManagementService, AdminAppReleaseService],
  exports: [StoreManagementService],
})
export class AdminModule {}
