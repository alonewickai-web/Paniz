import { Body, Controller, ForbiddenException, Get, Post, Req, UseGuards } from "@nestjs/common";
import { ApiBearerAuth, ApiOperation, ApiTags } from "@nestjs/swagger";
import { AdminRequest, AdminSessionGuard } from "../admin-auth/admin-session.guard";
import { SiteAnalyticsService } from "./site-analytics.service";
import { CreatePageViewDto } from "./dto/create-page-view.dto";
import { AdminPermissionGuard, RequireAdminPermission } from "../admin-auth/admin-permission.guard";

@ApiTags("آمار بازدید سایت")
@Controller("analytics")
export class PublicSiteAnalyticsController {
  constructor(private readonly analytics: SiteAnalyticsService) {}

  @Post("page-view")
  @ApiOperation({ summary: "ثبت بازدید ناشناس یک مسیر از سایت فروشگاه" })
  recordPageView(@Body() body: CreatePageViewDto) {
    return this.analytics.recordPageView(body);
  }
}

@ApiTags("مدیریت فروشگاه")
@ApiBearerAuth("admin-session")
@UseGuards(AdminSessionGuard, AdminPermissionGuard)
@Controller("admin/analytics")
export class AdminSiteAnalyticsController {
  constructor(private readonly analytics: SiteAnalyticsService) {}

  @Get("site-visits")
  @RequireAdminPermission("reports.view")
  @ApiOperation({ summary: "بازدیدهای امروز، روند ۷ و ۳۰ روز و صفحه‌های پربازدید" })
  report(@Req() request: AdminRequest) {
    return this.analytics.siteVisitReport();
  }
}
