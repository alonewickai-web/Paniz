import { Body, Controller, Get, Param, Patch, Post, Query, Req, UseGuards } from "@nestjs/common";
import { ApiBearerAuth, ApiTags } from "@nestjs/swagger";
import { AdminRequest, AdminSessionGuard } from "../admin-auth/admin-session.guard";
import { AdminPermissionGuard, RequireAdminPermission } from "../admin-auth/admin-permission.guard";
import { AdminManagementService } from "./admin-management.service";
import { CreateAdminStaffDto } from "./dto/create-admin-staff.dto";
import { UpdateAdminStaffDto } from "./dto/update-admin-staff.dto";

@ApiTags("کارکنان و تاریخچهٔ فعالیت")
@ApiBearerAuth("admin-session")
@UseGuards(AdminSessionGuard, AdminPermissionGuard)
@Controller("admin")
export class AdminManagementController {
  constructor(private readonly management: AdminManagementService) {}

  @Get("staff/permissions")
  @RequireAdminPermission("staff.manage")
  permissions() { return this.management.permissionCatalog(); }

  @Get("staff")
  @RequireAdminPermission("staff.manage")
  staff(@Req() request: AdminRequest, @Query() query: Record<string, string>) {
    return this.management.listStaff(request.admin!, query);
  }

  @Get("staff/:id")
  @RequireAdminPermission("staff.manage")
  staffDetail(@Req() request: AdminRequest, @Param("id") id: string) {
    return this.management.getStaff(request.admin!, id);
  }

  @Post("staff")
  @RequireAdminPermission("staff.manage")
  createStaff(@Req() request: AdminRequest, @Body() body: CreateAdminStaffDto) {
    return this.management.createStaff(request.admin!, body);
  }

  @Patch("staff/:id")
  @RequireAdminPermission("staff.manage")
  updateStaff(@Req() request: AdminRequest, @Param("id") id: string, @Body() body: UpdateAdminStaffDto) {
    return this.management.updateStaff(request.admin!, id, body);
  }

  @Post("staff/:id/reset-password")
  @RequireAdminPermission("staff.manage")
  resetPassword(@Req() request: AdminRequest, @Param("id") id: string) {
    return this.management.resetStaffPassword(request.admin!, id);
  }

  @Get("audit-logs")
  @RequireAdminPermission("staff.activity")
  activity(@Req() request: AdminRequest, @Query() query: Record<string, string>) {
    return this.management.listAuditLogs(request.admin!, query);
  }

  @Get("audit-logs/:id")
  @RequireAdminPermission("staff.activity")
  activityDetail(@Req() request: AdminRequest, @Param("id") id: string) {
    return this.management.getAuditLog(request.admin!, id);
  }
}
