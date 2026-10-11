import { Injectable, Logger, ServiceUnavailableException } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";

@Injectable()
export class CustomerSmsService {
  private readonly logger = new Logger(CustomerSmsService.name);

  constructor(private readonly config: ConfigService) {}

  async sendLoginCode(phone: string, code: string): Promise<{ developmentCode?: string }> {
    const environment = this.config.get<string>("NODE_ENV", "development");
    const provider = this.config.get<string>("SMS_PROVIDER", environment === "production" ? "" : "console");

    if (provider === "console" && environment !== "production") {
      this.logger.log(`Development login code for ${maskPhone(phone)}: ${code}`);
      return { developmentCode: code };
    }

    if (provider === "console") {
      throw new ServiceUnavailableException({
        code: "SMS_PROVIDER_NOT_CONFIGURED",
        message: "سرویس پیامک برای ارسال کد ورود در حالت عملیاتی تنظیم نشده است.",
      });
    }

    if (provider === "smsir") {
      const apiKey = this.config.get<string>("SMSIR_API_KEY", "");
      const lineNumber = this.config.get<string>("SMSIR_LINE_NUMBER", "");
      if (!apiKey || !lineNumber) {
        throw new ServiceUnavailableException({
          code: "SMS_PROVIDER_NOT_CONFIGURED",
          message: "تنظیمات API پیامک SMS.ir کامل نیست.",
        });
      }
      try {
        const endpoint = this.config.get<string>("SMSIR_BULK_URL", "https://api.sms.ir/v1/send/bulk");
        const response = await fetch(endpoint, {
          method: "POST",
          headers: { "Content-Type": "application/json", "X-API-KEY": apiKey },
          body: JSON.stringify({
            lineNumber,
            MessageText: `کد ورود به PANIZ: ${code}`,
            Mobiles: [toSmsIranPhone(phone)],
          }),
          signal: AbortSignal.timeout(15_000),
        });
        const result = await response.json().catch(() => ({})) as Record<string, unknown>;
        if (!response.ok || smsIrRejected(result)) throw new Error(`SMS.ir returned HTTP ${response.status}.`);
        return {};
      } catch {
        throw new ServiceUnavailableException({
          code: "SMS_PROVIDER_UNAVAILABLE",
          message: "ارسال کد ورود با سرویس پیامک انجام نشد. کمی بعد دوباره تلاش کنید.",
        });
      }
    }

    throw new ServiceUnavailableException({
      code: "SMS_PROVIDER_NOT_CONFIGURED",
      message: "سرویس انتخاب‌شدهٔ پیامک هنوز به تنظیمات اتصال نیاز دارد.",
    });
  }
}

function toSmsIranPhone(phone: string): string {
  if (phone.startsWith("+98")) return `0${phone.slice(3)}`;
  if (phone.startsWith("98")) return `0${phone.slice(2)}`;
  return phone;
}

function smsIrRejected(result: Record<string, unknown>): boolean {
  const status = result.status ?? result.Status;
  return result.IsSuccessful === false || result.isSuccessful === false || status === 0 || status === "0" || status === "ERROR" || status === "error";
}

function maskPhone(phone: string): string {
  return phone.length > 6 ? `${phone.slice(0, 6)}••••` : "شمارهٔ مشتری";
}
