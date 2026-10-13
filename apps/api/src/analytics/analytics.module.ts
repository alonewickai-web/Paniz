import { Module } from "@nestjs/common";
import { AdminAuthModule } from "../admin-auth/admin-auth.module";
import { AdminSiteAnalyticsController, PublicSiteAnalyticsController } from "./site-analytics.controller";
import { SiteAnalyticsService } from "./site-analytics.service";
import { FinancialReportController } from "./financial-report.controller";
import { FinancialReportService } from "./financial-report.service";

@Module({
  imports: [AdminAuthModule],
  controllers: [PublicSiteAnalyticsController, AdminSiteAnalyticsController, FinancialReportController],
  providers: [SiteAnalyticsService, FinancialReportService],
})
export class AnalyticsModule {}
