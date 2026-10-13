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
import { SupportModule } from "../support/support.module";
import { WebPushModule } from "../push/web-push.module";
import { AdminNotificationsModule } from "../admin-notifications/admin-notifications.module";
import { AdminChatController } from "./admin-chat.controller";
import { AdminChatService } from "./admin-chat.service";

@Module({
  imports: [AdminAuthModule, RubikaModule, SupportModule, WebPushModule, AdminNotificationsModule],
  controllers: [AdminController, StoreManagementController, AdminToolsController, AdminManagementController, AdminAppReleaseController, AdminChatController],
  providers: [AdminService, StoreManagementService, AdminToolsService, AdminManagementService, AdminAppReleaseService, AdminChatService],
  exports: [StoreManagementService],
})
export class AdminModule {}
