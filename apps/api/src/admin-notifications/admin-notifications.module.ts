import { Module } from "@nestjs/common";
import { AdminNotificationController } from "./admin-notification.controller";
import { AdminNotificationService } from "./admin-notification.service";

@Module({
  controllers: [AdminNotificationController],
  providers: [AdminNotificationService],
  exports: [AdminNotificationService],
})
export class AdminNotificationsModule {}
