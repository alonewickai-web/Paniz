import { Body, Controller, Get, HttpCode, HttpStatus, Post } from "@nestjs/common";
import { ApiOperation, ApiTags } from "@nestjs/swagger";
import { Throttle } from "@nestjs/throttler";
import { CustomerPushSubscriptionDto } from "../support/dto/customer-push-subscription.dto";
import { WebPushService } from "./web-push.service";

@ApiTags("اعلان‌های عمومی فروشگاه")
@Controller("public/push")
export class PublicWebPushController {
  constructor(private readonly push: WebPushService) {}

  @Get("public-key")
  @Throttle({ default: { limit: 60, ttl: 60_000 } })
  @ApiOperation({ summary: "دریافت کلید عمومی اعلان فروشگاه" })
  publicKey() {
    return { data: { publicKey: this.push.publicKey() } };
  }

  @Post("marketing-subscriptions")
  @HttpCode(HttpStatus.OK)
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @ApiOperation({ summary: "ثبت رضایت و اشتراک اعلان تخفیف‌ها و محصولات تازه" })
  async saveMarketingSubscription(@Body() body: CustomerPushSubscriptionDto) {
    return { data: await this.push.saveMarketingSubscription(body) };
  }
}
