import { Module } from "@nestjs/common";
import { AdminNotificationController } from "./admin-notification.controller";
import { AdminNotificationService } from "./admin-notification.service";
import { FirebasePushService } from "./firebase-push.service";

@Module({
  controllers: [AdminNotificationController],
  providers: [AdminNotificationService, FirebasePushService],
  exports: [AdminNotificationService],
})
export class AdminNotificationsModule {}
