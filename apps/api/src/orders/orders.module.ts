import { Module } from "@nestjs/common";
import { OrdersController } from "./orders.controller";
import { OrdersService } from "./orders.service";
import { CustomerModule } from "../customer/customer.module";

@Module({
  controllers: [OrdersController],
  providers: [OrdersService],
  imports: [CustomerModule],
})
export class OrdersModule {}
