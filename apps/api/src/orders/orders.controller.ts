import { Body, Controller, Headers, Post, Req, UseGuards } from "@nestjs/common";
import { ApiBody, ApiHeader, ApiOperation, ApiTags } from "@nestjs/swagger";
import { CreateCustomerOrderDto } from "../customer/dto/create-customer-order.dto";
import { CustomerRequest, CustomerSessionGuard } from "../customer/customer-session.guard";
import { QuoteCartDto } from "./dto/quote-cart.dto";
import { TrackOrderDto } from "./dto/track-order.dto";
import { OrdersService } from "./orders.service";

@ApiTags("سبد و سفارش")
@Controller()
export class OrdersController {
  constructor(private readonly ordersService: OrdersService) {}

  @Post("checkout/quote")
  @ApiOperation({ summary: "محاسبهٔ قیمت معتبر سبد از دیتابیس" })
  @ApiBody({ type: QuoteCartDto })
  quote(@Body() body: QuoteCartDto) {
    return this.ordersService.quote(body.items);
  }

  @Post("orders")
  @UseGuards(CustomerSessionGuard)
  @ApiOperation({ summary: "ثبت سفارش مشتری واردشده با نشانی ذخیره‌شده و رزرو موقت موجودی" })
  @ApiHeader({ name: "Idempotency-Key", required: true, description: "شناسهٔ یکتای تلاش ثبت سفارش" })
  @ApiBody({ type: CreateCustomerOrderDto })
  create(@Body() body: CreateCustomerOrderDto, @Req() request: CustomerRequest, @Headers("idempotency-key") idempotencyKey?: string) {
    return this.ordersService.createCustomerOrder(request.customer!.id, body, idempotencyKey ?? "");
  }

  @Post("orders/track")
  @ApiOperation({ summary: "پیگیری سفارش با شماره سفارش و تلفن گیرنده" })
  @ApiBody({ type: TrackOrderDto })
  track(@Body() body: TrackOrderDto) {
    return this.ordersService.trackOrder(body);
  }
}
