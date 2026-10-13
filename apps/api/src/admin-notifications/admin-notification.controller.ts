import { Body, Controller, Delete, Get, Patch, Param, Post, Query, Req, UseGuards } from "@nestjs/common";
import { ApiBearerAuth, ApiTags } from "@nestjs/swagger";
import { IsIn, IsString, MaxLength, MinLength } from "class-validator";
import { AdminRequest, AdminSessionGuard } from "../admin-auth/admin-session.guard";
import { AdminNotificationService } from "./admin-notification.service";

class RegisterPushDeviceDto {
  @IsString()
  @MinLength(32)
  @MaxLength(4096)
  token!: string;

  @IsString()
  @IsIn(["android"])
  platform!: string;
}

class UnregisterPushDeviceDto {
  @IsString()
  @MinLength(32)
  @MaxLength(4096)
  token!: string;
}

@ApiTags("اعلان‌های مدیر")
@ApiBearerAuth("admin-session")
@UseGuards(AdminSessionGuard)
@Controller("admin/notifications")
export class AdminNotificationController {
  constructor(private readonly notifications: AdminNotificationService) {}

  @Get()
  list(@Req() request: AdminRequest, @Query("page") page?: string, @Query("pageSize") pageSize?: string) {
    return this.notifications.list(request.admin!, page, pageSize);
  }

  @Post("devices")
  registerDevice(@Req() request: AdminRequest, @Body() body: RegisterPushDeviceDto) {
    return this.notifications.registerDevice(request.admin!, body.token, body.platform);
  }

  @Delete("devices")
  unregisterDevice(@Req() request: AdminRequest, @Body() body: UnregisterPushDeviceDto) {
    return this.notifications.unregisterDevice(request.admin!, body.token);
  }

  @Patch("read-all")
  markAllRead(@Req() request: AdminRequest) {
    return this.notifications.markAllRead(request.admin!);
  }

  @Patch(":id/read")
  markRead(@Req() request: AdminRequest, @Param("id") id: string) {
    return this.notifications.markRead(request.admin!, id);
  }
}
