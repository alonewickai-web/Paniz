import { BadRequestException, Injectable, Logger, OnModuleDestroy, OnModuleInit } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { createSign } from "node:crypto";
import { Prisma } from "@prisma/client";
import { PrismaService } from "../database/prisma.service";
import { createAnalyticsXlsx } from "./xlsx-export";

type DateRange = { start: string; end: string; days: number; previousStart: string; previousEnd: string };
type SourceState = { state: "connected" | "needs_configuration" | "error"; reason: string | null };
type GoogleRow = { keys?: string[]; clicks?: number; impressions?: number; ctr?: number; position?: number };
type GaRow = { dimensionValues?: Array<{ value?: string }>; metricValues?: Array<{ value?: string }> };
type StoreProductRow = {
  id: bigint; name: string; slug: string; seoTitle: string | null; seoDescription: string | null;
  seoCanonicalUrl: string | null; images: Array<{ imagePath: string; altText: string | null }>;
  category: { id: bigint; name: string; slug: string } | null;
  slugRedirects: Array<{ oldSlug: string }>;
};

const GSC_SCOPE = "https://www.googleapis.com/auth/webmasters.readonly";
const GA_SCOPE = "https://www.googleapis.com/auth/analytics.readonly";
const TOKEN_URL = "https://oauth2.googleapis.com/token";
const GOOGLE_API_TIMEOUT_MS = 12_000;
const REPORT_CACHE_MS = 5 * 60_000;

