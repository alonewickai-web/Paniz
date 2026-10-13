import {
  ForbiddenException,
  HttpException,
  HttpStatus,
  Injectable,
  Logger,
  UnauthorizedException,
} from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { Prisma } from "@prisma/client";
import { createHash, randomBytes, randomInt, timingSafeEqual } from "node:crypto";
import { PrismaService } from "../database/prisma.service";
import { CustomerRequest } from "./customer-session.guard";
import { normalizeIranPhone } from "./dto/phone.dto";
import { PhoneDto } from "./dto/phone.dto";
import { VerifyPhoneCodeDto } from "./dto/verify-phone-code.dto";
import { CustomerSmsService } from "./sms.service";

const CODE_TTL_MINUTES = 5;
const RESEND_DELAY_SECONDS = 180;
const MAX_DAILY_CODES = 10;
const MAX_CODE_ATTEMPTS = 5;
const CUSTOMER_SESSION_DAYS = 30;

@Injectable()
export class CustomerAuthService {
  private readonly logger = new Logger(CustomerAuthService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
    private readonly sms: CustomerSmsService,
  ) {}

  async sendCode(input: PhoneDto) {
    const phone = normalizeIranPhone(input.phone);
    const now = new Date();
    const recent = await this.prisma.otpRequest.findFirst({
      where: { phone, status: { not: "failed" }, createdAt: { gt: new Date(now.getTime() - RESEND_DELAY_SECONDS * 1000) } },
      orderBy: { createdAt: "desc" },
    });
    if (recent) {
      throw new HttpException({
        code: "OTP_RESEND_WAIT",
        retryAfterSeconds: Math.max(1, Math.ceil((recent.createdAt.getTime() + RESEND_DELAY_SECONDS * 1000 - now.getTime()) / 1000)),
        message: "برای دریافت کد تازه کمی صبر کن.",
      }, HttpStatus.TOO_MANY_REQUESTS);
    }

    const todayCount = await this.prisma.otpRequest.count({
      // Provider failures never delivered a code, so they must not consume the customer's daily quota.
      where: {
        phone,
        createdAt: { gt: new Date(now.getTime() - 24 * 60 * 60 * 1000) },
        status: { not: "failed" },
      },
    });
    if (todayCount >= MAX_DAILY_CODES) {
      throw new HttpException({ code: "OTP_DAILY_LIMIT", message: "سقف دریافت کد امروز برای این شماره تکمیل شده است." }, HttpStatus.TOO_MANY_REQUESTS);
    }

    const code = randomInt(0, 1_000_000).toString().padStart(6, "0");
    const expiresAt = new Date(now.getTime() + CODE_TTL_MINUTES * 60_000);
    await this.prisma.otpRequest.updateMany({
      where: { phone, status: "pending" },
      data: { status: "superseded" },
    });
    const request = await this.prisma.otpRequest.create({
      data: { phone, codeHash: hashOtp(this.otpSecret(), phone, code), expiresAt },
    });

    let delivery: { developmentCode?: string };
    try {
      delivery = await this.sms.sendLoginCode(phone, code);
    } catch (error) {
      await this.prisma.otpRequest.update({ where: { id: request.id }, data: { status: "failed" } });
      throw error;
    }

    const sentAt = new Date();
    await this.prisma.otpRequest.update({ where: { id: request.id }, data: { createdAt: sentAt } });

    return {
      data: {
        phone,
        expiresAt: expiresAt.toISOString(),
        retryAfterSeconds: RESEND_DELAY_SECONDS,
        sentAt: sentAt.toISOString(),
        ...(delivery.developmentCode ? { developmentCode: delivery.developmentCode } : {}),
      },
    };
  }

