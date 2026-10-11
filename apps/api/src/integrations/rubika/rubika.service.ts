import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
  OnModuleInit,
  ServiceUnavailableException,
} from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { Prisma } from "@prisma/client";
import { createHash, createHmac, randomBytes, timingSafeEqual } from "node:crypto";
import { PrismaService } from "../../database/prisma.service";

const LINK_CODE_TTL_MS = 10 * 60_000;
const BOT_API_BASE_URL = "https://botapi.rubika.ir/v3";

@Injectable()
export class RubikaBotService implements OnModuleInit {
  private readonly logger = new Logger(RubikaBotService.name);

  constructor(private readonly prisma: PrismaService, private readonly config: ConfigService) {}

  async onModuleInit(): Promise<void> {
    const token = this.token();
    const webhookBase = this.webhookBaseUrl();
    if (!token || !webhookBase) return;

    try {
      const url = new URL("/api/v1/integrations/rubika/webhook/" + this.webhookSecret(token), webhookBase).toString();
      await this.call(token, "updateBotEndpoints", { url, type: "ReceiveUpdate" });
      this.logger.log("Rubika update webhook is configured.");
    } catch (error) {
      this.logger.warn("Rubika webhook registration failed: " + (error instanceof Error ? error.message : "unknown error"));
    }
  }

  async integrationStatus() {
    return {
      configured: Boolean(this.token()),
      webhookConfigured: Boolean(this.token() && this.webhookBaseUrl()),
    };
  }

  async createLinkCode(customerId: bigint) {
    const token = this.requireToken();
    const customer = await this.prisma.customer.findUnique({
      where: { id: customerId },
      select: { status: true, rubikaMarketingOptIn: true },
    });
    if (!customer || customer.status !== "active") {
      throw new NotFoundException({ code: "CUSTOMER_NOT_FOUND", message: "حساب مشتری پیدا نشد." });
    }
    if (!customer.rubikaMarketingOptIn) {
      throw new BadRequestException({ code: "RUBIKA_CONSENT_REQUIRED", message: "برای اتصال روبیکا، ابتدا رضایت دریافت پیام‌های روبیکا را ذخیره کن." });
    }

    const code = "PZ-" + randomBytes(8).toString("hex").toUpperCase();
    const tokenHash = hashLinkCode(code);
    const expiresAt = new Date(Date.now() + LINK_CODE_TTL_MS);
    await this.prisma.$transaction([
      this.prisma.customerRubikaLinkCode.updateMany({
        where: { customerId, usedAt: null }, data: { expiresAt: new Date() },
      }),
      this.prisma.customerRubikaLinkCode.create({ data: { customerId, tokenHash, expiresAt } }),
    ]);

    let botUrl: string | null = null;
    let botUsername: string | null = null;
    try {
      const botInfo = await this.getBotInfo(token);
      botUrl = stringOrNull(botInfo.share_url);
      botUsername = stringOrNull(botInfo.username);
    } catch (error) {
      this.logger.warn("Could not load Rubika bot details: " + (error instanceof Error ? error.message : "unknown error"));
    }

    return { code, expiresAt: expiresAt.toISOString(), botUrl, botUsername };
  }

  async sendMessage(chatId: string, text: string) {
    return this.call(this.requireToken(), "sendMessage", { chat_id: chatId, text });
  }

  async handleWebhook(secret: string, rawBody: unknown) {
    const token = this.token();
    if (!token || !safeSecretEquals(secret, this.webhookSecret(token))) throw new NotFoundException();

    const body = asRecord(rawBody);
    const update = asRecord(body.update);
    const type = typeof update.type === "string" ? update.type : "";
    const chatId = stringOrNull(update.chat_id);
    if (!chatId) return { ok: true };

    if (type === "StoppedBot") {
      await this.prisma.customer.updateMany({
        where: { rubikaChatId: chatId }, data: { rubikaMarketingOptIn: false, rubikaMarketingOptInAt: null },
      });
      return { ok: true };
    }

    if (type === "StartedBot") {
      await this.sendMessage(chatId, "سلام! برای اتصال حساب فروشگاه PanizStyle، کد یک‌بارمصرف صفحهٔ حساب کاربری‌ات را همین‌جا بفرست. برای لغو پیام‌های تبلیغاتی هم /stop را بفرست.");
      return { ok: true };
    }

    if (type !== "NewMessage") return { ok: true };
    const message = asRecord(update.new_message);
    if (message.sender_type !== "User") return { ok: true };
    const text = stringOrNull(message.text)?.trim() ?? "";
    if (!text) return { ok: true };

    const chat = await this.getChat(token, chatId).catch(() => null);
    if (chat?.chat_type !== "User") return { ok: true };

    if (/^\/?stop$/i.test(text)) {
      const result = await this.prisma.customer.updateMany({
        where: { rubikaChatId: chatId }, data: { rubikaMarketingOptIn: false, rubikaMarketingOptInAt: null },
      });
      await this.sendMessage(chatId, result.count ? "دریافت پیام‌های تبلیغاتی روبیکا برای این حساب غیرفعال شد." : "این حساب به پیام‌های روبیکا متصل نیست.");
      return { ok: true };
    }

    if (/^\/?start$/i.test(text)) {
      await this.sendMessage(chatId, "برای اتصال حساب، کد یک‌بارمصرف صفحهٔ حساب کاربری PanizStyle را بفرست. برای لغو پیام‌های تبلیغاتی /stop را بفرست.");
      return { ok: true };
    }

    const code = extractLinkCode(text);
    if (!code) return { ok: true };
    const tokenHash = hashLinkCode(code);
    const now = new Date();
    try {
      const connected = await this.prisma.$transaction(async (tx) => {
        const link = await tx.customerRubikaLinkCode.findUnique({ where: { tokenHash } });
        if (!link || link.usedAt || link.expiresAt <= now) return false;
        const claimed = await tx.customerRubikaLinkCode.updateMany({
          where: { id: link.id, usedAt: null, expiresAt: { gt: now } }, data: { usedAt: now },
        });
        if (claimed.count !== 1) return false;
        const customer = await tx.customer.updateMany({
          where: { id: link.customerId, status: "active", rubikaMarketingOptIn: true },
          data: { rubikaChatId: chatId, rubikaMarketingOptInAt: now },
        });
        if (customer.count !== 1) throw new Error("Customer consent is no longer active.");
        return true;
      });
      await this.sendMessage(chatId, connected
        ? "حساب PanizStyle با موفقیت متصل شد. برای لغو پیام‌های تبلیغاتی هر زمان /stop را بفرست."
        : "کد معتبر نیست یا منقضی شده است. از حساب PanizStyle کد تازه بگیر.");
    } catch (error) {
      if (isUniqueError(error)) {
        await this.sendMessage(chatId, "این حساب فروشگاه به گفت‌وگوی روبیکای دیگری متصل است. ابتدا اتصال قبلی را از حساب کاربری قطع کن.");
      } else {
        this.logger.warn("Rubika account linking failed: " + (error instanceof Error ? error.message : "unknown error"));
        await this.sendMessage(chatId, "اتصال حساب انجام نشد. دوباره کد تازه بگیر و تلاش کن.");
      }
    }
    return { ok: true };
  }