@Injectable()
export class GoogleInsightsService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(GoogleInsightsService.name);
  private syncTimer?: NodeJS.Timeout;
  private readonly reportCache = new Map<string, { expiresAt: number; value: Promise<Record<string, unknown>> }>();
  private readonly accessTokens = new Map<string, { value: string; expiresAt: number }>();
  private readonly accessTokenRequests = new Map<string, Promise<string>>();

  constructor(private readonly config: ConfigService, private readonly prisma: PrismaService) {}

  onModuleInit() {
    if (!this.googleIdentityConfigured() || this.config.get<string>("GOOGLE_ANALYTICS_SYNC_ENABLED") === "false") return;
    this.syncTimer = setInterval(() => {
      void this.report("28").catch(() => this.logger.warn("Background SEO report refresh failed."));
    }, 30 * 60_000);
    this.syncTimer.unref();
  }

  onModuleDestroy() { if (this.syncTimer) clearInterval(this.syncTimer); }

  async report(rangeInput?: string, fromInput?: string, toInput?: string): Promise<Record<string, unknown>> {
    const range = parseRange(rangeInput, fromInput, toInput);
    for (const [key, entry] of this.reportCache) if (entry.expiresAt <= Date.now()) this.reportCache.delete(key);
    if (this.reportCache.size > 50) this.reportCache.delete(this.reportCache.keys().next().value!);
    const cacheKey = `${range.start}:${range.end}`;
    const cached = this.reportCache.get(cacheKey);
    if (cached && cached.expiresAt > Date.now()) return cached.value;

    const value = this.buildReport(range);
    this.reportCache.set(cacheKey, { expiresAt: Date.now() + REPORT_CACHE_MS, value });
    try {
      return await value;
    } catch (error) {
      this.reportCache.delete(cacheKey);
      throw error;
    }
  }

  async csv(rangeInput: string | undefined, fromInput: string | undefined, toInput: string | undefined, typeInput: string | undefined, category?: string): Promise<string> {
    const report = await this.report(rangeInput, fromInput, toInput);
    const table = analyticsExportTable(report.data as Record<string, unknown>, typeInput, category);
    return toCsv(table.headers, table.rows);
  }

  async xlsx(rangeInput: string | undefined, fromInput: string | undefined, toInput: string | undefined, typeInput: string | undefined, category?: string): Promise<Buffer> {
    const report = await this.report(rangeInput, fromInput, toInput);
    const table = analyticsExportTable(report.data as Record<string, unknown>, typeInput, category);
    return createAnalyticsXlsx([table.headers, ...table.rows]);
  }

  private async buildReport(range: DateRange): Promise<Record<string, unknown>> {
    const [gscResult, gaResult, storeResult] = await Promise.all([
      this.loadSearchConsole(range),
      this.loadAnalytics(range),
      this.loadStoreData(range),
    ]);

    const google = gscResult.data;
    const analytics = gaResult.data;
    const comparison = {
      googleClicks: deltaPercent(google?.totals.clicks ?? null, google?.previous.clicks ?? null),
      googleImpressions: deltaPercent(google?.totals.impressions ?? null, google?.previous.impressions ?? null),
      activeUsers: deltaPercent(analytics?.totals.activeUsers ?? null, analytics?.previous.activeUsers ?? null),
      users: deltaPercent(analytics?.totals.users ?? null, analytics?.previous.users ?? null),
      sessions: deltaPercent(analytics?.totals.sessions ?? null, analytics?.previous.sessions ?? null),
      googleCtr: deltaPercent(google ? ratio(google.totals.clicks, google.totals.impressions) : null, google ? ratio(google.previous.clicks, google.previous.impressions) : null),
      averagePosition: deltaPercent(google ? ratio(google.totals.weightedPosition, google.totals.impressions) : null, google ? ratio(google.previous.weightedPosition, google.previous.impressions) : null),
      conversionPercent: deltaPercent(analytics ? ratio(storeResult.totals.paidOrders, analytics.totals.sessions) : null, analytics ? ratio(storeResult.totals.previousPaidOrders, analytics.previous.sessions) : null),
      organicRevenue: deltaPercent(analytics?.organicRevenue ?? null, analytics?.previous.organicRevenue ?? null),
    };
    const queries = google?.queries.map((row) => ({
      query: row.key,
      clicks: row.clicks,
      impressions: row.impressions,
      ctrPercent: round(row.impressions ? row.clicks / row.impressions * 100 : 0, 2),
      averagePosition: round(row.position, 2),
      previousClicks: google.queryPrevious.get(row.key)?.clicks ?? null,
      clicksChangePercent: deltaPercent(row.clicks, google.queryPrevious.get(row.key)?.clicks ?? null),
      previousPosition: google.queryPrevious.get(row.key)?.position ?? null,
      positionChange: google.queryPrevious.has(row.key) ? round(row.position - google.queryPrevious.get(row.key)!.position, 2) : null,
    })) ?? [];
    const pages = mergePageMetrics(google?.pages ?? [], analytics?.pages ?? []);
    const productMetrics = new Map(pages.map((row) => [row.path, row]));
    const products = storeResult.products.map((product) => {
      const path = `/products/${product.slug}`;
      const matchedPages = [path, ...product.slugRedirects.map((alias) => `/products/${alias.oldSlug}`)]
        .map((productPath) => productMetrics.get(productPath)).filter((row) => row !== undefined);
      const googlePages = matchedPages.filter((row) => row.googleObserved);
      const analyticsPages = matchedPages.filter((row) => row.analyticsObserved);
      const googleClicks = google && googlePages.length ? googlePages.reduce((sum, row) => sum + row.googleClicks, 0) : null;
      const googleImpressions = google && googlePages.length ? googlePages.reduce((sum, row) => sum + row.googleImpressions, 0) : null;
      const gaPageViews = analytics && analyticsPages.length ? analyticsPages.reduce((sum, row) => sum + row.gaPageViews, 0) : null;
      const averagePosition = googleImpressions ? round(googlePages.reduce((sum, row) => sum + (row.averagePosition ?? 0) * row.googleImpressions, 0) / googleImpressions, 2) : null;
      const sold = storeResult.sales.get(product.id.toString()) ?? { paidOrders: 0, unitsSold: 0 };
      const imagesMissingAlt = product.images.filter((image) => !image.altText?.trim()).length;
      return {
        id: product.id.toString(),
        name: product.name,
        slug: product.slug,
        url: `https://panizstyle.ir${path}`,
        imagePath: product.images[0]?.imagePath ?? null,
        category: product.category?.name ?? null,
        googleClicks,
        googleImpressions,
        averagePosition,
        gaPageViews,
        paidOrders: sold.paidOrders,
        unitsSold: sold.unitsSold,
        productConversionPercent: gaPageViews
          ? round(sold.paidOrders / gaPageViews * 100, 2)
          : null,
        conversionDefinition: "سفارش پرداخت‌شدهٔ این محصول ÷ بازدید صفحهٔ محصول",
        hasSeoTitle: Boolean(product.seoTitle?.trim()),
        hasSeoDescription: Boolean(product.seoDescription?.trim()),
        canonicalUrl: product.seoCanonicalUrl,
        imagesMissingAlt,
      };
    });

    const paidOrders = storeResult.totals.paidOrders;
    const sessions = analytics?.totals.sessions ?? null;
    const conversionPercent = sessions && sessions > 0
      ? round(paidOrders / sessions * 100, 2)
      : null;
    const organicRevenue = analytics?.organicRevenue ?? null;
    const currencyCode = this.config.get<string>("GA4_CURRENCY_CODE")?.trim().toUpperCase() || null;
    const organicRevenueToman = organicRevenue !== null && currencyCode === "IRR"
      ? round(organicRevenue / 10, 0)
      : null;

    const alerts: Array<{ level: "warning" | "info"; source: string; message: string }> = [];
    const clickDrop = comparison.googleClicks;
    const alertThreshold = Math.max(10, Math.min(90, Number(this.config.get<string>("SEO_ALERT_DROP_PERCENT") ?? 30)));
    if (clickDrop !== null && clickDrop <= -alertThreshold) {
      alerts.push({ level: "warning", source: "Search Console", message: `کلیک‌های گوگل نسبت به دورهٔ قبل ${Math.abs(clickDrop)}٪ کاهش داشته‌اند.` });
    }
    if (comparison.googleCtr !== null && comparison.googleCtr <= -alertThreshold) {
      alerts.push({ level: "warning", source: "Search Console", message: `نرخ کلیک نسبت به دورهٔ قبل ${Math.abs(comparison.googleCtr)}٪ کاهش داشته است.` });
    }
    const positionThreshold = Math.max(1, Number(this.config.get<string>("SEO_ALERT_POSITION_DROP") ?? 3));
    const losingQuery = queries.find((row) => row.impressions >= 20 && row.positionChange !== null && row.positionChange >= positionThreshold);
    if (losingQuery) alerts.push({ level: "warning", source: "Search Console", message: `رتبهٔ عبارت «${losingQuery.query}» نسبت به دورهٔ قبل ${losingQuery.positionChange} پله افت داشته است.` });
    if (storeResult.audit.missingSeoTitle > 0 || storeResult.audit.missingSeoDescription > 0 || storeResult.audit.imagesMissingAlt > 0) {
      alerts.push({
        level: "info",
        source: "بررسی فروشگاه",
        message: `${storeResult.audit.missingSeoTitle} محصول عنوان سئو، ${storeResult.audit.missingSeoDescription} محصول توضیح سئو و ${storeResult.audit.imagesMissingAlt} تصویر متن جایگزین ندارند.`,
      });
    }
    if (gscResult.state.state === "needs_configuration") alerts.push({ level: "info", source: "Search Console", message: "اتصال Search Console نیازمند تنظیم دسترسی حساب گوگل است." });
    if (gaResult.state.state === "needs_configuration") alerts.push({ level: "info", source: "Google Analytics 4", message: "اتصال GA4 نیازمند تنظیم شناسهٔ اندازه‌گیری و دسترسی گزارش‌خوانی است." });

    const daily = buildDaily(range, google?.daily ?? [], google?.dailyPrevious ?? [], analytics?.daily ?? [], analytics?.dailyPrevious ?? []);
    const popularPages = pages
      .slice()
      .sort((left, right) => (right.gaPageViews ?? 0) - (left.gaPageViews ?? 0))
      .slice(0, 50)
      .map((row) => ({
        path: row.path,
        title: analyticsPageTitle(row.path, storeResult.products),
        googleClicks: google && row.googleObserved ? row.googleClicks : null,
        googleImpressions: google && row.googleObserved ? row.googleImpressions : null,
        averagePosition: google && row.googleObserved ? row.averagePosition : null,
        gaPageViews: analytics && row.analyticsObserved ? row.gaPageViews : null,
      }));

    return {
      data: {
        range: { start: range.start, end: range.end, days: range.days, previousStart: range.previousStart, previousEnd: range.previousEnd },
        sources: { searchConsole: gscResult.state, analytics: gaResult.state },
        metrics: {
          google: google ? {
            clicks: google.totals.clicks,
            impressions: google.totals.impressions,
            ctrPercent: google.totals.impressions ? round(google.totals.clicks / google.totals.impressions * 100, 2) : 0,
            averagePosition: google.totals.impressions ? round(google.totals.weightedPosition / google.totals.impressions, 2) : null,
          } : { clicks: null, impressions: null, ctrPercent: null, averagePosition: null },
          analytics: analytics ? {
            users: analytics.totals.users,
            activeUsers: analytics.totals.activeUsers,
            newUsers: analytics.totals.newUsers,
            sessions: analytics.totals.sessions,
            pageViews: analytics.totals.pageViews,
            ecommercePurchases: analytics.totals.purchases,
            purchaseRevenue: analytics.totals.purchaseRevenue,
            purchaseRevenueCurrency: currencyCode,
          } : { users: null, activeUsers: null, newUsers: null, sessions: null, pageViews: null, ecommercePurchases: null, purchaseRevenue: null, purchaseRevenueCurrency: currencyCode },
          store: {
            paidOrders,
            unitsSold: storeResult.totals.unitsSold,
            conversionPercent,
            conversionDefinition: "تعداد سفارش‌های پرداخت‌شدهٔ دیتابیس فروشگاه ÷ تعداد نشست‌های GA4 در همین بازه",
            organicRevenueToman,
            organicRevenueCurrency: currencyCode,
          },
          comparison,
        },
        daily,
        queries,
        pages: popularPages,
        products,
        trafficSources: analytics?.trafficSources ?? [],
        devices: analytics?.devices ?? [],
        audit: { ...storeResult.audit, sitemapStatus: "unknown", coreWebVitalsStatus: "unknown", indexingStatus: "unknown" },
        alerts,
        notes: [
          "عبارت‌های جست‌وجوی Search Console ممکن است همهٔ جست‌وجوها را شامل نشوند؛ این جدول فقط ردیف‌های گزارش‌شده را نشان می‌دهد.",
          "فروش از سفارش‌های پرداخت‌شدهٔ دیتابیس خوانده می‌شود. سفارش ثبت‌شده اما پرداخت‌نشده فروش محسوب نمی‌شود.",
          ...(organicRevenue !== null && !currencyCode ? ["ارز درآمد GA4 مشخص نشده است؛ درآمد منتسب به جست‌وجوی گوگل به تومان نمایش داده نمی‌شود."] : []),
          "وضعیت Core Web Vitals و ایندکس فقط پس از اتصال منبع رسمی مربوطه قابل گزارش است؛ مورد نامعلوم حدس زده نمی‌شود.",
          "تاریخ فروش‌های دیتابیس به وقت تهران است؛ روزهای Search Console و GA4 طبق منطقهٔ زمانی همان منبع گزارش می‌شوند.",
          ...(storeResult.audit.publishedProducts > 1000 ? ["جدول محصولات فعلاً هزار محصول تازه‌تر را پوشش می‌دهد؛ شمار کل محصولات در بررسی فنی جدا نمایش داده می‌شود."] : []),
        ],
        lastSyncedAt: gscResult.state.state === "connected" || gaResult.state.state === "connected" ? new Date().toISOString() : null,
      },
    };
  }

  private async loadSearchConsole(range: DateRange): Promise<{
    state: SourceState;
    data: null | {
      totals: { clicks: number; impressions: number; weightedPosition: number };
      previous: { clicks: number; impressions: number; weightedPosition: number };
      daily: Array<{ key: string; clicks: number; impressions: number; position: number }>;
      dailyPrevious: Array<{ key: string; clicks: number; impressions: number; position: number }>;
      queries: Array<{ key: string; clicks: number; impressions: number; position: number }>;
      queryPrevious: Map<string, { clicks: number; position: number }>;
      pages: Array<{ key: string; clicks: number; impressions: number; position: number }>;
    };
  }> {
    const siteUrl = this.config.get<string>("GOOGLE_SEARCH_CONSOLE_SITE_URL")?.trim();
    if (!siteUrl || !this.googleIdentityConfigured()) return { state: needsConfiguration("دسترسی حساب Search Console هنوز برای فروشگاه تنظیم نشده است."), data: null };
    try {
      const [dailyRows, currentQueries, previousQueries, pageRows, previousDaily] = await Promise.all([
        this.searchConsoleRows(siteUrl, range.start, range.end, ["date"]),
        this.searchConsoleRows(siteUrl, range.start, range.end, ["query"]),
        this.searchConsoleRows(siteUrl, range.previousStart, range.previousEnd, ["query"]),
        this.searchConsoleRows(siteUrl, range.start, range.end, ["page"]),
        this.searchConsoleRows(siteUrl, range.previousStart, range.previousEnd, ["date"]),
      ]);
      const totals = sumGoogleRows(dailyRows);
      const previousTotals = sumGoogleRows(previousDaily);
      return {
        state: connected(),
        data: {
          totals,
          previous: previousTotals,
          daily: dailyRows.map((row) => ({ key: row.keys?.[0] ?? "", clicks: numeric(row.clicks), impressions: numeric(row.impressions), position: numeric(row.position) })),
          dailyPrevious: previousDaily.map((row) => ({ key: row.keys?.[0] ?? "", clicks: numeric(row.clicks), impressions: numeric(row.impressions), position: numeric(row.position) })),
          queries: currentQueries.map((row) => ({ key: row.keys?.[0] ?? "", clicks: numeric(row.clicks), impressions: numeric(row.impressions), position: numeric(row.position) })),
          queryPrevious: new Map(previousQueries.map((row) => [row.keys?.[0] ?? "", { clicks: numeric(row.clicks), position: numeric(row.position) }])),
          pages: pageRows.map((row) => ({ key: row.keys?.[0] ?? "", clicks: numeric(row.clicks), impressions: numeric(row.impressions), position: numeric(row.position) })),
        },
      };
    } catch {
      this.logger.warn("Search Console report retrieval failed.");
      return { state: sourceError("گزارش Search Console در دسترس نیست؛ دسترسی و وضعیت property را بررسی کنید."), data: null };
    }
  }

  private async loadAnalytics(range: DateRange): Promise<{
    state: SourceState;
    data: null | {
      totals: { users: number; activeUsers: number; newUsers: number; sessions: number; pageViews: number; purchases: number; purchaseRevenue: number };
      previous: { users: number; activeUsers: number; sessions: number; organicRevenue: number };
      organicRevenue: number | null;
      daily: Array<{ key: string; users: number; sessions: number; pageViews: number }>;
      dailyPrevious: Array<{ key: string; users: number; sessions: number; pageViews: number }>;
      pages: Array<{ key: string; pageViews: number }>;
      trafficSources: Array<{ source: string; sessions: number }>;
      devices: Array<{ device: string; users: number; sessions: number }>;
    };
  }> {
    const propertyId = this.config.get<string>("GA4_PROPERTY_ID")?.trim();
    if (!propertyId || !this.googleIdentityConfigured()) return { state: needsConfiguration("دسترسی گزارش حساب GA4 هنوز برای فروشگاه تنظیم نشده است."), data: null };
    try {
      const [totals, previous, dailyRows, previousDailyRows, pageRows, organicRows, previousOrganicRows, sourceRows, deviceRows] = await Promise.all([
        this.analyticsReport(propertyId, range.start, range.end, [], ["totalUsers", "activeUsers", "newUsers", "sessions", "screenPageViews", "ecommercePurchases", "purchaseRevenue"]),
        this.analyticsReport(propertyId, range.previousStart, range.previousEnd, [], ["totalUsers", "activeUsers", "sessions"]),
        this.analyticsReport(propertyId, range.start, range.end, ["date"], ["totalUsers", "sessions", "screenPageViews"]),
        this.analyticsReport(propertyId, range.previousStart, range.previousEnd, ["date"], ["totalUsers", "sessions", "screenPageViews"]),
        this.analyticsReport(propertyId, range.start, range.end, ["pagePath"], ["screenPageViews"], "pagePath"),
        this.analyticsReport(propertyId, range.start, range.end, [], ["purchaseRevenue"], undefined, undefined, undefined, true),
        this.analyticsReport(propertyId, range.previousStart, range.previousEnd, [], ["purchaseRevenue"], undefined, undefined, undefined, true),
        this.analyticsReport(propertyId, range.start, range.end, ["sessionDefaultChannelGroup"], ["sessions"]),
        this.analyticsReport(propertyId, range.start, range.end, ["deviceCategory"], ["totalUsers", "sessions"]),
      ]);
      return {
        state: connected(),
        data: {
          totals: {
            users: metric(totals, "totalUsers"),
            activeUsers: metric(totals, "activeUsers"),
            newUsers: metric(totals, "newUsers"),
            sessions: metric(totals, "sessions"),
            pageViews: metric(totals, "screenPageViews"),
            purchases: metric(totals, "ecommercePurchases"),
            purchaseRevenue: metric(totals, "purchaseRevenue"),
          },
          previous: { users: metric(previous, "totalUsers"), activeUsers: metric(previous, "activeUsers"), sessions: metric(previous, "sessions"), organicRevenue: metric(previousOrganicRows, "purchaseRevenue") },
          organicRevenue: organicRows.rowCount ? metric(organicRows, "purchaseRevenue") : 0,
          daily: dailyRows.rows.map((row) => ({
            key: row.dimensionValues?.[0]?.value ?? "",
            users: metricRow(dailyRows, row, "totalUsers"),
            sessions: metricRow(dailyRows, row, "sessions"),
            pageViews: metricRow(dailyRows, row, "screenPageViews"),
          })),
          dailyPrevious: previousDailyRows.rows.map((row) => ({
            key: row.dimensionValues?.[0]?.value ?? "",
            users: metricRow(previousDailyRows, row, "totalUsers"),
            sessions: metricRow(previousDailyRows, row, "sessions"),
            pageViews: metricRow(previousDailyRows, row, "screenPageViews"),
          })),
          pages: pageRows.rows.map((row) => ({ key: row.dimensionValues?.[0]?.value ?? "", pageViews: metricRow(pageRows, row, "screenPageViews") })),
          trafficSources: sourceRows.rows.map((row) => ({ source: row.dimensionValues?.[0]?.value ?? "", sessions: metricRow(sourceRows, row, "sessions") })),
          devices: deviceRows.rows.map((row) => ({ device: row.dimensionValues?.[0]?.value ?? "", users: metricRow(deviceRows, row, "totalUsers"), sessions: metricRow(deviceRows, row, "sessions") })),
        },
      };
    } catch {
      this.logger.warn("GA4 report retrieval failed.");
      return { state: sourceError("گزارش GA4 در دسترس نیست؛ شناسهٔ property و نقش گزارش‌خوان را بررسی کنید."), data: null };
    }
  }

  private async loadStoreData(range: DateRange): Promise<{
    products: StoreProductRow[];
    sales: Map<string, { paidOrders: number; unitsSold: number }>;
    totals: { paidOrders: number; previousPaidOrders: number; unitsSold: number };
    audit: { publishedProducts: number; missingSeoTitle: number; missingSeoDescription: number; imagesMissingAlt: number };
  }> {
    const endExclusive = addDays(range.end, 1);
    const indexableProductWhere: Prisma.ProductWhereInput = {
      status: "published",
      publishedAt: { lte: new Date() },
      deletedAt: null,
      variants: { some: { isActive: true } },
      category: { is: { isActive: true } },
    };
    const [products, currentSales, auditRows, paidOrderCount, previousPaidOrders] = await Promise.all([
      this.prisma.product.findMany({
        where: indexableProductWhere,
        take: 1000,
        orderBy: [{ publishedAt: "desc" }, { id: "desc" }],
        select: {
          id: true, name: true, slug: true, seoTitle: true, seoDescription: true, seoCanonicalUrl: true,
          images: { orderBy: [{ isPrimary: "desc" }, { sortOrder: "asc" }], select: { imagePath: true, altText: true } },
          category: { select: { id: true, name: true, slug: true } },
          slugRedirects: { select: { oldSlug: true } },
        },
      }),
      this.paidProductSales(range.start, endExclusive),
      this.prisma.product.aggregate({
        where: indexableProductWhere,
        _count: { _all: true },
      }),
      this.prisma.order.count({ where: { paymentStatus: "paid", createdAt: { gte: storeDateStart(range.start), lt: storeDateStart(endExclusive) } } }),
      this.prisma.order.count({ where: { paymentStatus: "paid", createdAt: { gte: storeDateStart(range.previousStart), lt: storeDateStart(range.start) } } }),
    ]);
    const missingTitle = await this.prisma.product.count({ where: { ...indexableProductWhere, OR: [{ seoTitle: null }, { seoTitle: "" }] } });
    const missingDescription = await this.prisma.product.count({ where: { ...indexableProductWhere, OR: [{ seoDescription: null }, { seoDescription: "" }] } });
    const imagesMissingAlt = await this.prisma.productImage.count({
      where: { product: { is: indexableProductWhere }, OR: [{ altText: null }, { altText: "" }] },
    });
    const unitsSold = [...currentSales.values()].reduce((sum, item) => sum + item.unitsSold, 0);
    return {
      products,
      sales: currentSales,
      totals: { paidOrders: paidOrderCount, previousPaidOrders, unitsSold },
      audit: { publishedProducts: auditRows._count._all, missingSeoTitle: missingTitle, missingSeoDescription: missingDescription, imagesMissingAlt },
    };
  }

  private async paidProductSales(start: string, endExclusive: string): Promise<Map<string, { paidOrders: number; unitsSold: number }>> {
    const rows = await this.prisma.$queryRaw<Array<{ productId: bigint; paidOrders: bigint; unitsSold: bigint }>>`
      SELECT oi.product_id AS productId,
             CAST(COUNT(DISTINCT o.id) AS UNSIGNED) AS paidOrders,
             CAST(COALESCE(SUM(oi.quantity), 0) AS UNSIGNED) AS unitsSold
      FROM order_items oi
      INNER JOIN orders o ON o.id = oi.order_id
      WHERE oi.product_id IS NOT NULL
        AND o.payment_status = 'paid'
        AND o.created_at >= ${storeDateStart(start)}
        AND o.created_at < ${storeDateStart(endExclusive)}
      GROUP BY oi.product_id
    `;
    return new Map(rows.map((row) => [row.productId.toString(), { paidOrders: toSafeNumber(row.paidOrders), unitsSold: toSafeNumber(row.unitsSold) }]));
  }

  private async searchConsoleRows(siteUrl: string, startDate: string, endDate: string, dimensions: string[]): Promise<GoogleRow[]> {
    const token = await this.getAccessToken([GSC_SCOPE]);
    const endpoint = `https://searchconsole.googleapis.com/webmasters/v3/sites/${encodeURIComponent(siteUrl)}/searchAnalytics/query`;
    const response = await fetch(endpoint, {
      method: "POST",
      headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
      body: JSON.stringify({ startDate, endDate, dimensions, rowLimit: dimensions[0] === "date" ? 1000 : 1000 }),
      signal: AbortSignal.timeout(GOOGLE_API_TIMEOUT_MS),
    });
    if (!response.ok) throw new Error("Search Console request failed.");
    const payload = await response.json() as { rows?: GoogleRow[] };
    return payload.rows ?? [];
  }

  private async analyticsReport(
    rawPropertyId: string,
    startDate: string,
    endDate: string,
    dimensions: string[],
    metrics: string[],
    sortDimension?: string,
    filterDimension?: string,
    filterValue?: string,
    googleOrganicOnly = false,
  ): Promise<{ dimensionHeaders: Array<{ name: string }>; metricHeaders: Array<{ name: string }>; rows: GaRow[]; rowCount: number }> {
    const token = await this.getAccessToken([GA_SCOPE]);
    const propertyId = rawPropertyId.replace(/^properties\//u, "");
    if (!/^\d{3,20}$/u.test(propertyId)) throw new Error("Invalid Analytics property ID.");
    const endpoint = `https://analyticsdata.googleapis.com/v1beta/properties/${propertyId}:runReport`;
    const response = await fetch(endpoint, {
      method: "POST",
      headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        dateRanges: [{ startDate, endDate }],
        ...(this.config.get<string>("GA4_CURRENCY_CODE")?.trim() ? { currencyCode: this.config.get<string>("GA4_CURRENCY_CODE")!.trim().toUpperCase() } : {}),
        dimensions: dimensions.map((name) => ({ name })),
        metrics: metrics.map((name) => ({ name })),
        ...(sortDimension ? { orderBys: [{ dimension: { dimensionName: sortDimension }, desc: true }] } : {}),
        ...(googleOrganicOnly ? { dimensionFilter: { andGroup: { expressions: [
          { filter: { fieldName: "sessionSource", stringFilter: { matchType: "EXACT", value: "google" } } },
          { filter: { fieldName: "sessionMedium", stringFilter: { matchType: "EXACT", value: "organic" } } },
        ] } } } : filterDimension && filterValue ? { dimensionFilter: { filter: { fieldName: filterDimension, stringFilter: { matchType: "EXACT", value: filterValue } } } } : {}),
        limit: dimensions.length ? "10000" : "1",
      }),
      signal: AbortSignal.timeout(GOOGLE_API_TIMEOUT_MS),
    });
    if (!response.ok) throw new Error("Analytics report request failed.");
    const payload = await response.json() as { dimensionHeaders?: Array<{ name: string }>; metricHeaders?: Array<{ name: string }>; rows?: GaRow[]; rowCount?: number };
    return { dimensionHeaders: payload.dimensionHeaders ?? [], metricHeaders: payload.metricHeaders ?? [], rows: payload.rows ?? [], rowCount: payload.rowCount ?? 0 };
  }

  private googleIdentityConfigured(): boolean {
    return Boolean(this.config.get<string>("GOOGLE_SERVICE_ACCOUNT_EMAIL")?.trim() && this.config.get<string>("GOOGLE_SERVICE_ACCOUNT_PRIVATE_KEY")?.trim());
  }

  private async getAccessToken(scopes: string[]): Promise<string> {
    const scopeKey = [...scopes].sort().join(" ");
    const cached = this.accessTokens.get(scopeKey);
    if (cached && cached.expiresAt > Date.now() + 60_000) return cached.value;
    const inFlight = this.accessTokenRequests.get(scopeKey);
    if (inFlight) return inFlight;
    const request = this.requestAccessToken(scopes, scopeKey);
    this.accessTokenRequests.set(scopeKey, request);
    try { return await request; } finally { this.accessTokenRequests.delete(scopeKey); }
  }

  private async requestAccessToken(scopes: string[], scopeKey: string): Promise<string> {
    const email = this.config.get<string>("GOOGLE_SERVICE_ACCOUNT_EMAIL")?.trim();
    const privateKey = this.config.get<string>("GOOGLE_SERVICE_ACCOUNT_PRIVATE_KEY")?.replace(/\\n/gu, "\n").trim();
    if (!email || !privateKey) throw new Error("Google service account credentials are missing.");
    const now = Math.floor(Date.now() / 1000);
    const unsigned = `${base64url(JSON.stringify({ alg: "RS256", typ: "JWT" }))}.${base64url(JSON.stringify({
      iss: email,
      scope: scopes.join(" "),
      aud: TOKEN_URL,
      iat: now,
      exp: now + 3600,
    }))}`;
    const signer = createSign("RSA-SHA256");
    signer.update(unsigned);
    signer.end();
    const assertion = `${unsigned}.${signer.sign(privateKey).toString("base64url")}`;
    const response = await fetch(TOKEN_URL, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion }).toString(),
      signal: AbortSignal.timeout(GOOGLE_API_TIMEOUT_MS),
    });
    if (!response.ok) throw new Error("Google authorization failed.");
    const payload = await response.json() as { access_token?: string; expires_in?: number };
    if (!payload.access_token) throw new Error("Google authorization returned no token.");
    this.accessTokens.set(scopeKey, { value: payload.access_token, expiresAt: Date.now() + (payload.expires_in ?? 3600) * 1000 });
    return payload.access_token;
  }
}

