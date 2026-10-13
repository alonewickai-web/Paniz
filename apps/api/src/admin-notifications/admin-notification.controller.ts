import { Controller, Get, Patch, Param, Query, Req, UseGuards } from "@nestjs/common";
import { ApiBearerAuth, ApiTags } from "@nestjs/swagger";
import { AdminRequest, AdminSessionGuard } from "../admin-auth/admin-session.guard";
import { AdminNotificationService } from "./admin-notification.service";

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

  @Patch("read-all")
  markAllRead(@Req() request: AdminRequest) {
    return this.notifications.markAllRead(request.admin!);
  }

  @Patch(":id/read")
  markRead(@Req() request: AdminRequest, @Param("id") id: string) {
    return this.notifications.markRead(request.admin!, id);
  }
}