  private async getBotInfo(token: string): Promise<Record<string, unknown>> {
    const result = await this.call(token, "getMe");
    const data = asRecord(result.data);
    return asRecord(result.bot ?? data.bot ?? result);
  }

  private async getChat(token: string, chatId: string): Promise<Record<string, unknown>> {
    const result = await this.call(token, "getChat", { chat_id: chatId });
    const data = asRecord(result.data);
    return asRecord(result.chat ?? data.chat ?? result);
  }

  private async call(token: string, method: string, body?: Record<string, unknown>): Promise<Record<string, unknown>> {
    const base = this.config.get<string>("RUBIKA_BOT_API_BASE_URL", BOT_API_BASE_URL).replace(/\/+$/, "");
    let apiBase: URL;
    try { apiBase = new URL(base); }
    catch { throw new ServiceUnavailableException({ code: "RUBIKA_API_URL_INVALID", message: "Rubika API base URL is invalid." }); }
    if (apiBase.protocol !== "https:") {
      throw new ServiceUnavailableException({ code: "RUBIKA_API_HTTPS_REQUIRED", message: "Rubika API must be called over HTTPS." });
    }
    const response = await fetch(apiBase.toString().replace(/\/+$/, "") + "/" + encodeURIComponent(token) + "/" + method, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      ...(body ? { body: JSON.stringify(body) } : {}),
      signal: AbortSignal.timeout(15_000),
    });
    const result = asRecord(await response.json().catch(() => ({})));
    const status = typeof result.status === "string" ? result.status.toLowerCase() : "";
    if (!response.ok || result.ok === false || status === "error" || Boolean(result.error)) {
      throw new ServiceUnavailableException({ code: "RUBIKA_API_ERROR", message: "Rubika API returned HTTP " + response.status + "." });
    }
    return result;
  }

  private token(): string {
    return this.config.get<string>("RUBIKA_BOT_TOKEN", "").trim();
  }

  private requireToken(): string {
    const token = this.token();
    if (!token) {
      throw new ServiceUnavailableException({ code: "RUBIKA_NOT_CONFIGURED", message: "توکن بات روبیکا در متغیر محرمانهٔ RUBIKA_BOT_TOKEN تنظیم نشده است." });
    }
    return token;
  }

  private webhookBaseUrl(): string | null {
    const configured = this.config.get<string>("RUBIKA_WEBHOOK_BASE_URL", "").trim()
      || this.config.get<string>("PUBLIC_API_URL", "").trim()
      || this.config.get<string>("RAILWAY_PUBLIC_DOMAIN", "").trim();
    if (!configured) return null;
    const candidate = configured.includes("://") ? configured : "https://" + configured;
    try {
      const url = new URL(candidate);
      return url.protocol === "https:" ? url.origin : null;
    } catch { return null; }
  }

  private webhookSecret(token: string): string {
    return createHmac("sha256", token).update("PanizStyle Rubika ReceiveUpdate v1").digest("hex");
  }
}

function extractLinkCode(text: string): string | null {
  const match = text.match(/^(?:(?:\/?(?:link|connect|کد|اتصال))\s+)?(PZ-[A-F0-9]{16})$/i);
  return match?.[1]?.toUpperCase() ?? null;
}

function hashLinkCode(code: string): string {
  return createHash("sha256").update(code.toUpperCase()).digest("hex");
}

function safeSecretEquals(received: string, expected: string): boolean {
  if (!/^[a-f0-9]{64}$/i.test(received)) return false;
  return timingSafeEqual(Buffer.from(received, "hex"), Buffer.from(expected, "hex"));
}

function asRecord(value: unknown): Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value) ? value as Record<string, unknown> : {};
}

function stringOrNull(value: unknown): string | null {
  return typeof value === "string" && value.trim() ? value.trim() : null;
}

function isUniqueError(error: unknown): boolean {
  return error instanceof Prisma.PrismaClientKnownRequestError && error.code === "P2002";
}
