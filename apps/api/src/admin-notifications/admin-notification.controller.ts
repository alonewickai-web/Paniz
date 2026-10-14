import { Body, Controller, Delete, Get, Param, Patch, Post, Query, Req, UseGuards } from "@nestjs/common";
import { ApiBearerAuth, ApiTags } from "@nestjs/swagger";
import { AdminRequest, AdminSessionGuard } from "../admin-auth/admin-session.guard";
import { AdminNotificationService } from "./admin-notification.service";
import { RegisterNotificationDeviceDto } from "./dto/register-notification-device.dto";
import { NotificationDeviceIdDto } from "./dto/notification-device-id.dto";
import { UpdateNotificationPreferencesDto } from "./dto/update-notification-preferences.dto";

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

  @Get("unread-count")
  unreadCount(@Req() request: AdminRequest) { return this.notifications.unreadCount(request.admin!); }

  @Get("preferences")
  preferences(@Req() request: AdminRequest) { return this.notifications.getPreferences(request.admin!); }

  @Patch("preferences")
  updatePreferences(@Req() request: AdminRequest, @Body() body: UpdateNotificationPreferencesDto) {
    return this.notifications.updatePreferences(request.admin!, body);
  }

  @Get("devices")
  devices(@Req() request: AdminRequest) { return this.notifications.listDevices(request.admin!); }

  @Post("devices")
  registerDevice(@Req() request: AdminRequest, @Body() body: RegisterNotificationDeviceDto) {
    return this.notifications.registerDevice(request.admin!, request.adminSessionId!, body);
  }

  @Delete("devices/:deviceId")
  revokeDevice(@Req() request: AdminRequest, @Param("deviceId") deviceId: string) {
    return this.notifications.revokeDevice(request.admin!, deviceId);
  }

  @Post("socket-ticket")
  socketTicket(@Req() request: AdminRequest, @Body() body: NotificationDeviceIdDto) {
    return this.notifications.createSocketTicket(request.admin!, request.adminSessionId!, body.deviceId);
  }

  @Get("sync")
  sync(@Req() request: AdminRequest, @Query("deviceId") deviceId: string, @Query("limit") limit?: string) {
    return this.notifications.syncDevice(request.admin!, deviceId, limit);
  }

  @Patch(":id/ack")
  acknowledge(@Req() request: AdminRequest, @Param("id") id: string, @Body() body: NotificationDeviceIdDto) {
    return this.notifications.acknowledge(request.admin!, id, body.deviceId);
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
