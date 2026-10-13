import { Controller, Get, Query, Req, UseGuards } from "@nestjs/common";
import { ApiBearerAuth, ApiOperation, ApiTags } from "@nestjs/swagger";
import { AdminPermissionGuard, RequireAdminPermission } from "../admin-auth/admin-permission.guard";
import { AdminRequest, AdminSessionGuard } from "../admin-auth/admin-session.guard";
import { FinancialReportService } from "./financial-report.service";

@ApiTags("گزارش مالی")
@ApiBearerAuth("admin-session")
@UseGuards(AdminSessionGuard, AdminPermissionGuard)
@Controller("admin/analytics")
export class FinancialReportController {
  constructor(private readonly reportService: FinancialReportService) {}

  @Get("finance")
  @RequireAdminPermission("reports.financial")
  @ApiOperation({ summary: "گزارش فروش، بهای تمام‌شده و سود ناخالص به ریال" })
  report(@Req() _request: AdminRequest, @Query("range") range?: string) {
    return this.reportService.report(range);
  }
}