function parseRange(input?: string, from?: string, to?: string): DateRange {
  if (input && !["7", "7d", "28", "28d", "90", "90d", "custom"].includes(input)) {
    throw new BadRequestException({ code: "INVALID_DATE_RANGE", message: "بازهٔ گزارش معتبر نیست." });
  }
  let start: string;
  let end: string;
  if (input === "custom") {
    if (!isIsoDate(from) || !isIsoDate(to) || from > to || to > todayIranDate()) {
      throw new BadRequestException({ code: "INVALID_DATE_RANGE", message: "برای بازهٔ دلخواه تاریخ شروع و پایان معتبر وارد کنید." });
    }
    start = from;
    end = to;
  } else {
    const days = input === "7" || input === "7d" ? 7 : input === "90" || input === "90d" ? 90 : 28;
    end = todayIranDate();
    start = addDays(end, -(days - 1));
  }
  const days = Math.floor((dateStart(end).getTime() - dateStart(start).getTime()) / 86_400_000) + 1;
  if (days > 366) throw new BadRequestException({ code: "DATE_RANGE_TOO_LARGE", message: "بازهٔ گزارش نمی‌تواند بیشتر از ۳۶۶ روز باشد." });
  return { start, end, days, previousStart: addDays(start, -days), previousEnd: addDays(start, -1) };
}

