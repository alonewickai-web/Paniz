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

    throw new ServiceUnavailableException({
      code: "SMS_PROVIDER_NOT_CONFIGURED",
      message: "سرویس انتخاب‌شدهٔ پیامک هنوز به تنظیمات اتصال نیاز دارد.",
    });
  }
}

function maskPhone(phone: string): string {
  return phone.length > 6 ? `${phone.slice(0, 6)}••••` : "شمارهٔ مشتری";
}
