import { Module } from "@nestjs/common";
import { RubikaWebhookController } from "./rubika-webhook.controller";
import { RubikaBotService } from "./rubika.service";

@Module({
  controllers: [RubikaWebhookController],
  providers: [RubikaBotService],
  exports: [RubikaBotService],
})
export class RubikaModule {}