  async verifyCode(input: VerifyPhoneCodeDto) {
    const phone = normalizeIranPhone(input.phone);
    const now = new Date();
    const request = await this.prisma.otpRequest.findFirst({
      where: { phone, status: "pending", expiresAt: { gt: now } },
      orderBy: { createdAt: "desc" },
    });
    if (!request || request.attemptCount >= MAX_CODE_ATTEMPTS) {
      throw new UnauthorizedException({ code: "OTP_INVALID_OR_EXPIRED", message: "کد معتبر نیست یا مهلتش تمام شده؛ کد تازه بگیر." });
    }

    const expected = Buffer.from(request.codeHash, "hex");
    const actual = Buffer.from(hashOtp(this.otpSecret(), phone, input.code), "hex");
    const isValidCode = expected.length === actual.length && timingSafeEqual(expected, actual);
    if (!isValidCode && !this.acceptsAnyDevelopmentCode()) {
      const attemptCount = request.attemptCount + 1;
      await this.prisma.otpRequest.update({
        where: { id: request.id },
        data: { attemptCount, ...(attemptCount >= MAX_CODE_ATTEMPTS ? { status: "locked" } : {}) },
      });
      throw new UnauthorizedException({ code: "OTP_INVALID_OR_EXPIRED", message: "کد واردشده درست نیست." });
    }

    const accessToken = randomBytes(32).toString("base64url");
    const expiresAt = new Date(now.getTime() + CUSTOMER_SESSION_DAYS * 24 * 60 * 60 * 1000);
    const result = await this.prisma.$transaction(async (tx) => {
      const consumed = await tx.otpRequest.updateMany({
        where: { id: request.id, status: "pending", consumedAt: null, expiresAt: { gt: now } },
        data: { status: "verified", consumedAt: now },
      });
      if (consumed.count !== 1) {
        throw new UnauthorizedException({ code: "OTP_ALREADY_USED", message: "این کد قبلاً استفاده شده؛ کد تازه بگیر." });
      }

      const customer = await tx.customer.upsert({
        where: { phone },
        update: { phoneVerifiedAt: now },
        create: { phone, phoneVerifiedAt: now },
      });
      if (customer.status === "active") {
        await tx.customerSession.create({
          data: { customerId: customer.id, tokenHash: hashSessionToken(accessToken), expiresAt, lastUsedAt: now },
        });
      }
      return customer;
    }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });

    if (result.status !== "active") {
      throw new ForbiddenException({ code: "CUSTOMER_ACCOUNT_DISABLED", message: "دسترسی این حساب غیرفعال شده است." });
    }

    return {
      accessToken,
      expiresAt,
      customer: publicCustomer(result),
    };
  }

  me(request: CustomerRequest) {
    return { data: publicCustomer(request.customer!) };
  }

  async logout(request: CustomerRequest) {
    await this.prisma.customerSession.updateMany({
      where: { id: request.customerSessionId, revokedAt: null },
      data: { revokedAt: new Date() },
    });
    return { data: { revoked: true } };
  }

  private otpSecret(): string {
    const secret = this.config.get<string>("CUSTOMER_AUTH_SECRET");
    if (secret && secret.length >= 32) return secret;
    if (this.config.get<string>("NODE_ENV") === "production") {
      this.logger.error("CUSTOMER_AUTH_SECRET is required in production.");
      throw new ForbiddenException({ code: "CUSTOMER_AUTH_NOT_CONFIGURED", message: "ورود مشتری هنوز تنظیم نشده است." });
    }
    return "panizstyle-local-development-otp-pepper";
  }

  private acceptsAnyDevelopmentCode(): boolean {
    return this.config.get<string>("NODE_ENV", "development") === "development"
      && this.config.get<string>("CUSTOMER_OTP_BYPASS") === "true";
  }
}

function hashOtp(secret: string, phone: string, code: string): string {
  return createHash("sha256").update(`${secret}:${phone}:${code}`).digest("hex");
}

function hashSessionToken(token: string): string {
  return createHash("sha256").update(token).digest("hex");
}

function publicCustomer(customer: { id: bigint; phone: string; fullName: string | null; email: string | null }) {
  return {
    id: customer.id.toString(),
    phone: customer.phone,
    fullName: customer.fullName,
    email: customer.email,
  };
}
