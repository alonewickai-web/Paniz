import { Body, Controller, Param, Post } from "@nestjs/common";
import { ApiExcludeController } from "@nestjs/swagger";
import { RubikaBotService } from "./rubika.service";

@ApiExcludeController()
@Controller("integrations/rubika")
export class RubikaWebhookController {
  constructor(private readonly rubika: RubikaBotService) {}

  @Post("webhook/:secret")
  receiveUpdate(@Param("secret") secret: string, @Body() body: unknown) {
    return this.rubika.handleWebhook(secret, body);
  }
}