function todayIranDate(): string {
  const parts = new Intl.DateTimeFormat("en-CA", { timeZone: "Asia/Tehran", year: "numeric", month: "2-digit", day: "2-digit" }).formatToParts(new Date());
  const value = (type: string) => parts.find((part) => part.type === type)?.value ?? "";
  return `${value("year")}-${value("month")}-${value("day")}`;
}

function isIsoDate(value?: string): value is string {
  if (!value || !/^\d{4}-\d{2}-\d{2}$/u.test(value)) return false;
  const date = new Date(`${value}T00:00:00.000Z`);
  return !Number.isNaN(date.getTime()) && date.toISOString().slice(0, 10) === value;
}

function dateStart(value: string): Date { return new Date(`${value}T00:00:00.000Z`); }
function storeDateStart(value: string): Date { return new Date(dateStart(value).getTime() - 210 * 60_000); }
function addDays(value: string, amount: number): string {
  const date = dateStart(value);
  date.setUTCDate(date.getUTCDate() + amount);
  return date.toISOString().slice(0, 10);
}

function sumGoogleRows(rows: GoogleRow[]) {
  return rows.reduce<{ clicks: number; impressions: number; weightedPosition: number }>((total, row) => {
    const impressions = numeric(row.impressions);
    return {
      clicks: total.clicks + numeric(row.clicks),
      impressions: total.impressions + impressions,
      weightedPosition: total.weightedPosition + numeric(row.position) * impressions,
    };
  }, { clicks: 0, impressions: 0, weightedPosition: 0 });
}

