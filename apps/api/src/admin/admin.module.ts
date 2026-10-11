import { Module } from "@nestjs/common";
import { AdminAuthModule } from "../admin-auth/admin-auth.module";
import { AdminController } from "./admin.controller";
import { AdminService } from "./admin.service";
import { StoreManagementController } from "./store-management.controller";
import { StoreManagementService } from "./store-management.service";
import { AdminToolsController } from "./admin-tools.controller";
import { AdminToolsService } from "./admin-tools.service";

@Module({
  imports: [AdminAuthModule],
  controllers: [AdminController, StoreManagementController, AdminToolsController],
  providers: [AdminService, StoreManagementService, AdminToolsService],
  exports: [StoreManagementService],
})
export class AdminModule {}
