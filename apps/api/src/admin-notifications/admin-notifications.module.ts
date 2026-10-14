import { Module } from "@nestjs/common";
import { AdminNotificationController } from "./admin-notification.controller";
import { AdminNotificationService } from "./admin-notification.service";
import { AdminNotificationGateway } from "./admin-notification.gateway";

@Module({
  controllers: [AdminNotificationController],
  providers: [AdminNotificationService, AdminNotificationGateway],
  exports: [AdminNotificationService, AdminNotificationGateway],
})
export class AdminNotificationsModule {}
