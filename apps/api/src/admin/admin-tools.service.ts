import { hasAdminPermission, requireAdminPermission } from "../admin-auth/admin-permissions";
import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
  OnModuleDestroy,
  OnModuleInit,
  ServiceUnavailableException,
} from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { Prisma } from "@prisma/client";
import { execFile as execFileCallback } from "node:child_process";
import { randomUUID } from "node:crypto";
import { mkdir, readFile, readdir, rm, stat, writeFile } from "node:fs/promises";
import { basename, join, resolve, sep } from "node:path";
import { promisify } from "node:util";
import { AuthenticatedAdmin } from "../admin-auth/admin-session.guard";
import { PrismaService } from "../database/prisma.service";
import { RubikaBotService } from "../integrations/rubika/rubika.service";
import { uploadRoot } from "../uploads/upload-storage";
import { WebPushService } from "../push/web-push.service";

const execFile = promisify(execFileCallback);
const MAX_AUDIENCE = 20_000;
const ALLOWED_CHANNELS = new Set(["rubika", "instagram"]);
const socialProductSelect = {
  id: true,
  name: true,
  slug: true,
  seoTitle: true,
  shortDescription: true,
  variants: {
    where: { isActive: true },
    orderBy: [{ createdAt: "asc" }, { id: "asc" }],
    select: { sku: true, colorName: true, sizeLabel: true },
  },
} satisfies Prisma.ProductSelect;
type SocialProduct = Prisma.ProductGetPayload<{ select: typeof socialProductSelect }>;

type AudienceFilters = {
  q?: string;
  city?: string;
  registration?: "any" | "under_year" | "over_year";
  purchaseSort?: "none" | "recent" | "oldest";
  productId?: string;
};