function metric(report: { metricHeaders: Array<{ name: string }>; rows: GaRow[] }, name: string): number {
  return metricRow(report, report.rows[0], name);
}

function metricRow(report: { metricHeaders: Array<{ name: string }> }, row: GaRow | undefined, name: string): number {
  const index = report.metricHeaders.findIndex((header) => header.name === name);
  return numeric(index >= 0 ? row?.metricValues?.[index]?.value : 0);
}

function numeric(value: unknown): number {
  const parsed = typeof value === "number" ? value : Number(value ?? 0);
  return Number.isFinite(parsed) ? parsed : 0;
}

function round(value: number, decimals: number): number {
  const scale = 10 ** decimals;
  return Math.round((value + Number.EPSILON) * scale) / scale;
}

function deltaPercent(current: number | null, previous: number | null): number | null {
  if (current === null || previous === null || previous <= 0) return null;
  return round((current - previous) / previous * 100, 1);
}

function ratio(numerator: number, denominator: number): number | null { return denominator > 0 ? numerator / denominator : null; }

function connected(): SourceState { return { state: "connected", reason: null }; }
function needsConfiguration(reason: string): SourceState { return { state: "needs_configuration", reason }; }
function sourceError(reason: string): SourceState { return { state: "error", reason }; }

function base64url(value: string): string { return Buffer.from(value).toString("base64url"); }
function toSafeNumber(value: bigint): number {
  const result = Number(value);
  if (!Number.isSafeInteger(result)) throw new Error("Analytics count exceeds the safe integer range.");
  return result;
}

