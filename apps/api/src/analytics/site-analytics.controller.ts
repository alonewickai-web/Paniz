import { Body, Controller, ForbiddenException, Get, Post, Query, Req, Res, StreamableFile, UseGuards } from "@nestjs/common";
import { ApiBearerAuth, ApiOperation, ApiTags } from "@nestjs/swagger";
import type { Response } from "express";
import { AdminRequest, AdminSessionGuard } from "../admin-auth/admin-session.guard";
import { SiteAnalyticsService } from "./site-analytics.service";
import { CreatePageViewDto } from "./dto/create-page-view.dto";
import { AdminPermissionGuard, RequireAdminPermission } from "../admin-auth/admin-permission.guard";
import { GoogleInsightsService } from "./google-insights.service";
import { hasAdminPermission } from "../admin-auth/admin-permissions";

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
  constructor(private readonly analytics: SiteAnalyticsService, private readonly googleInsights: GoogleInsightsService) {}

  @Get("site-visits")
  @RequireAdminPermission("reports.view")
  @ApiOperation({ summary: "بازدیدهای امروز، روند ۷ و ۳۰ روز و صفحه‌های پربازدید" })
  report(@Req() request: AdminRequest) {
    return this.analytics.siteVisitReport();
  }

  @Get("seo")
  @RequireAdminPermission("reports.view")
  @ApiOperation({ summary: "گزارش واقعی SEO، Search Console و GA4 همراه فروش پرداخت‌شده" })
  async seoReport(
    @Req() request: AdminRequest,
    @Query("range") range?: string,
    @Query("from") from?: string,
    @Query("to") to?: string,
  ) {
    const report = structuredClone(await this.googleInsights.report(range, from, to)) as { data: Record<string, unknown> };
    const financialAccess = hasAdminPermission(request.admin!, "reports.financial");
    report.data.financialAccess = financialAccess;
    if (!financialAccess) {
      const metrics = report.data.metrics as Record<string, Record<string, unknown>>;
      metrics.analytics.purchaseRevenue = null;
      metrics.store.organicRevenueToman = null;
      metrics.comparison.organicRevenue = null;
    }
    return report;
  }

  @Get("seo/export.csv")
  @RequireAdminPermission("reports.view")
  @ApiOperation({ summary: "خروجی CSV گزارش سئو، جست‌وجوها، صفحه‌ها یا محصولات" })
  async exportSeoReport(
    @Req() _request: AdminRequest,
    @Res({ passthrough: true }) response: Response,
    @Query("range") range?: string,
    @Query("from") from?: string,
    @Query("to") to?: string,
    @Query("type") type?: string,
    @Query("category") category?: string,
  ) {
    const csv = await this.googleInsights.csv(range, from, to, type, category);
    response.setHeader("Content-Type", "text/csv; charset=utf-8");
    response.setHeader("Content-Disposition", `attachment; filename="paniz-seo-${type ?? "products"}.csv"`);
    return csv;
  }

  @Get("seo/export.xlsx")
  @RequireAdminPermission("reports.view")
  @ApiOperation({ summary: "خروجی Excel گزارش سئو با فیلتر تاریخ و دسته‌بندی" })
  async exportSeoExcel(
    @Req() _request: AdminRequest,
    @Res({ passthrough: true }) response: Response,
    @Query("range") range?: string,
    @Query("from") from?: string,
    @Query("to") to?: string,
    @Query("type") type?: string,
    @Query("category") category?: string,
  ) {
    const workbook = await this.googleInsights.xlsx(range, from, to, type, category);
    response.setHeader("Content-Type", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet");
    response.setHeader("Content-Disposition", `attachment; filename="paniz-seo-${type ?? "products"}.xlsx"`);
    return new StreamableFile(workbook);
  }
}
