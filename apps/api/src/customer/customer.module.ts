import { Module } from "@nestjs/common";
import { CustomerAuthController } from "./customer-auth.controller";
import { CustomerAuthService } from "./customer-auth.service";
import { CustomerController } from "./customer.controller";
import { CustomerService } from "./customer.service";
import { CustomerSessionGuard } from "./customer-session.guard";
import { CustomerSmsService } from "./sms.service";
import { RubikaModule } from "../integrations/rubika/rubika.module";
import { AdminNotificationsModule } from "../admin-notifications/admin-notifications.module";
import { ContactMessageController } from "./contact-message.controller";

@Module({
  imports: [RubikaModule, AdminNotificationsModule],
  controllers: [CustomerAuthController, CustomerController, ContactMessageController],
  providers: [CustomerAuthService, CustomerService, CustomerSessionGuard, CustomerSmsService],
  exports: [CustomerSessionGuard],
})
export class CustomerModule {}