function mergePageMetrics(
  google: Array<{ key: string; clicks: number; impressions: number; position: number }>,
  analytics: Array<{ key: string; pageViews: number }>,
) {
  const pages = new Map<string, { path: string; googleClicks: number; googleImpressions: number; weightedPosition: number; gaPageViews: number; googleObserved: boolean; analyticsObserved: boolean }>();
  const normalizedPath = (value: string) => {
    try { return new URL(value, "https://panizstyle.ir").pathname.replace(/\/$/u, "") || "/"; } catch { return value.split("?")[0] || "/"; }
  };
  for (const row of google) {
    const path = normalizedPath(row.key);
    const current = pages.get(path) ?? { path, googleClicks: 0, googleImpressions: 0, weightedPosition: 0, gaPageViews: 0, googleObserved: false, analyticsObserved: false };
    current.googleClicks += row.clicks;
    current.googleImpressions += row.impressions;
    current.weightedPosition += row.position * row.impressions;
    current.googleObserved = true;
    pages.set(path, current);
  }
  for (const row of analytics) {
    const path = normalizedPath(row.key);
    const current = pages.get(path) ?? { path, googleClicks: 0, googleImpressions: 0, weightedPosition: 0, gaPageViews: 0, googleObserved: false, analyticsObserved: false };
    current.gaPageViews += row.pageViews;
    current.analyticsObserved = true;
    pages.set(path, current);
  }
  return [...pages.values()].map((row) => ({
    path: row.path,
    googleClicks: row.googleClicks,
    googleImpressions: row.googleImpressions,
    averagePosition: row.googleImpressions ? round(row.weightedPosition / row.googleImpressions, 2) : null,
    gaPageViews: row.gaPageViews,
    googleObserved: row.googleObserved,
    analyticsObserved: row.analyticsObserved,
  }));
}

