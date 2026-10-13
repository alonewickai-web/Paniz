import { Module } from "@nestjs/common";
import { OrdersController } from "./orders.controller";
import { OrdersService } from "./orders.service";
import { CustomerModule } from "../customer/customer.module";
import { AdminNotificationsModule } from "../admin-notifications/admin-notifications.module";

@Module({
  controllers: [OrdersController],
  providers: [OrdersService],
  imports: [CustomerModule, AdminNotificationsModule],
})
export class OrdersModule {}
