import { Module } from "@nestjs/common";
import { RubikaWebhookController } from "./rubika-webhook.controller";
import { RubikaBotService } from "./rubika.service";
import { AdminNotificationsModule } from "../../admin-notifications/admin-notifications.module";

@Module({
  controllers: [RubikaWebhookController],
  providers: [RubikaBotService],
  imports: [AdminNotificationsModule],
  exports: [RubikaBotService],
})
export class RubikaModule {}