function buildDaily(
  range: DateRange,
  google: Array<{ key: string; clicks: number; impressions: number; position: number }>,
  googlePrevious: Array<{ key: string; clicks: number; impressions: number; position: number }>,
  analytics: Array<{ key: string; users: number; sessions: number; pageViews: number }>,
  analyticsPrevious: Array<{ key: string; users: number; sessions: number; pageViews: number }>,
) {
  const googleByDay = new Map(google.map((row) => [row.key, row]));
  const googlePreviousByDay = new Map(googlePrevious.map((row) => [row.key, row]));
  const analyticsByDay = new Map(analytics.map((row) => [row.key, row]));
  const analyticsPreviousByDay = new Map(analyticsPrevious.map((row) => [row.key, row]));
  return Array.from({ length: range.days }, (_, index) => {
    const date = addDays(range.start, index);
    const previousDate = addDays(range.previousStart, index);
    const googleRow = googleByDay.get(date.replace(/-/gu, "")) ?? googleByDay.get(date);
    const googlePreviousRow = googlePreviousByDay.get(previousDate.replace(/-/gu, "")) ?? googlePreviousByDay.get(previousDate);
    const analyticsRow = analyticsByDay.get(date.replace(/-/gu, "")) ?? analyticsByDay.get(date);
    const analyticsPreviousRow = analyticsPreviousByDay.get(previousDate.replace(/-/gu, "")) ?? analyticsPreviousByDay.get(previousDate);
    return {
      date,
      googleClicks: googleRow?.clicks ?? null,
      googleImpressions: googleRow?.impressions ?? null,
      googlePosition: googleRow ? round(googleRow.position, 2) : null,
      previousGoogleClicks: googlePreviousRow?.clicks ?? null,
      previousGoogleImpressions: googlePreviousRow?.impressions ?? null,
      previousVisitors: analyticsPreviousRow?.users ?? null,
      visitors: analyticsRow?.users ?? null,
      sessions: analyticsRow?.sessions ?? null,
      pageViews: analyticsRow?.pageViews ?? null,
    };
  });
}

