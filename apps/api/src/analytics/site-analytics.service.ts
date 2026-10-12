import { createHash } from "node:crypto";
import { Injectable } from "@nestjs/common";
import { PrismaService } from "../database/prisma.service";
import { CreatePageViewDto } from "./dto/create-page-view.dto";

const IRAN_UTC_OFFSET_MINUTES = 210;

type RangeAggregate = {
  viewsToday: bigint;
  visitorsToday: bigint;
  views7Days: bigint;
  visitors7Days: bigint;
  views30Days: bigint;
  visitors30Days: bigint;
};

type DailyAggregate = { day: string; pageViews: bigint; uniqueVisitors: bigint };
type PopularPageAggregate = { path: string; pageViews: bigint };

@Injectable()
export class SiteAnalyticsService {
  constructor(private readonly prisma: PrismaService) {}

  async recordPageView(input: CreatePageViewDto) {
    const path = input.path.trim();
    const visitorHash = createHash("sha256").update(input.visitorId.toLowerCase()).digest("hex");
    await this.prisma.sitePageView.create({ data: { visitorHash, path } });
    return { data: { accepted: true } };
  }

  async siteVisitReport() {
    const now = new Date();
    const iranNow = new Date(now.getTime() + IRAN_UTC_OFFSET_MINUTES * 60_000);
    const iranOffsetMs = IRAN_UTC_OFFSET_MINUTES * 60_000;
    const todayStart = new Date(
      Date.UTC(iranNow.getUTCFullYear(), iranNow.getUTCMonth(), iranNow.getUTCDate()) - iranOffsetMs,
    );
    const sevenDaysStart = new Date(todayStart.getTime() - 6 * 24 * 60 * 60_000);
    const thirtyDaysStart = new Date(todayStart.getTime() - 29 * 24 * 60 * 60_000);

    const [aggregateRows, dailyRows, popularRows] = await Promise.all([
      this.prisma.$queryRaw<RangeAggregate[]>`
        SELECT
          CAST(COALESCE(SUM(CASE WHEN created_at >= ${todayStart} THEN 1 ELSE 0 END), 0) AS UNSIGNED) AS viewsToday,
          CAST(COUNT(DISTINCT CASE WHEN created_at >= ${todayStart} THEN visitor_hash END) AS UNSIGNED) AS visitorsToday,
          CAST(COALESCE(SUM(CASE WHEN created_at >= ${sevenDaysStart} THEN 1 ELSE 0 END), 0) AS UNSIGNED) AS views7Days,
          CAST(COUNT(DISTINCT CASE WHEN created_at >= ${sevenDaysStart} THEN visitor_hash END) AS UNSIGNED) AS visitors7Days,
          CAST(COUNT(*) AS UNSIGNED) AS views30Days,
          CAST(COUNT(DISTINCT visitor_hash) AS UNSIGNED) AS visitors30Days
        FROM site_page_views
        WHERE created_at >= ${thirtyDaysStart}
      `,
      this.prisma.$queryRaw<DailyAggregate[]>`
        SELECT
          DATE_FORMAT(DATE_ADD(created_at, INTERVAL 210 MINUTE), '%Y-%m-%d') AS day,
          CAST(COUNT(*) AS UNSIGNED) AS pageViews,
          CAST(COUNT(DISTINCT visitor_hash) AS UNSIGNED) AS uniqueVisitors
        FROM site_page_views
        WHERE created_at >= ${sevenDaysStart}
        GROUP BY DATE_FORMAT(DATE_ADD(created_at, INTERVAL 210 MINUTE), '%Y-%m-%d')
        ORDER BY day ASC
      `,
      this.prisma.$queryRaw<PopularPageAggregate[]>`
        SELECT path, CAST(COUNT(*) AS UNSIGNED) AS pageViews
        FROM site_page_views
        WHERE created_at >= ${thirtyDaysStart}
        GROUP BY path
        ORDER BY pageViews DESC, path ASC
        LIMIT 8
      `,
    ]);

    const aggregate = aggregateRows[0] ?? {
      viewsToday: 0n,
      visitorsToday: 0n,
      views7Days: 0n,
      visitors7Days: 0n,
      views30Days: 0n,
      visitors30Days: 0n,
    };
    const dailyByDate = new Map(dailyRows.map((row) => [row.day, row]));
    const daily = Array.from({ length: 7 }, (_, index) => {
      const date = new Date(sevenDaysStart.getTime() + index * 24 * 60 * 60_000 + iranOffsetMs)
        .toISOString()
        .slice(0, 10);
      const row = dailyByDate.get(date);
      return {
        date,
        pageViews: safeCount(row?.pageViews ?? 0n),
        uniqueVisitors: safeCount(row?.uniqueVisitors ?? 0n),
      };
    });

    return {
      data: {
        today: { pageViews: safeCount(aggregate.viewsToday), uniqueVisitors: safeCount(aggregate.visitorsToday) },
        last7Days: { pageViews: safeCount(aggregate.views7Days), uniqueVisitors: safeCount(aggregate.visitors7Days) },
        last30Days: { pageViews: safeCount(aggregate.views30Days), uniqueVisitors: safeCount(aggregate.visitors30Days) },
        daily,
        popularPages: popularRows.map((row) => ({ path: row.path, pageViews: safeCount(row.pageViews) })),
      },
    };
  }
}

function safeCount(value: bigint): number {
  const count = Number(value);
  if (!Number.isSafeInteger(count)) throw new Error("Site analytics count exceeds JavaScript's safe integer range.");
  return count;
}