@Injectable()
export class AdminToolsService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(AdminToolsService.name);
  private socialTimer?: NodeJS.Timeout;
  private smsTimer?: NodeJS.Timeout;
  private rubikaTimer?: NodeJS.Timeout;
  private rubikaProductTimer?: NodeJS.Timeout;
  private backupTimer?: NodeJS.Timeout;
  private socialBusy = false;
  private socialRunRequested = false;
  private smsBusy = false;
  private rubikaBusy = false;
  private rubikaProductBusy = false;
  private readonly pendingRubikaProductIds = new Map<string, bigint | undefined>();
  private backupBusy = false;

  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
    private readonly rubika: RubikaBotService,
    private readonly push: WebPushService,
  ) {}

  async onModuleInit(): Promise<void> {
    try { await this.recoverInterruptedJobs(); }
    catch (error) { this.logger.warn(`Could not recover interrupted work: ${error instanceof Error ? error.message : "unknown error"}`); }
    this.socialTimer = setInterval(() => void this.publishDuePosts(), 5_000);
    this.socialTimer.unref();
    if (this.smsCampaignWorkerEnabled()) {
      this.smsTimer = setInterval(() => void this.processQueuedSms(), 15_000);
      this.smsTimer.unref();
    } else {
      this.logger.log("SMS campaign worker is disabled by configuration.");
    }
    this.rubikaTimer = setInterval(() => void this.processQueuedRubika(), 15_000);
    this.rubikaTimer.unref();
    this.rubikaProductTimer = setInterval(() => void this.publishOldestAvailableProduct(), 150 * 60_000);
    this.rubikaProductTimer.unref();
    this.backupTimer = setInterval(() => void this.ensureDailyBackup(), 60 * 60_000);
    this.backupTimer.unref();
    setTimeout(() => void this.publishDuePosts(), 5_000).unref();
    if (this.smsCampaignWorkerEnabled()) setTimeout(() => void this.processQueuedSms(), 8_000).unref();
    setTimeout(() => void this.processQueuedRubika(), 8_000).unref();
    setTimeout(() => void this.ensureDailyBackup(), 15_000).unref();
  }

  onModuleDestroy(): void {
    if (this.socialTimer) clearInterval(this.socialTimer);
    if (this.smsTimer) clearInterval(this.smsTimer);
    if (this.rubikaTimer) clearInterval(this.rubikaTimer);
    if (this.rubikaProductTimer) clearInterval(this.rubikaProductTimer);
    if (this.backupTimer) clearInterval(this.backupTimer);
  }

  async listCustomers(admin: AuthenticatedAdmin, query: Record<string, string>) {
    requireAdminPermission(admin, "customers.view");
    const filters = normalizeFilters(query);
    const page = boundedInt(query.page, 1, 1, 100_000);
    const pageSize = boundedInt(query.pageSize, 30, 1, 100);
    const { customers, total, capped } = await this.loadCustomers(filters, "all", false);
    const start = (page - 1) * pageSize;
    return { data: {
      items: customers.slice(start, start + pageSize).map(toCustomerSummary),
      meta: { page, pageSize, total, capped },
    } };
  }

  async productOptions(admin: AuthenticatedAdmin) {

    const products = await this.prisma.product.findMany({
      where: { deletedAt: null }, orderBy: { name: "asc" }, take: 500,
      select: { id: true, name: true, status: true },
    });
    return { data: products.map((item) => ({ id: item.id.toString(), name: item.name, status: item.status })) };
  }

  async socialProducts(admin: AuthenticatedAdmin) {

    const products = await this.prisma.product.findMany({
      where: {
        status: "published",
        publishedAt: { lte: new Date() },
        deletedAt: null,
        category: { is: { isActive: true } },
        variants: { some: { isActive: true } },
      },
      orderBy: [{ name: "asc" }, { id: "asc" }],
      take: 500,
      select: socialProductSelect,
    });
    const siteBaseUrl = this.publicWebBaseUrl();
    return { data: products.map((product) => this.toSocialProduct(product, siteBaseUrl)) };
  }

  async listCoupons(admin: AuthenticatedAdmin) {
    requireAdminPermission(admin, "marketing.campaign.manage");
    const coupons = await this.prisma.coupon.findMany({ orderBy: { createdAt: "desc" }, take: 200 });
    return { data: coupons.map(toCoupon) };
  }

  async saveCoupon(admin: AuthenticatedAdmin, idText: string | null, input: Record<string, unknown>) {
    requireAdminPermission(admin, "marketing.campaign.manage");
    const code = requiredText(input.code, "code", 64).toUpperCase().replace(/\s+/g, "");
    if (!/^[A-Z0-9_-]{3,64}$/.test(code)) throw badInput("Coupon code must contain 3-64 letters, numbers, _ or -.");
    const discountType = input.discountType === "percent" ? "percent" : input.discountType === "fixed" ? "fixed" : "";
    if (!discountType) throw badInput("discountType must be percent or fixed.");
    const discountValue = Number(input.discountValue);
    if (!Number.isFinite(discountValue) || discountValue <= 0 || (discountType === "percent" && discountValue > 100)) {
      throw badInput("Discount value is outside its allowed range.");
    }
    if (discountType === "fixed" && !Number.isSafeInteger(discountValue)) {
      throw badInput("Fixed discounts must be a whole number of toman.");
    }
    const minOrderToman = integerBigInt(input.minOrderToman ?? 0, "minOrderToman");
    const maxDiscountToman = input.maxDiscountToman === null || input.maxDiscountToman === undefined || input.maxDiscountToman === ""
      ? null : integerBigInt(input.maxDiscountToman, "maxDiscountToman");
    const usageLimit = optionalPositiveInt(input.usageLimit, "usageLimit");
    const perCustomerLimit = optionalPositiveInt(input.perCustomerLimit, "perCustomerLimit");
    const startsAt = optionalDate(input.startsAt, "startsAt");
    const endsAt = optionalDate(input.endsAt, "endsAt");
    if (startsAt && endsAt && startsAt >= endsAt) throw badInput("endsAt must be after startsAt.");
    const data = {
      code, discountType, discountValue: new Prisma.Decimal(discountValue), minOrderToman, maxDiscountToman,
      usageLimit, perCustomerLimit, firstOrderOnly: input.firstOrderOnly === true,
      startsAt, endsAt, isActive: input.isActive !== false,
    };
    try {
      const previous = idText === null ? null : await this.prisma.coupon.findUnique({ where: { id: parseId(idText, "coupon id") }, select: { isActive: true } });
      const coupon = idText === null
        ? await this.prisma.coupon.create({ data })
        : await this.prisma.coupon.update({ where: { id: parseId(idText, "coupon id") }, data });
      await this.audit(admin, idText ? "coupon.updated" : "coupon.created", "coupon", coupon.id, { code });
      if (coupon.isActive && (!previous || !previous.isActive)) {
        const value = discountType === "percent" ? `${discountValue}%` : `${discountValue.toLocaleString("fa-IR")} تومان`;
        await this.push.notifyMarketingCustomers("تخفیف تازه در پانیذ", `کد ${coupon.code} · ${value} تخفیف`, "/products");
      }
      return { data: toCoupon(coupon) };
    } catch (error) {
      if (isUniqueError(error)) throw new ConflictException({ code: "COUPON_CODE_EXISTS", message: "That coupon code already exists." });
      throw error;
    }
  }

  async previewSmsAudience(admin: AuthenticatedAdmin, rawFilters: unknown) {

    const filters = normalizeFilters(asObject(rawFilters));
    const audience = await this.loadCustomers(filters, "sms", true);
    return { data: { count: audience.total, capped: audience.capped, filters } };
  }

  async listSmsCampaigns(admin: AuthenticatedAdmin) {

    const campaigns = await this.prisma.smsCampaign.findMany({ where: { channel: "sms" }, orderBy: { createdAt: "desc" }, take: 50 });
    return { data: campaigns.map((item) => ({
      id: item.id.toString(), title: item.title, message: item.message, recipientCount: item.recipientCount,
      sentCount: item.sentCount, failedCount: item.failedCount, status: item.status,
      createdAt: item.createdAt.toISOString(), completedAt: item.completedAt?.toISOString() ?? null,
    })) };
  }

  async createSmsCampaign(admin: AuthenticatedAdmin, input: Record<string, unknown>) {
    requireAdminPermission(admin, "marketing.sms.send");
    const title = requiredText(input.title, "title", 160);
    const message = requiredText(input.message, "message", 1000);
    const filters = normalizeFilters(asObject(input.filters));
    const audience = await this.loadCustomers(filters, "sms", true);
    const campaign = await this.prisma.smsCampaign.create({ data: {
      channel: "sms", title, message, targetFilters: filters as Prisma.InputJsonValue,
      recipientCount: audience.total, status: "draft", createdByAdminId: admin.id,
    } });
    await this.audit(admin, "sms_campaign.created", "sms_campaign", campaign.id, { recipientCount: audience.total });
    return { data: { id: campaign.id.toString(), recipientCount: campaign.recipientCount, status: campaign.status } };
  }

  async sendSmsCampaign(admin: AuthenticatedAdmin, idText: string) {
    requireAdminPermission(admin, "marketing.sms.send");
    if (!this.smsCampaignWorkerEnabled()) {
      throw new ServiceUnavailableException({ code: "SMS_CAMPAIGNS_DISABLED", message: "ارسال کمپین پیامکی فعلاً غیرفعال است." });
    }
    const campaignId = parseId(idText, "campaign id");
    const campaign = await this.prisma.smsCampaign.findFirst({ where: { id: campaignId, channel: "sms" } });
    if (!campaign) throw new NotFoundException({ code: "SMS_CAMPAIGN_NOT_FOUND", message: "Campaign was not found." });
    if (campaign.status !== "draft") throw new ConflictException({ code: "SMS_CAMPAIGN_ALREADY_PROCESSED", message: "Only a draft can be sent. Check SMS.ir delivery records before creating a replacement campaign." });
    const apiKey = this.config.get<string>("SMSIR_API_KEY", "");
    const lineNumber = this.config.get<string>("SMSIR_LINE_NUMBER", "");
    if (!apiKey || !lineNumber) throw new ServiceUnavailableException({ code: "SMSIR_NOT_CONFIGURED", message: "Set SMSIR_API_KEY and SMSIR_LINE_NUMBER in the API environment before sending." });

    const filters = normalizeFilters(asObject(campaign.targetFilters));
    const audience = await this.loadCustomers(filters, "sms", true);
    if (!audience.customers.length) throw new ConflictException({ code: "SMS_AUDIENCE_EMPTY", message: "No customers with SMS marketing consent match these filters." });
    if (audience.capped) throw new ConflictException({ code: "SMS_AUDIENCE_TOO_LARGE", message: `This campaign exceeds the ${MAX_AUDIENCE.toLocaleString()} recipient limit. Narrow its filters.` });
    await this.prisma.smsCampaign.update({ where: { id: campaignId }, data: { status: "queued", recipientCount: audience.customers.length, sentCount: 0, failedCount: 0, providerResponse: Prisma.JsonNull } });
    setTimeout(() => void this.processQueuedSms(), 250).unref();
    return { data: { id: campaign.id.toString(), status: "queued", recipientCount: audience.customers.length } };
  }

  private async processQueuedSms(): Promise<void> {
    if (!this.smsCampaignWorkerEnabled() || this.smsBusy) return;
    this.smsBusy = true;
    try {
      for (let count = 0; count < 2; count++) {
        const campaign = await this.prisma.smsCampaign.findFirst({ where: { status: "queued", channel: "sms" }, orderBy: { createdAt: "asc" } });
        if (!campaign) break;
        const claim = await this.prisma.smsCampaign.updateMany({ where: { id: campaign.id, status: "queued" }, data: { status: "sending", startedAt: new Date() } });
        if (claim.count !== 1) continue;
        await this.dispatchSmsCampaign(campaign);
      }
    } catch (error) {
      this.logger.error(`SMS campaign worker failed: ${error instanceof Error ? error.message : "unknown error"}`);
    } finally { this.smsBusy = false; }
  }

  private smsCampaignWorkerEnabled(): boolean {
    return this.config.get<string>("NODE_ENV", "development") !== "production"
      || this.config.get<string>("SMS_CAMPAIGNS_ENABLED") === "true";
  }

  private async dispatchSmsCampaign(campaign: Prisma.SmsCampaignGetPayload<object>): Promise<void> {
    let sentCount = 0;
    let failedCount = 0;
    let recipientCount = campaign.recipientCount;
    const responses: Prisma.InputJsonObject[] = [];
    const endpoint = this.config.get<string>("SMSIR_BULK_URL", "https://api.sms.ir/v1/send/bulk");
    try {
        const filters = normalizeFilters(asObject(campaign.targetFilters));
        const audience = await this.loadCustomers(filters, "sms", true);
        recipientCount = audience.total;
        await this.prisma.smsCampaign.update({ where: { id: campaign.id }, data: { recipientCount } });
        if (audience.capped) throw new Error(`Campaign exceeds the ${MAX_AUDIENCE} recipient limit.`);
        if (!audience.customers.length) throw new Error("No customers with marketing consent match this audience.");
      for (let index = 0; index < audience.customers.length; index += 100) {
        const batch = audience.customers.slice(index, index + 100);
        const response = await fetch(endpoint, {
          method: "POST",
          headers: { "Content-Type": "application/json", "X-API-KEY": this.config.get<string>("SMSIR_API_KEY", "") },
          body: JSON.stringify({ lineNumber: Number(this.config.get<string>("SMSIR_LINE_NUMBER", "")), messageText: campaign.message, mobiles: batch.map((customer) => smsIrPhone(customer.phone)) }),
          signal: AbortSignal.timeout(25_000),
        });
        const responseBody = await response.json().catch(() => ({})) as Record<string, unknown>;
        if (!response.ok || smsIrRejected(responseBody)) {
          failedCount += batch.length;
          responses.push({ batchStart: index, httpStatus: response.status, result: safeProviderResult(responseBody) });
          throw new Error(`SMS.ir rejected batch ${index / 100 + 1} with HTTP ${response.status}.`);
        }
        sentCount += batch.length;
        responses.push({ batchStart: index, count: batch.length, result: safeProviderResult(responseBody) });
        await this.prisma.smsCampaign.update({ where: { id: campaign.id }, data: { sentCount, failedCount } });
      }
      await this.prisma.smsCampaign.update({ where: { id: campaign.id }, data: {
        status: "sent", recipientCount: audience.customers.length, sentCount, failedCount,
        completedAt: new Date(), providerResponse: responses as Prisma.InputJsonArray,
      } });
    } catch (error) {
      const message = error instanceof Error ? error.message : "SMS provider request failed.";
      await this.prisma.smsCampaign.update({ where: { id: campaign.id }, data: {
        status: sentCount ? "partial" : "failed", recipientCount, sentCount,
        failedCount: Math.max(failedCount, recipientCount - sentCount), completedAt: new Date(),
        providerResponse: { batches: responses, error: message } as Prisma.InputJsonObject,
      } });
      this.logger.error(`SMS campaign ${campaign.id} failed after ${sentCount} accepted recipients: ${message}`);
    }
  }

  async previewRubikaAudience(admin: AuthenticatedAdmin, rawFilters: unknown) {

    const filters = normalizeFilters(asObject(rawFilters));
    const audience = await this.loadCustomers(filters, "rubika", true);
    return { data: { count: audience.total, capped: audience.capped, filters } };
  }

  async listRubikaCampaigns(admin: AuthenticatedAdmin) {

    const campaigns = await this.prisma.smsCampaign.findMany({
      where: { channel: "rubika" }, orderBy: { createdAt: "desc" }, take: 50,
    });
    return { data: campaigns.map((item) => ({
      id: item.id.toString(), title: item.title, message: item.message, recipientCount: item.recipientCount,
      sentCount: item.sentCount, failedCount: item.failedCount, status: item.status,
      createdAt: item.createdAt.toISOString(), completedAt: item.completedAt?.toISOString() ?? null,
    })) };
  }

  async createRubikaCampaign(admin: AuthenticatedAdmin, input: Record<string, unknown>) {
    requireAdminPermission(admin, "marketing.rubika.publish");
    if (!(await this.rubika.integrationStatus()).configured) {
      throw new ServiceUnavailableException({ code: "RUBIKA_NOT_CONFIGURED", message: "توکن بات روبیکا در تنظیمات API ثبت نشده است." });
    }
    const title = requiredText(input.title, "title", 160);
    const message = requiredText(input.message, "message", 1000);
    const filters = normalizeFilters(asObject(input.filters));
    const audience = await this.loadCustomers(filters, "rubika", true);
    const campaign = await this.prisma.smsCampaign.create({ data: {
      channel: "rubika", title, message, targetFilters: filters as Prisma.InputJsonValue,
      recipientCount: audience.total, status: "draft", createdByAdminId: admin.id,
    } });
    await this.audit(admin, "rubika_campaign.created", "sms_campaign", campaign.id, { recipientCount: audience.total });
    return { data: { id: campaign.id.toString(), recipientCount: campaign.recipientCount, status: campaign.status } };
  }

  async sendRubikaCampaign(admin: AuthenticatedAdmin, idText: string) {
    requireAdminPermission(admin, "marketing.rubika.publish");
    if (!(await this.rubika.integrationStatus()).configured) {
      throw new ServiceUnavailableException({ code: "RUBIKA_NOT_CONFIGURED", message: "توکن بات روبیکا در تنظیمات API ثبت نشده است." });
    }
    const campaignId = parseId(idText, "campaign id");
    const campaign = await this.prisma.smsCampaign.findFirst({ where: { id: campaignId, channel: "rubika" } });
    if (!campaign) throw new NotFoundException({ code: "RUBIKA_CAMPAIGN_NOT_FOUND", message: "کمپین روبیکا پیدا نشد." });
    if (campaign.status !== "draft") throw new ConflictException({ code: "RUBIKA_CAMPAIGN_ALREADY_PROCESSED", message: "این کمپین قبلاً در صف ارسال قرار گرفته است." });
    const audience = await this.loadCustomers(normalizeFilters(asObject(campaign.targetFilters)), "rubika", true);
    if (!audience.customers.length) {
      throw new ConflictException({ code: "RUBIKA_AUDIENCE_EMPTY", message: "مشتریِ متصل و دارای رضایت روبیکا با این فیلتر پیدا نشد." });
    }
    if (audience.capped) {
      throw new ConflictException({ code: "RUBIKA_AUDIENCE_TOO_LARGE", message: "تعداد مخاطبان از سقف " + MAX_AUDIENCE.toLocaleString() + " بیشتر است؛ فیلترها را محدودتر کن." });
    }
    await this.prisma.smsCampaign.update({ where: { id: campaignId }, data: {
      status: "queued", recipientCount: audience.customers.length, sentCount: 0, failedCount: 0, providerResponse: Prisma.JsonNull,
    } });
    await this.audit(admin, "rubika_campaign.queued", "sms_campaign", campaignId, { recipientCount: audience.customers.length });
    setTimeout(() => void this.processQueuedRubika(), 250).unref();
    return { data: { id: campaign.id.toString(), status: "queued", recipientCount: audience.customers.length } };
  }

  private async processQueuedRubika(): Promise<void> {
    if (this.rubikaBusy) return;
    this.rubikaBusy = true;
    try {
      for (let count = 0; count < 2; count++) {
        const campaign = await this.prisma.smsCampaign.findFirst({
          where: { status: "queued", channel: "rubika" }, orderBy: { createdAt: "asc" },
        });
        if (!campaign) break;
        const claim = await this.prisma.smsCampaign.updateMany({
          where: { id: campaign.id, status: "queued", channel: "rubika" },
          data: { status: "sending", startedAt: new Date() },
        });
        if (claim.count !== 1) continue;
        await this.dispatchRubikaCampaign(campaign);
      }
    } catch (error) {
      this.logger.error("Rubika campaign worker failed: " + (error instanceof Error ? error.message : "unknown error"));
    } finally { this.rubikaBusy = false; }
  }

  private async dispatchRubikaCampaign(campaign: Prisma.SmsCampaignGetPayload<object>): Promise<void> {
    let sentCount = 0;
    let failedCount = 0;
    let suppressedCount = 0;
    let lastError: string | null = null;
    let recipientCount = campaign.recipientCount;
    try {
      const audience = await this.loadCustomers(normalizeFilters(asObject(campaign.targetFilters)), "rubika", true);
      if (audience.capped) throw new Error("Campaign exceeds the " + MAX_AUDIENCE + " recipient limit.");
      recipientCount = campaign.recipientCount;
      for (let index = 0; index < audience.customers.length; index += 25) {
        const batch = audience.customers.slice(index, index + 25);
        const current = await this.prisma.customer.findMany({
          where: {
            id: { in: batch.map((customer) => customer.id) },
            status: "active", rubikaMarketingOptIn: true, rubikaChatId: { not: null },
          },
          select: { id: true, rubikaChatId: true },
        });
        const currentById = new Map(current.map((customer) => [customer.id, customer.rubikaChatId]));
        suppressedCount += batch.length - current.length;
        for (const customer of batch) {
          const chatId = currentById.get(customer.id);
          if (!chatId) continue;
          try {
            await this.rubika.sendMessage(chatId, campaign.message);
            sentCount += 1;
          } catch (error) {
            failedCount += 1;
            lastError = error instanceof Error ? error.message.slice(0, 300) : "Rubika delivery failed.";
          }
          const delayMs = boundedInt(this.config.get<string>("RUBIKA_SEND_DELAY_MS", "150"), 150, 0, 5000);
          if (delayMs) await new Promise((resolve) => setTimeout(resolve, delayMs));
        }
        await this.prisma.smsCampaign.update({ where: { id: campaign.id }, data: { sentCount, failedCount } });
      }
      const status = failedCount === 0 ? "sent" : sentCount > 0 ? "partial" : "failed";
      await this.prisma.smsCampaign.update({ where: { id: campaign.id }, data: {
        status, recipientCount, sentCount, failedCount, completedAt: new Date(),
        providerResponse: {
          provider: "rubika", suppressedCount,
          ...(lastError ? { lastError } : {}),
        },
      } });
    } catch (error) {
      const message = error instanceof Error ? error.message : "Rubika provider request failed.";
      await this.prisma.smsCampaign.update({ where: { id: campaign.id }, data: {
        status: sentCount ? "partial" : "failed", recipientCount, sentCount,
        failedCount: Math.max(failedCount, recipientCount - sentCount - suppressedCount), completedAt: new Date(),
        providerResponse: { provider: "rubika", suppressedCount, error: message },
      } });
      this.logger.error("Rubika campaign " + campaign.id + " failed after " + sentCount + " accepted recipients: " + message);
    }
  }

  socialStatus(admin: AuthenticatedAdmin) {

    return { data: {
      rubika: { configured: Boolean(this.config.get("RUBIKA_BOT_TOKEN") && this.config.get("RUBIKA_CHANNEL_ID")) },
      instagram: { configured: Boolean(this.config.get("INSTAGRAM_USER_ID") && this.config.get("INSTAGRAM_ACCESS_TOKEN") && this.config.get("INSTAGRAM_GRAPH_API_VERSION")) },
    } };
  }

  async listSocialPosts(admin: AuthenticatedAdmin) {

    const posts = await this.prisma.socialPost.findMany({ orderBy: { createdAt: "desc" } });
    return { data: posts.map((post) => ({
      id: post.id.toString(), caption: post.caption, imageUrl: post.imageUrl,
      channels: post.channels, status: post.status, publishAt: post.publishAt.toISOString(),
      channelResults: post.channelResults, lastError: post.lastError,
      publishedAt: post.publishedAt?.toISOString() ?? null, createdAt: post.createdAt.toISOString(),
    })) };
  }

  async createSocialPost(admin: AuthenticatedAdmin, input: Record<string, unknown>) {
    requireAdminPermission(admin, "marketing.rubika.publish");
    const rawCaption = typeof input.caption === "string" ? input.caption.trim() : "";
    if (rawCaption.length > 2200) throw badInput("caption must be at most 2200 characters.");
    if (!Array.isArray(input.channels) || input.channels.length === 0 || input.channels.some((channel) => typeof channel !== "string" || !ALLOWED_CHANNELS.has(channel))) {
      throw badInput("Choose Rubika, Instagram, or both.");
    }
    const channels = [...new Set(input.channels as string[])];
    const productId = input.productId === null || input.productId === undefined || input.productId === ""
      ? null
      : parseId(String(input.productId), "productId");
    const productTitle = typeof input.productTitle === "string" ? input.productTitle.trim() : "";
    if (productTitle.length > 220) throw badInput("عنوان محصول باید حداکثر ۲۲۰ نویسه باشد.");
    const caption = productId
      ? await this.appendSocialProductDetails(rawCaption, productId, productTitle, channels.includes("rubika"))
      : rawCaption;
    if (!caption) throw badInput("متن تبلیغ بنویس یا برای انتشار روبیکا یک محصول انتخاب کن.");
    if (caption.length > 2200) throw badInput("کپشن نهایی با اطلاعات محصول نباید بیشتر از ۲۲۰۰ نویسه باشد.");
    const imageUrl = typeof input.imageUrl === "string" && input.imageUrl.trim() ? input.imageUrl.trim() : null;
    if (imageUrl && !/^https:\/\//i.test(imageUrl)) throw badInput("Social media needs a public HTTPS image URL.");
    if (channels.includes("instagram") && !imageUrl) throw badInput("Instagram posts require a public HTTPS image URL.");
    if (channels.includes("rubika") && imageUrl) await this.readRubikaImage(imageUrl);
    const publishAt = input.publishAt ? optionalDate(input.publishAt, "publishAt") : new Date();
    if (!publishAt) throw badInput("publishAt is invalid.");
    const post = await this.prisma.socialPost.create({ data: {
      caption, imageUrl, channels: channels as Prisma.InputJsonArray, publishAt,
      status: "queued", createdByAdminId: admin.id,
    } });
    await this.audit(admin, "social_post.queued", "social_post", post.id, { channels, publishAt: publishAt.toISOString() });
    if (publishAt <= new Date()) void this.publishDuePosts();
    return { data: { id: post.id.toString(), status: post.status, publishAt: post.publishAt.toISOString() } };
  }

  async publishProductToRubika(productId: string, createdByAdminId?: bigint): Promise<void> {
    if (this.rubikaProductBusy) {
      this.pendingRubikaProductIds.set(productId, createdByAdminId);
      return;
    }
    this.rubikaProductBusy = true;
    try {
      await this.publishProductToRubikaNow(productId, createdByAdminId);
    } finally {
      this.rubikaProductBusy = false;
      const next = this.pendingRubikaProductIds.entries().next().value as [string, bigint | undefined] | undefined;
      if (next) {
        this.pendingRubikaProductIds.delete(next[0]);
        setImmediate(() => void this.publishProductToRubika(next[0], next[1]).catch((error) => {
          this.logger.warn(`Queued Rubika product post failed: ${error instanceof Error ? error.message : "unknown error"}`);
        }));
      }
    }
  }

  private async publishOldestAvailableProduct(): Promise<void> {
    if (this.rubikaProductBusy) return;
    const candidates = await this.prisma.product.findMany({
      where: {
        status: "published", publishedAt: { lte: new Date() }, deletedAt: null,
        category: { is: { isActive: true } },
        variants: { some: { isActive: true } },
      },
      orderBy: [{ rubikaPostedAt: "asc" }, { createdAt: "asc" }],
      take: 250,
      select: {
        id: true,
        variants: { where: { isActive: true }, select: { stockQuantity: true, reservedQuantity: true } },
      },
    });
    const oldest = candidates.find((product) => product.variants.some((variant) => variant.stockQuantity > variant.reservedQuantity));
    if (!oldest) return;
    const owner = await this.prisma.adminUser.findFirst({
      where: { isActive: true, role: "owner" }, orderBy: { id: "asc" }, select: { id: true },
    }) ?? await this.prisma.adminUser.findFirst({
      where: { isActive: true }, orderBy: { id: "asc" }, select: { id: true },
    });
    if (!owner) {
      this.logger.warn("Rubika product post skipped because there is no active admin to own the post record.");
      return;
    }
    try {
      await this.publishProductToRubika(oldest.id.toString(), owner.id);
    } catch (error) {
      this.logger.warn(`Scheduled Rubika product post failed: ${error instanceof Error ? error.message : "unknown error"}`);
    }
  }

  private async publishProductToRubikaNow(productId: string, createdByAdminId?: bigint): Promise<void> {
    const id = parseId(productId, "productId");
    const product = await this.prisma.product.findFirst({
      where: {
        id, status: "published", publishedAt: { lte: new Date() }, deletedAt: null,
        category: { is: { isActive: true } },
      },
      include: {
        images: { orderBy: [{ isPrimary: "desc" }, { sortOrder: "asc" }], take: 1 },
        variants: {
          where: { isActive: true },
          orderBy: [{ colorSortOrder: "asc" }, { colorName: "asc" }, { sizeLabel: "asc" }],
          select: { sku: true, colorName: true, sizeLabel: true, stockQuantity: true, reservedQuantity: true },
        },
      },
    });
    if (!product || !product.variants.some((variant) => variant.stockQuantity > variant.reservedQuantity)) {
      throw new Error("محصول منتشرشده و دارای موجودی پیدا نشد.");
    }
    const chatId = this.config.get<string>("RUBIKA_CHANNEL_ID", "").trim();
    if (!chatId) throw new Error("شناسهٔ کانال روبیکا تنظیم نشده است.");
    const channelUrl = this.config.get<string>("RUBIKA_CHANNEL_URL", "").trim();
    if (!/^https:\/\/rubika\.ir\/[A-Za-z0-9_]+\/?$/i.test(channelUrl)) {
      throw new Error("لینک عمومی کانال باید در RUBIKA_CHANNEL_URL تنظیم شود.");
    }
    const siteUrl = this.publicWebBaseUrl();
    const purchaseUrl = new URL(`/products/${encodeURIComponent(product.slug)}`, siteUrl).toString();
    const availableVariants = product.variants.filter((variant) => variant.stockQuantity > variant.reservedQuantity);
    const colors = [...new Set(availableVariants.map((variant) => variant.colorName.trim()).filter(Boolean))];
    const sizes = [...new Set(availableVariants.map((variant) => variant.sizeLabel.trim()).filter(Boolean))];
    const date = new Intl.DateTimeFormat("fa-IR-u-ca-persian", {
      timeZone: "Asia/Tehran", year: "numeric", month: "long", day: "numeric",
    }).format(new Date());
    const caption = [
      `✨ ${product.name}`,
      `کد کالا: ${availableVariants[0]?.sku ?? "—"}`,
      `رنگ‌ها: ${colors.join("، ") || "—"}`,
      `سایزها: ${sizes.join("، ") || "—"}`,
      `مشاهده و خرید: ${purchaseUrl}`,
      "",
      "New ❤️",
      date,
      channelUrl,
    ].join("\n");
    const imageUrl = product.images[0]?.imagePath
      ? new URL(product.images[0].imagePath, siteUrl).toString()
      : null;
    const adminId = createdByAdminId ?? (await this.prisma.adminUser.findFirst({
      where: { isActive: true, role: "owner" }, orderBy: { id: "asc" }, select: { id: true },
    }))?.id;
    if (!adminId) throw new Error("مدیر فعالی برای ثبت سابقهٔ انتشار روبیکا وجود ندارد.");
    const post = await this.prisma.socialPost.create({
      data: {
        caption,
        imageUrl,
        channels: ["rubika"],
        status: "publishing",
        publishAt: new Date(),
        createdByAdminId: adminId,
      },
    });
    try {
      const result = await this.publishRubika(caption, imageUrl);
      await this.prisma.$transaction([
        this.prisma.product.update({ where: { id }, data: { rubikaPostedAt: new Date() } }),
        this.prisma.socialPost.update({ where: { id: post.id }, data: {
          status: "published", channelResults: { rubika: result } as Prisma.InputJsonObject, publishedAt: new Date(), lastError: null,
        } }),
      ]);
    } catch (error) {
      await this.prisma.socialPost.update({ where: { id: post.id }, data: {
        status: "failed", lastError: (error instanceof Error ? error.message : "Rubika post failed.").slice(0, 1000),
      } });
      throw error;
    }
  }

  async approveSocialPost(admin: AuthenticatedAdmin, rawId: string) {
    requireAdminPermission(admin, "marketing.rubika.publish");
    const id = parseId(rawId, "id");
    const post = await this.prisma.socialPost.findUnique({ where: { id }, select: { id: true, status: true, publishAt: true } });
    if (!post) throw new NotFoundException({ code: "SOCIAL_POST_NOT_FOUND", message: "پیام انتشار پیدا نشد." });
    if (post.status !== "awaiting_approval") throw new ConflictException({ code: "SOCIAL_POST_NOT_AWAITING_APPROVAL", message: "این پیام دیگر در انتظار تأیید نیست." });
    const updated = await this.prisma.socialPost.updateMany({ where: { id, status: "awaiting_approval" }, data: { status: "queued" } });
    if (updated.count !== 1) throw new ConflictException({ code: "SOCIAL_POST_ALREADY_PROCESSED", message: "وضعیت پیام هم‌زمان تغییر کرده است؛ فهرست را تازه‌سازی کن." });
    await this.audit(admin, "social_post.approved", "social_post", id, { publishAt: post.publishAt.toISOString() });
    if (post.publishAt <= new Date()) void this.publishDuePosts();
    return { data: { id: id.toString(), status: "queued", publishAt: post.publishAt.toISOString() } };
  }

  async sendSocialPostNow(admin: AuthenticatedAdmin, rawId: string) {
    requireAdminPermission(admin, "marketing.rubika.publish");
    const id = parseId(rawId, "id");
    const post = await this.prisma.socialPost.findUnique({ where: { id }, select: { id: true, status: true } });
    if (!post) throw new NotFoundException({ code: "SOCIAL_POST_NOT_FOUND", message: "پیام انتشار پیدا نشد." });
    if (post.status !== "queued") throw new ConflictException({ code: "SOCIAL_POST_NOT_QUEUED", message: "فقط پیام تأییدشدهٔ در صف را می‌توان فوری ارسال کرد." });
    const publishAt = new Date();
    const updated = await this.prisma.socialPost.updateMany({
      where: { id, status: "queued" }, data: { publishAt },
    });
    if (updated.count !== 1) throw new ConflictException({ code: "SOCIAL_POST_ALREADY_PROCESSED", message: "وضعیت پیام هم‌زمان تغییر کرده است؛ فهرست را تازه‌سازی کن." });
    await this.audit(admin, "social_post.send_now", "social_post", id, { publishAt: publishAt.toISOString() });
    void this.publishDuePosts();
    return { data: { id: id.toString(), status: "queued", publishAt: publishAt.toISOString() } };
  }

  async cancelSocialPost(admin: AuthenticatedAdmin, rawId: string) {
    requireAdminPermission(admin, "marketing.rubika.publish");
    const id = parseId(rawId, "id");
    const post = await this.prisma.socialPost.findUnique({ where: { id }, select: { id: true, status: true } });
    if (!post) throw new NotFoundException({ code: "SOCIAL_POST_NOT_FOUND", message: "پیام انتشار پیدا نشد." });
    if (post.status !== "awaiting_approval" && post.status !== "queued") {
      throw new ConflictException({ code: "SOCIAL_POST_CANNOT_BE_CANCELLED", message: "این پیام در حال ارسال است یا قبلاً پردازش شده و دیگر قابل لغو نیست." });
    }
    const updated = await this.prisma.socialPost.updateMany({
      where: { id, status: { in: ["awaiting_approval", "queued"] } }, data: { status: "cancelled" },
    });
    if (updated.count !== 1) throw new ConflictException({ code: "SOCIAL_POST_ALREADY_PROCESSED", message: "وضعیت پیام هم‌زمان تغییر کرده است؛ فهرست را تازه‌سازی کن." });
    await this.audit(admin, "social_post.cancelled", "social_post", id, { previousStatus: post.status });
    return { data: { id: id.toString(), status: "cancelled" } };
  }

  async operationsStatus(admin: AuthenticatedAdmin) {
    requireAdminPermission(admin, "system.monitor");
    let database = "offline";
    try { await this.prisma.$queryRaw`SELECT 1`; database = "online"; } catch { /* report without leaking connection details */ }
    const directory = this.backupDirectory();
    let backupVolume: { available: boolean; persistentConfigured: boolean; backupCount: number; latestAt: string | null; path: string } = {
      available: false, persistentConfigured: Boolean(this.config.get<string>("BACKUP_DIR")), backupCount: 0, latestAt: null, path: directory,
    };
    try {
      await mkdir(directory, { recursive: true });
      const probe = join(directory, `.paniz-write-check-${randomUUID()}`);
      await writeFile(probe, "ok", { flag: "wx" });
      await rm(probe, { force: true });
      const files = await this.listBackupFiles();
      backupVolume = { available: true, persistentConfigured: Boolean(this.config.get<string>("BACKUP_DIR")), backupCount: files.length, latestAt: files[0]?.createdAt ?? null, path: directory };
    } catch { /* an unavailable persistent backup volume is reported below */ }
    const rubikaStatus = await this.rubika.integrationStatus();
    return { data: {
      api: "online", database, backupVolume,
      backupTool: process.platform === "win32" ? "external mysqldump required" : "mysqldump",
      integrations: {
        smsIr: Boolean(this.config.get("SMSIR_API_KEY") && this.config.get("SMSIR_LINE_NUMBER")),
        rubika: Boolean(this.config.get("RUBIKA_BOT_TOKEN") && this.config.get("RUBIKA_CHANNEL_ID") && this.config.get("RUBIKA_CHANNEL_URL")),
        rubikaBotMessaging: rubikaStatus.configured,
        rubikaWebhook: rubikaStatus.webhookConfigured,
        instagram: Boolean(this.config.get("INSTAGRAM_USER_ID") && this.config.get("INSTAGRAM_ACCESS_TOKEN") && this.config.get("INSTAGRAM_GRAPH_API_VERSION")),
      },
    } };
  }

  async listBackups(admin: AuthenticatedAdmin) {
    requireAdminPermission(admin, "system.backup");
    return { data: await this.listBackupFiles() };
  }

  async createBackup(admin: AuthenticatedAdmin) {
    requireAdminPermission(admin, "system.backup");
    const file = await this.writeBackup();
    await this.removeOldBackups();
    await this.audit(admin, "database.backup_created", "database_backup", null, { filename: file.filename, sizeBytes: file.sizeBytes });
    return { data: file };
  }

  private async loadCustomers(filters: AudienceFilters, channel: "all" | "sms" | "rubika", consentOnly: boolean) {
    const now = new Date();
    const cutoff = new Date(now.getTime() - 365 * 24 * 60 * 60 * 1000);
    const where: Prisma.CustomerWhereInput = {
      status: "active",
      ...(consentOnly && channel === "sms" ? { marketingOptIn: true } : {}),
      ...(channel === "rubika" ? { rubikaMarketingOptIn: true, rubikaChatId: { not: null } } : {}),
      ...(filters.q ? { OR: [
        { fullName: { contains: filters.q } }, { phone: { contains: filters.q } }, { email: { contains: filters.q } },
      ] } : {}),
      ...(filters.city ? { addresses: { some: { city: { contains: filters.city } } } } : {}),
      ...(filters.registration === "under_year" ? { createdAt: { gte: cutoff } } : {}),
      ...(filters.registration === "over_year" ? { createdAt: { lt: cutoff } } : {}),
      ...(filters.productId ? { orders: { some: {
        paymentStatus: "paid", items: { some: { productId: parseId(filters.productId, "productId") } },
      } } } : {}),
    };
    const [total, customers] = await Promise.all([
      this.prisma.customer.count({ where }),
      this.prisma.customer.findMany({
        where, orderBy: { createdAt: filters.registration === "over_year" ? "asc" : "desc" }, take: MAX_AUDIENCE,
        select: {
          id: true, phone: true, fullName: true, email: true, marketingOptIn: true,
          rubikaMarketingOptIn: true, rubikaChatId: true,
          createdAt: true, addresses: { orderBy: { updatedAt: "desc" }, take: 1, select: { city: true, province: true } },
          orders: { where: { paymentStatus: "paid" }, orderBy: { placedAt: "desc" }, take: 1, select: { placedAt: true, orderNumber: true } },
        },
      }),
    ]);
    if (filters.purchaseSort !== "none") {
      customers.sort((left, right) => {
        const leftAt = left.orders[0]?.placedAt.getTime() ?? 0;
        const rightAt = right.orders[0]?.placedAt.getTime() ?? 0;
        return filters.purchaseSort === "recent" ? rightAt - leftAt : leftAt - rightAt;
      });
    }
    return { customers, total, capped: total > customers.length };
  }

  private async publishDuePosts(): Promise<void> {
    if (this.socialBusy) {
      this.socialRunRequested = true;
      return;
    }
    this.socialBusy = true;
    try {
      for (let index = 0; index < 5; index++) {
        const post = await this.prisma.socialPost.findFirst({
          where: { status: "queued", publishAt: { lte: new Date() } }, orderBy: { publishAt: "asc" },
        });
        if (!post) break;
        const claim = await this.prisma.socialPost.updateMany({ where: { id: post.id, status: "queued" }, data: { status: "publishing" } });
        if (claim.count !== 1) continue;
        const startedAt = Date.now();
        const channels = Array.isArray(post.channels) ? post.channels.filter((item): item is string => typeof item === "string") : [];
        const results: Record<string, unknown> = {};
        for (const channel of channels) {
          try {
            results[channel] = channel === "instagram" ? await this.publishInstagram(post.caption, post.imageUrl) : await this.publishRubika(post.caption, post.imageUrl);
          } catch (error) {
            results[channel] = { ok: false, error: error instanceof Error ? error.message : "Publish failed." };
          }
        }
        const failures = Object.entries(results).filter(([, value]) => (value as { ok?: boolean }).ok !== true);
        const state = failures.length === 0 ? "published" : failures.length === channels.length ? "failed" : "partial";
        await this.prisma.socialPost.update({ where: { id: post.id }, data: {
          status: state, channelResults: results as Prisma.InputJsonObject,
          lastError: failures.length ? failures.map(([channel, result]) => `${channel}: ${(result as { error?: string }).error ?? "failed"}`).join("; ").slice(0, 1000) : null,
          publishedAt: state === "published" ? new Date() : null,
        } });
        this.logger.log(`Social post ${post.id} finished with status ${state} in ${Date.now() - startedAt}ms.`);
      }
    } catch (error) {
      this.logger.error(`Social publishing worker failed: ${error instanceof Error ? error.message : "unknown error"}`);
    } finally {
      this.socialBusy = false;
      if (this.socialRunRequested) {
        this.socialRunRequested = false;
        setImmediate(() => void this.publishDuePosts());
      }
    }
  }

  private async publishRubika(caption: string, imageUrl: string | null) {
    const chatId = this.config.get<string>("RUBIKA_CHANNEL_ID", "");
    if (!chatId) throw new Error("Rubika bot token/channel ID is not configured.");
    if (imageUrl) {
      const image = await this.readRubikaImage(imageUrl);
      const result = await this.rubika.sendImage(chatId, image.bytes, image.fileName, caption);
      return { ok: true, media: "image", provider: safeProviderResult(result) };
    }
    const result = await this.rubika.sendMessage(chatId, caption);
    return { ok: true, media: "text", provider: safeProviderResult(result) };
  }

  private async appendSocialProductDetails(caption: string, productId: bigint, titleOverride: string, includeRubikaFooter = false) {
    const product = await this.prisma.product.findFirst({
      where: {
        id: productId,
        status: "published",
        publishedAt: { lte: new Date() },
        deletedAt: null,
        category: { is: { isActive: true } },
        variants: { some: { isActive: true } },
      },
      select: socialProductSelect,
    });
    if (!product) throw new NotFoundException({ code: "SOCIAL_PRODUCT_NOT_AVAILABLE", message: "محصول انتخاب‌شده منتشرشده یا قابل خرید نیست." });

    const details = this.toSocialProduct(product, this.publicWebBaseUrl());
    const title = titleOverride || details.title;
    const productLines = [
      `نام محصول: ${details.name}`,
      `عنوان محصول: ${title}`,
      `کد محصول: ${details.productCode ?? "—"}`,
      `تنوع رنگی محصول: ${details.colors.length ? details.colors.join("، ") : "—"}`,
      `تنوع سایزی محصول: ${details.sizes.length ? details.sizes.join("، ") : "—"}`,
      `لینک خرید محصول: ${details.purchaseUrl}`,
    ];
    if (includeRubikaFooter) {
      const channelUrl = this.config.get<string>("RUBIKA_CHANNEL_URL", "").trim();
      if (!/^https:\/\/rubika\.ir\/[A-Za-z0-9_]+\/?$/i.test(channelUrl)) {
        throw new ServiceUnavailableException({ code: "RUBIKA_CHANNEL_URL_MISSING", message: "لینک عمومی کانال روبیکا در تنظیمات سرور ثبت نشده است." });
      }
      const date = new Intl.DateTimeFormat("fa-IR-u-ca-persian", {
        timeZone: "Asia/Tehran", year: "numeric", month: "long", day: "numeric",
      }).format(new Date());
      productLines.push("", "New ❤️", date, channelUrl);
    }
    return [caption, ...(caption ? [""] : []), ...productLines].join("\n");
  }

  private toSocialProduct(product: SocialProduct, siteBaseUrl: URL) {
    const colors = [...new Set(product.variants.map((variant) => variant.colorName.trim()).filter(Boolean))];
    const sizes = [...new Set(product.variants.map((variant) => variant.sizeLabel.trim()).filter(Boolean))];
    return {
      id: product.id.toString(),
      name: product.name,
      title: product.seoTitle?.trim() || product.shortDescription?.trim() || product.name,
      productCode: product.variants[0]?.sku ?? null,
      colors,
      sizes,
      purchaseUrl: new URL(`/products/${encodeURIComponent(product.slug)}`, siteBaseUrl).toString(),
    };
  }

  private publicWebBaseUrl(): URL {
    const configured = this.config.get<string>("PUBLIC_WEB_URL", "https://panizstyle.ir").trim();
    try {
      const url = new URL(configured);
      if (url.protocol !== "https:") throw new Error("HTTPS is required");
      return url;
    } catch {
      throw new ServiceUnavailableException({ code: "PUBLIC_WEB_URL_INVALID", message: "نشانی HTTPS سایت برای لینک خرید محصول تنظیم نشده است." });
    }
  }

  private async readRubikaImage(imageUrl: string): Promise<{ bytes: Buffer; fileName: string }> {
    let pathname: string;
    try {
      pathname = new URL(imageUrl).pathname;
      pathname = decodeURIComponent(pathname);
    } catch {
      throw badInput("برای روبیکا، تصویر باید با انتخاب‌گر تصویر اپ ادمین روی سرور بارگذاری شده باشد.");
    }

    const match = /^\/uploads\/products\/([A-Za-z0-9][A-Za-z0-9._-]*\.(?:jpe?g|png|webp))$/i.exec(pathname);
    if (!match) {
      throw badInput("برای روبیکا، تصویر باید با انتخاب‌گر تصویر اپ ادمین روی سرور بارگذاری شده باشد.");
    }

    const root = resolve(uploadRoot(), "products");
    const fileName = basename(match[1]);
    const filePath = resolve(root, fileName);
    if (!filePath.startsWith(root + sep)) throw badInput("مسیر تصویر روبیکا معتبر نیست.");

    try {
      const details = await stat(filePath);
      if (!details.isFile() || details.size <= 0 || details.size > 8 * 1024 * 1024) {
        throw badInput("حجم تصویر روبیکا باید کمتر از ۸ مگابایت باشد.");
      }
      return { bytes: await readFile(filePath), fileName };
    } catch (error) {
      if (error instanceof BadRequestException) throw error;
      throw badInput("فایل تصویر روی سرور پیدا نشد؛ تصویر را دوباره از اپ ادمین بارگذاری کن.");
    }
  }

  private async publishInstagram(caption: string, imageUrl: string | null) {
    const userId = this.config.get<string>("INSTAGRAM_USER_ID", "");
    const token = this.config.get<string>("INSTAGRAM_ACCESS_TOKEN", "");
    if (!userId || !token || !imageUrl) throw new Error("Instagram professional account, access token, and public image URL are required.");
    const version = this.config.get<string>("INSTAGRAM_GRAPH_API_VERSION", "");
    if (!/^v\d+\.\d+$/.test(version)) throw new Error("Set INSTAGRAM_GRAPH_API_VERSION to the Graph API version enabled for your Meta app.");
    const base = `https://graph.facebook.com/${version}/${encodeURIComponent(userId)}`;
    const createBody = new URLSearchParams({ image_url: imageUrl, caption, access_token: token });
    const creationResponse = await fetch(`${base}/media`, { method: "POST", body: createBody, signal: AbortSignal.timeout(25_000) });
    const creation = await creationResponse.json().catch(() => ({})) as Record<string, unknown>;
    if (!creationResponse.ok || typeof creation.id !== "string") throw new Error(`Instagram media container creation failed (HTTP ${creationResponse.status}).`);
    const publishBody = new URLSearchParams({ creation_id: creation.id, access_token: token });
    const publishResponse = await fetch(`${base}/media_publish`, { method: "POST", body: publishBody, signal: AbortSignal.timeout(25_000) });
    const published = await publishResponse.json().catch(() => ({})) as Record<string, unknown>;
    if (!publishResponse.ok || typeof published.id !== "string") throw new Error(`Instagram publish failed (HTTP ${publishResponse.status}).`);
    return { ok: true, mediaId: published.id };
  }

  private async ensureDailyBackup(): Promise<void> {
    if (this.backupBusy || this.config.get<string>("BACKUP_SCHEDULE_ENABLED", "true") === "false") return;
    this.backupBusy = true;
    try {
      const files = await this.listBackupFiles();
      const latest = files[0] ? new Date(files[0].createdAt).getTime() : 0;
      if (Date.now() - latest > 24 * 60 * 60_000) {
        await this.writeBackup();
        await this.removeOldBackups();
      }
    } catch (error) {
      this.logger.warn(`Scheduled database backup skipped: ${error instanceof Error ? error.message : "unknown error"}`);
    } finally { this.backupBusy = false; }
  }

  private async recoverInterruptedJobs(): Promise<void> {
    const smsCutoff = new Date(Date.now() - 3 * 60_000);
    const postCutoff = new Date(Date.now() - 5 * 60_000);
    const [sms, posts] = await Promise.all([
        this.prisma.smsCampaign.findMany({ where: { status: "sending", updatedAt: { lt: smsCutoff } }, select: { id: true, channel: true, recipientCount: true, sentCount: true } }),
      this.prisma.socialPost.findMany({ where: { status: "publishing", updatedAt: { lt: postCutoff } }, select: { id: true } }),
    ]);
    let recoveredSms = 0;
    let recoveredPosts = 0;
    for (const campaign of sms) {
      const result = await this.prisma.smsCampaign.updateMany({
        where: { id: campaign.id, status: "sending", updatedAt: { lt: smsCutoff } },
        data: {
          status: campaign.sentCount ? "partial" : "failed", failedCount: campaign.recipientCount - campaign.sentCount,
          completedAt: new Date(),
          providerResponse: {
            error: campaign.channel === "rubika"
              ? "The API restarted during delivery. Check the bot delivery before creating another campaign."
              : "The API restarted during delivery. Check SMS.ir before creating another campaign.",
            manualReviewRequired: true,
          },
        },
      });
      recoveredSms += result.count;
    }
    for (const post of posts) {
      const result = await this.prisma.socialPost.updateMany({
        where: { id: post.id, status: "publishing", updatedAt: { lt: postCutoff } },
        data: {
          status: "failed", lastError: "The API restarted during publishing. Check the channel before creating another post.",
          channelResults: { manualReviewRequired: true, error: "Publishing was interrupted; provider delivery may have occurred." },
        },
      });
      recoveredPosts += result.count;
    }
    if (recoveredSms || recoveredPosts) {
      this.logger.warn(`Marked interrupted work for review: ${recoveredSms} SMS campaigns, ${recoveredPosts} social posts.`);
    }
  }

  private async writeBackup() {
    const databaseUrl = this.config.get<string>("DATABASE_URL", "");
    if (!databaseUrl) throw new ServiceUnavailableException({ code: "DATABASE_URL_MISSING", message: "DATABASE_URL is not configured." });
    const parsed = new URL(databaseUrl);
    const directory = this.backupDirectory();
    await mkdir(directory, { recursive: true });
    const filename = `paniz-mysql-${new Date().toISOString().replace(/[:.]/g, "-")}.sql`;
    const outputPath = join(directory, filename);
    const args = [
      "--single-transaction", "--quick", "--skip-lock-tables", "--host", parsed.hostname,
      "--port", parsed.port || "3306", "--user", decodeURIComponent(parsed.username),
      "--default-character-set=utf8mb4", "--result-file", outputPath,
      decodeURIComponent(parsed.pathname.replace(/^\//, "")),
    ];
    try {
      await execFile(this.config.get<string>("MYSQLDUMP_PATH", "mysqldump"), args, {
        timeout: 10 * 60_000, maxBuffer: 4 * 1024 * 1024,
        env: { ...process.env, MYSQL_PWD: decodeURIComponent(parsed.password) },
      });
    } catch (error) {
      await rm(outputPath, { force: true }).catch(() => undefined);
      throw new ServiceUnavailableException({ code: "BACKUP_FAILED", message: "mysqldump failed. Mount persistent storage at /data and install/configure the MySQL client in the API image." });
    }
    const metadata = await stat(outputPath);
    return { filename, createdAt: metadata.mtime.toISOString(), sizeBytes: metadata.size, path: outputPath };
  }

  private async listBackupFiles() {
    const directory = this.backupDirectory();
    const names = await readdir(directory).catch(() => [] as string[]);
    const files = await Promise.all(names.filter((name) => /^paniz-mysql-[\w-]+\.sql$/.test(name)).map(async (filename) => {
      const metadata = await stat(join(directory, filename));
      return { filename, createdAt: metadata.mtime.toISOString(), sizeBytes: metadata.size };
    }));
    return files.sort((left, right) => right.createdAt.localeCompare(left.createdAt));
  }

  private async removeOldBackups(): Promise<void> {
    const keep = boundedInt(this.config.get<string>("BACKUP_RETENTION_COUNT", "7"), 7, 1, 100);
    const files = await this.listBackupFiles();
    await Promise.all(files.slice(keep).map((file) => rm(join(this.backupDirectory(), file.filename), { force: true })));
  }

  private backupDirectory(): string {
    return this.config.get<string>("BACKUP_DIR", join(process.cwd(), "backups"));
  }

  private async audit(admin: AuthenticatedAdmin, action: string, entityType: string, entityId: bigint | null, details: Prisma.InputJsonObject) {
    await this.prisma.adminAuditLog.create({ data: { adminId: admin.id, action, entityType, entityId, details } });
  }
}

function requireManager(admin: AuthenticatedAdmin): void {
  if (admin.role !== "owner" && admin.role !== "admin") throw new ForbiddenException({ code: "ADMIN_PERMISSION_REQUIRED", message: "Manager access is required." });
}

function normalizeFilters(raw: Record<string, unknown>): AudienceFilters {
  const registration = raw.registration === "under_year" || raw.registration === "over_year" ? raw.registration : "any";
  const purchaseSort = raw.purchaseSort === "recent" || raw.purchaseSort === "oldest" ? raw.purchaseSort : "none";
  const filters: AudienceFilters = {
    q: typeof raw.q === "string" ? raw.q.trim().slice(0, 120) || undefined : undefined,
    city: typeof raw.city === "string" ? raw.city.trim().slice(0, 100) || undefined : undefined,
    registration, purchaseSort,
    productId: typeof raw.productId === "string" && raw.productId.trim() ? raw.productId.trim() : undefined,
  };
  if (filters.productId) parseId(filters.productId, "productId");
  return filters;
}

function toCustomerSummary(customer: {
  id: bigint; phone: string; fullName: string | null; email: string | null; marketingOptIn: boolean;
  rubikaMarketingOptIn: boolean; rubikaChatId: string | null; createdAt: Date;
  addresses: { city: string; province: string }[]; orders: { placedAt: Date; orderNumber: string }[];
}) {
  return {
    id: customer.id.toString(), phone: customer.phone, fullName: customer.fullName, email: customer.email,
    marketingOptIn: customer.marketingOptIn, rubikaMarketingOptIn: customer.rubikaMarketingOptIn,
    rubikaLinked: Boolean(customer.rubikaChatId), createdAt: customer.createdAt.toISOString(),
    city: customer.addresses[0]?.city ?? null, province: customer.addresses[0]?.province ?? null,
    lastPurchaseAt: customer.orders[0]?.placedAt.toISOString() ?? null,
    lastOrderNumber: customer.orders[0]?.orderNumber ?? null,
  };
}

function toCoupon(coupon: {
  id: bigint; code: string; discountType: string; discountValue: Prisma.Decimal; maxDiscountToman: bigint | null;
  minOrderToman: bigint; usageLimit: number | null; perCustomerLimit: number | null; firstOrderOnly: boolean;
  startsAt: Date | null; endsAt: Date | null; isActive: boolean; createdAt: Date;
}) {
  return {
    id: coupon.id.toString(), code: coupon.code, discountType: coupon.discountType,
    discountValue: Number(coupon.discountValue), maxDiscountToman: coupon.maxDiscountToman?.toString() ?? null,
    minOrderToman: coupon.minOrderToman.toString(), usageLimit: coupon.usageLimit,
    perCustomerLimit: coupon.perCustomerLimit, firstOrderOnly: coupon.firstOrderOnly,
    startsAt: coupon.startsAt?.toISOString() ?? null, endsAt: coupon.endsAt?.toISOString() ?? null,
    isActive: coupon.isActive, createdAt: coupon.createdAt.toISOString(),
  };
}

function asObject(value: unknown): Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value) ? value as Record<string, unknown> : {};
}

