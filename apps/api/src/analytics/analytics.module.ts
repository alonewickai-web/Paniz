import { Module } from "@nestjs/common";
import { AdminAuthModule } from "../admin-auth/admin-auth.module";
import { AdminSiteAnalyticsController, PublicSiteAnalyticsController } from "./site-analytics.controller";
import { SiteAnalyticsService } from "./site-analytics.service";

@Module({
  imports: [AdminAuthModule],
  controllers: [PublicSiteAnalyticsController, AdminSiteAnalyticsController],
  providers: [SiteAnalyticsService],
})
export class AnalyticsModule {}
