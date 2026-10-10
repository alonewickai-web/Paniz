import { Body, Controller, Get, HttpCode, HttpStatus, Post, Req, Res, UseGuards } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { ApiBody, ApiOperation, ApiTags } from "@nestjs/swagger";
import { Throttle } from "@nestjs/throttler";
import type { Response } from "express";
import { CustomerAuthService } from "./customer-auth.service";
import { CustomerRequest, CustomerSessionGuard, CUSTOMER_SESSION_COOKIE } from "./customer-session.guard";
import { PhoneDto } from "./dto/phone.dto";
import { VerifyPhoneCodeDto } from "./dto/verify-phone-code.dto";

const CUSTOMER_SESSION_DAYS = 30;

@ApiTags("حساب مشتری")
@Controller("customer/auth")
export class CustomerAuthController {
  constructor(
    private readonly auth: CustomerAuthService,
    private readonly config: ConfigService,
  ) {}

  @Post("send-code")
  @HttpCode(HttpStatus.OK)
  @Throttle({ default: { limit: 3, ttl: 60_000 } })
  @ApiOperation({ summary: "ارسال کد یک‌بارمصرف ورود به شمارهٔ همراه" })
  @ApiBody({ type: PhoneDto })
  sendCode(@Body() body: PhoneDto) {
    return this.auth.sendCode(body);
  }

  @Post("verify-code")
  @HttpCode(HttpStatus.OK)
  @Throttle({ default: { limit: 8, ttl: 60_000 } })
  @ApiOperation({ summary: "تأیید شمارهٔ همراه و ایجاد حساب یا نشست مشتری" })
  @ApiBody({ type: VerifyPhoneCodeDto })
  async verifyCode(
    @Body() body: VerifyPhoneCodeDto,
    @Res({ passthrough: true }) response: Response,
  ) {
    const session = await this.auth.verifyCode(body);
    response.cookie(CUSTOMER_SESSION_COOKIE, session.accessToken, {
      httpOnly: true,
      secure: this.config.get<string>("NODE_ENV") === "production",
      sameSite: "lax",
      path: "/api/v1",
      maxAge: CUSTOMER_SESSION_DAYS * 24 * 60 * 60 * 1000,
    });
    return { data: { expiresAt: session.expiresAt.toISOString(), customer: session.customer } };
  }

  @Get("me")
  @UseGuards(CustomerSessionGuard)
  @ApiOperation({ summary: "نمایش حساب مشتری واردشده" })
  me(@Req() request: CustomerRequest) {
    return this.auth.me(request);
  }

  @Post("logout")
  @HttpCode(HttpStatus.OK)
  @UseGuards(CustomerSessionGuard)
  @ApiOperation({ summary: "خروج و ابطال نشست مشتری" })
  logout(@Req() request: CustomerRequest, @Res({ passthrough: true }) response: Response) {
    response.clearCookie(CUSTOMER_SESSION_COOKIE, {
      httpOnly: true,
      secure: this.config.get<string>("NODE_ENV") === "production",
      sameSite: "lax",
      path: "/api/v1",
    });
    return this.auth.logout(request);
  }
}