function requiredText(value: unknown, name: string, maxLength: number): string {
  if (typeof value !== "string" || !value.trim() || value.trim().length > maxLength) throw badInput(`${name} is required and must be at most ${maxLength} characters.`);
  return value.trim();
}

function integerBigInt(value: unknown, name: string): bigint {
  const text = String(value);
  if (!/^\d{1,15}$/.test(text)) throw badInput(`${name} must be a non-negative whole number.`);
  return BigInt(text);
}

function optionalPositiveInt(value: unknown, name: string): number | null {
  if (value === null || value === undefined || value === "") return null;
  const number = Number(value);
  if (!Number.isInteger(number) || number < 1 || number > 1_000_000) throw badInput(`${name} must be between 1 and 1000000.`);
  return number;
}

function optionalDate(value: unknown, name: string): Date | null {
  if (value === null || value === undefined || value === "") return null;
  if (typeof value !== "string") throw badInput(`${name} must be an ISO date string.`);
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) throw badInput(`${name} is invalid.`);
  return parsed;
}

function boundedInt(value: unknown, fallback: number, minimum: number, maximum: number): number {
  const parsed = Number(value);
  return Number.isInteger(parsed) ? Math.min(maximum, Math.max(minimum, parsed)) : fallback;
}

function parseId(value: string, name: string): bigint {
  if (!/^\d{1,20}$/.test(value) || BigInt(value) < 1n) throw badInput(`${name} is invalid.`);
  return BigInt(value);
}

function badInput(message: string): BadRequestException {
  return new BadRequestException({ code: "INVALID_ADMIN_INPUT", message });
}

function isUniqueError(error: unknown): boolean {
  return error instanceof Prisma.PrismaClientKnownRequestError && error.code === "P2002";
}

function safeProviderResult(result: Record<string, unknown>): Prisma.InputJsonObject {
  const safe = { ...result };
  delete safe.access_token;
  delete safe.token;
  delete safe.apiKey;
  const text = JSON.stringify(safe);
  return text.length > 1800 ? { responseOmitted: true, reason: "provider response was too large" } : JSON.parse(text) as Prisma.InputJsonObject;
}

function smsIrPhone(phone: string): string {
  if (phone.startsWith("+98")) return `0${phone.slice(3)}`;
  if (phone.startsWith("98")) return `0${phone.slice(2)}`;
  return phone;
}

function smsIrRejected(result: Record<string, unknown>): boolean {
  const status = result.status ?? result.Status;
  return result.IsSuccessful === false || result.isSuccessful === false || status === 0 || status === "0" || status === "ERROR" || status === "error";
}
