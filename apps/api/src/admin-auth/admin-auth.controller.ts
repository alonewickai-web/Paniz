import { Body, Controller, Get, HttpCode, HttpStatus, Patch, Post, Req, UseGuards } from "@nestjs/common";
import { ApiBearerAuth, ApiBody, ApiOperation, ApiTags } from "@nestjs/swagger";
import { Throttle } from "@nestjs/throttler";
import { AdminAuthService } from "./admin-auth.service";
import { AdminSessionGuard, AdminRequest } from "./admin-session.guard";
import { AdminLoginDto } from "./dto/admin-login.dto";
import { BootstrapAdminDto } from "./dto/bootstrap-admin.dto";
import { UpdateAdminCredentialsDto } from "./dto/update-admin-credentials.dto";

@ApiTags("مدیریت فروشگاه | احراز هویت")
@Controller("admin/auth")
export class AdminAuthController {
  constructor(private readonly auth: AdminAuthService) {}

  @Post("bootstrap")
  @Throttle({ default: { limit: 2, ttl: 60_000 } })
  @ApiOperation({ summary: "راه‌اندازی یک‌بارهٔ مدیر مالک با کد یک‌بارمصرف ثبت‌شده در لاگ خصوصی API" })
  @ApiBody({ type: BootstrapAdminDto })
  bootstrap(@Body() body: BootstrapAdminDto) {
    return this.auth.bootstrap(body);
  }

  @Post("login")
  @HttpCode(HttpStatus.OK)
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  @ApiOperation({ summary: "ورود مدیر و دریافت نشست قابل ابطال" })
  @ApiBody({ type: AdminLoginDto })
  login(@Body() body: AdminLoginDto) {
    return this.auth.login(body);
  }

  @Get("me")
  @UseGuards(AdminSessionGuard)
  @ApiBearerAuth("admin-session")
  @ApiOperation({ summary: "نمایش هویت مدیر واردشده" })
  me(@Req() request: AdminRequest) {
    return this.auth.me(request);
  }

  @Post("logout")
  @HttpCode(HttpStatus.OK)
  @UseGuards(AdminSessionGuard)
  @ApiBearerAuth("admin-session")
  @ApiOperation({ summary: "باطل‌کردن نشست مدیر جاری" })
  logout(@Req() request: AdminRequest) {
    return this.auth.logout(request);
  }

  @Patch("credentials")
  @UseGuards(AdminSessionGuard)
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  @ApiBearerAuth("admin-session")
  @ApiOperation({ summary: "تغییر نام کاربری یا گذرواژه پس از تأیید گذرواژهٔ فعلی" })
  @ApiBody({ type: UpdateAdminCredentialsDto })
  updateCredentials(@Body() body: UpdateAdminCredentialsDto, @Req() request: AdminRequest) {
    return this.auth.updateCredentials(body, request);
  }
}
