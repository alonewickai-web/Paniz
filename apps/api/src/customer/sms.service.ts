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

    const sandbox = provider === "smsir-sandbox";
    if (sandbox && environment === "production") {
      throw new ServiceUnavailableException({
        code: "SMS_PROVIDER_NOT_CONFIGURED",
        message: "حالت آزمایشی پیامک در محیط عملیاتی مجاز نیست.",
      });
    }

    if (provider === "smsir" || sandbox) {
      const apiKey = this.config.get<string>(sandbox ? "SMSIR_SANDBOX_API_KEY" : "SMSIR_API_KEY", "");
      const lineNumber = this.config.get<string>("SMSIR_LINE_NUMBER", "");
      const numericLineNumber = Number(lineNumber);
      const configuredTemplate = this.config.get<string>("SMSIR_OTP_TEMPLATE_ID", "").trim();
      const templateId = sandbox ? 123456 : Number(configuredTemplate);
      const useTemplate = sandbox || Boolean(configuredTemplate);
      const parameterName = sandbox ? "Code" : this.config.get<string>("SMSIR_OTP_PARAMETER", "Code");
      if (!apiKey || (useTemplate ? !Number.isSafeInteger(templateId) || templateId < 1 || !parameterName : !Number.isSafeInteger(numericLineNumber) || numericLineNumber < 1)) {
        throw new ServiceUnavailableException({
          code: "SMS_PROVIDER_NOT_CONFIGURED",
          message: "تنظیمات API پیامک SMS.ir کامل نیست.",
        });
      }
      let providerHttpStatus: number | undefined;
      let providerStatus: unknown;
      let providerMessage: unknown;
      try {
        const endpoint = useTemplate
          ? this.config.get<string>("SMSIR_VERIFY_URL", "https://api.sms.ir/v1/send/verify")
          : this.config.get<string>("SMSIR_BULK_URL", "https://api.sms.ir/v1/send/bulk");
        const response = await fetch(endpoint, {
          method: "POST",
          headers: { "Content-Type": "application/json", Accept: "application/json", "X-API-KEY": apiKey },
          body: JSON.stringify(useTemplate ? {
            mobile: toSmsIranPhone(phone),
            templateId,
            parameters: [{ name: parameterName, value: code }],
          } : {
            lineNumber: numericLineNumber,
            messageText: `کد ورود شما به فروشگاه پانیذ: ${code}`,
            mobiles: [toSmsIranPhone(phone)],
          }),
          signal: AbortSignal.timeout(15_000),
        });
        providerHttpStatus = response.status;
        const result = await response.json().catch(() => ({})) as Record<string, unknown>;
        providerStatus = result.status ?? result.Status;
        providerMessage = result.message ?? result.Message;
        if (!response.ok || smsIrRejected(result)) throw new Error(`SMS.ir returned HTTP ${response.status}.`);
        return sandbox ? { developmentCode: code } : {};
      } catch (error) {
        this.logger.error(`SMS.ir login-code request failed: ${JSON.stringify({
          mode: useTemplate ? "verify" : "bulk",
          httpStatus: providerHttpStatus ?? null,
          providerStatus: providerStatus ?? null,
          providerMessage: safeProviderMessage(providerMessage),
          errorType: error instanceof Error ? error.name : "unknown",
        })}`);
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

function safeProviderMessage(value: unknown): string | null {
  if (typeof value !== "string") return null;
  return value.replace(/\d{4,}/g, "[redacted]").replace(/[\r\n]+/g, " ").slice(0, 180);
}

function toSmsIranPhone(phone: string): string {
  if (phone.startsWith("+98")) return `0${phone.slice(3)}`;
  if (phone.startsWith("98")) return `0${phone.slice(2)}`;
  return phone;
}

function smsIrRejected(result: Record<string, unknown>): boolean {
  const status = result.status ?? result.Status;
  return result.IsSuccessful === false || result.isSuccessful === false || (status !== 1 && status !== "1");
}

function maskPhone(phone: string): string {
  return phone.length > 6 ? `${phone.slice(0, 6)}••••` : "شمارهٔ مشتری";
}