function analyticsExportTable(data: Record<string, unknown>, typeInput?: string, category?: string): { headers: string[]; rows: unknown[][] } {
  const type = typeInput ?? "products";
  if (type === "summary") {
    const metrics = data.metrics as Record<string, Record<string, unknown>>;
    const range = data.range as Record<string, unknown>;
    const metricRows: unknown[][] = [
      ["کلیک گوگل", "Search Console", metrics.google.clicks, metrics.comparison.googleClicks],
      ["نمایش در گوگل", "Search Console", metrics.google.impressions, metrics.comparison.googleImpressions],
      ["نرخ کلیک درصد", "Search Console", metrics.google.ctrPercent, metrics.comparison.googleCtr],
      ["میانگین رتبه", "Search Console", metrics.google.averagePosition, metrics.comparison.averagePosition],
      ["بازدیدکنندگان", "GA4", metrics.analytics.users, metrics.comparison.users],
      ["کاربران فعال", "GA4", metrics.analytics.activeUsers, metrics.comparison.activeUsers],
      ["نشست‌ها", "GA4", metrics.analytics.sessions, metrics.comparison.sessions],
      ["سفارش پرداخت‌شده", "دیتابیس فروشگاه", metrics.store.paidOrders, null],
      ["نرخ تبدیل درصد", "دیتابیس فروشگاه ÷ نشست‌های GA4", metrics.store.conversionPercent, metrics.comparison.conversionPercent],
    ];
    return { headers: ["شاخص", "منبع", "مقدار دوره", "تغییر نسبت به دوره قبل درصد", "از", "تا"], rows: metricRows.map((row) => [...row, range.start, range.end]) };
  }
  if (type === "queries") return {
    headers: ["عبارت جست‌وجو", "کلیک", "نمایش", "نرخ کلیک درصد", "میانگین رتبه", "کلیک دوره قبل"],
    rows: (data.queries as Array<Record<string, unknown>> ?? []).map((row) => [row.query, row.clicks, row.impressions, row.ctrPercent, row.averagePosition, row.previousClicks]),
  };
  if (type === "pages") return {
    headers: ["عنوان صفحه", "نشانی صفحه", "کلیک گوگل", "نمایش گوگل", "بازدید GA4"],
    rows: (data.pages as Array<Record<string, unknown>> ?? []).map((row) => [row.title, row.path, row.googleClicks, row.googleImpressions, row.gaPageViews]),
  };
  if (type === "products") return {
    headers: ["محصول", "نشانی", "کلیک گوگل", "نمایش گوگل", "رتبه", "بازدید صفحه", "سفارش پرداخت‌شده", "تعداد فروش", "عنوان سئو", "توضیح سئو", "تصاویر بدون متن جایگزین"],
    rows: (data.products as Array<Record<string, unknown>> ?? [])
      .filter((row) => !category || row.category === category)
      .map((row) => [row.name, row.url, row.googleClicks, row.googleImpressions, row.averagePosition, row.gaPageViews, row.paidOrders, row.unitsSold, row.hasSeoTitle ? "دارد" : "ندارد", row.hasSeoDescription ? "دارد" : "ندارد", row.imagesMissingAlt]),
  };
  throw new BadRequestException({ code: "INVALID_REPORT_TYPE", message: "نوع گزارش انتخاب‌شده معتبر نیست." });
}

function analyticsPageTitle(path: string, products: StoreProductRow[]): string {
  const product = products.find((item) => path === `/products/${item.slug}` || item.slugRedirects.some((alias) => path === `/products/${alias.oldSlug}`));
  if (product) return `محصول ${product.name}`;
  return ({ "/": "صفحهٔ اصلی", "/products": "فهرست محصولات", "/account": "حساب کاربری", "/cart": "سبد خرید", "/checkout": "تسویه‌حساب", "/favorites": "علاقه‌مندی‌ها", "/about": "دربارهٔ فروشگاه", "/contact": "تماس با فروشگاه" } as Record<string, string>)[path] ?? "سایر صفحه‌ها";
}

function toCsv(headers: string[], rows: unknown[][]): string {
  const escape = (value: unknown) => {
    let text = value === null || value === undefined ? "" : String(value);
    if (/^[=+@\-\t\r]/u.test(text)) text = `'${text}`;
    return `"${text.replace(/"/gu, '""')}"`;
  };
  return `\uFEFF${[headers, ...rows].map((row) => row.map(escape).join(",")).join("\r\n")}`;
}
