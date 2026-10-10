import { Module } from "@nestjs/common";
import { CustomerAuthController } from "./customer-auth.controller";
import { CustomerAuthService } from "./customer-auth.service";
import { CustomerController } from "./customer.controller";
import { CustomerService } from "./customer.service";
import { CustomerSessionGuard } from "./customer-session.guard";
import { CustomerSmsService } from "./sms.service";

@Module({
  controllers: [CustomerAuthController, CustomerController],
  providers: [CustomerAuthService, CustomerService, CustomerSessionGuard, CustomerSmsService],
  exports: [CustomerSessionGuard],
})
export class CustomerModule {}
