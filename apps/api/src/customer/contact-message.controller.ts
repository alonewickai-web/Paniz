import { Body, Controller, HttpCode, HttpStatus, Post } from "@nestjs/common";
import { ApiOperation, ApiTags } from "@nestjs/swagger";
import { Throttle } from "@nestjs/throttler";
import { AdminNotificationService } from "../admin-notifications/admin-notification.service";
import { CreateContactMessageDto } from "./dto/create-contact-message.dto";

@ApiTags("تماس با فروشگاه")
@Controller("public/contact")
export class ContactMessageController {
  constructor(private readonly notifications: AdminNotificationService) {}

  @Post()
  @HttpCode(HttpStatus.OK)
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  @ApiOperation({ summary: "ارسال پیام از فرم تماس سایت" })
  async create(@Body() body: CreateContactMessageDto) {
    const name = body.name.trim();
    const phone = body.phone.trim();
    const message = body.message.trim();
    await this.notifications.notifyOwners({
      type: "customer_message",
      title: "پیام تازه از سایت",
      body: `از طرف ${name} · ${phone}\n${message}`,
      entityType: "customer_message",
    });
    return { data: { received: true } };
  }
}
