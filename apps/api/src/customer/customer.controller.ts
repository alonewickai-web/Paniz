import { BadRequestException, Body, Controller, Delete, Get, Param, Patch, Post, Req, UploadedFile, UseGuards, UseInterceptors } from "@nestjs/common";
import { FileInterceptor } from "@nestjs/platform-express";
import { diskStorage } from "multer";
import { randomUUID } from "node:crypto";
import { ApiOperation, ApiTags } from "@nestjs/swagger";
import { CustomerService } from "./customer.service";
import { CustomerRequest, CustomerSessionGuard } from "./customer-session.guard";
import { UpdateCustomerProfileDto } from "./dto/update-customer-profile.dto";
import { SaveCustomerAddressDto } from "./dto/save-customer-address.dto";
import { SupportService } from "../support/support.service";
import { CreateTicketDto, SupportMessageDto } from "../support/dto/create-ticket.dto";
import { CreateReturnDto } from "../support/dto/create-return.dto";
import { CustomerPushSubscriptionDto, RemoveCustomerPushSubscriptionDto } from "../support/dto/customer-push-subscription.dto";
import { supportImageRoot } from "../uploads/upload-storage";

@ApiTags("پروفایل و سفارش‌های مشتری")
@Controller("customer")
@UseGuards(CustomerSessionGuard)
export class CustomerController {
  constructor(private readonly customers: CustomerService, private readonly support: SupportService) {}

  @Get("push/public-key")
  pushPublicKey() { return this.support.pushPublicKey(); }

  @Post("push/subscriptions")
  savePushSubscription(@Req() request: CustomerRequest, @Body() body: CustomerPushSubscriptionDto) {
    return this.support.savePushSubscription(request.customer!.id, body);
  }

  @Delete("push/subscriptions")
  removePushSubscription(@Req() request: CustomerRequest, @Body() body: RemoveCustomerPushSubscriptionDto) {
    return this.support.removePushSubscription(request.customer!.id, body.endpoint);
  }

  @Post("back-in-stock/:variantId")
  @ApiOperation({ summary: "درخواست اعلان هنگام موجودشدن تنوع کالا" })
  backInStock(@Req() request: CustomerRequest, @Param("variantId") variantId: string) {
    return this.support.subscribeBackInStock(request.customer!.id, variantId);
  }

  @Get("support/tickets")
  tickets(@Req() request: CustomerRequest) { return this.support.customerTickets(request.customer!.id); }

  @Post("support/tickets")
  createTicket(@Req() request: CustomerRequest, @Body() body: CreateTicketDto) {
    return this.support.createTicket(request.customer!.id, body);
  }

  @Post("support/uploads/image")
  @UseInterceptors(FileInterceptor("file", {
    storage: diskStorage({ destination: supportImageRoot(), filename: (_request, file, callback) => {
      const extension = ({ "image/jpeg": ".jpg", "image/png": ".png", "image/webp": ".webp" } as Record<string, string>)[file.mimetype];
      callback(null, `${randomUUID()}${extension ?? ".img"}`);
    } }),
    limits: { fileSize: 5 * 1024 * 1024, files: 1 },
    fileFilter: (_request, file, callback) => {
      const supported = ["image/jpeg", "image/png", "image/webp"].includes(file.mimetype);
      callback(supported ? null : new BadRequestException({ code: "UNSUPPORTED_IMAGE_TYPE", message: "تصویر باید JPG، PNG یا WebP باشد." }), supported);
    },
  }))
  uploadSupportImage(@UploadedFile() file?: { filename: string; size: number }) {
    if (!file) throw new BadRequestException({ code: "SUPPORT_IMAGE_REQUIRED", message: "یک تصویر انتخاب کن." });
    return { data: { imagePath: `/uploads/support/${file.filename}`, fileSizeBytes: file.size } };
  }

  @Post("support/tickets/:id/messages")
  replyTicket(@Req() request: CustomerRequest, @Param("id") id: string, @Body() body: SupportMessageDto) {
    return this.support.customerReply(request.customer!.id, id, body);
  }

  @Get("returns")
  customerReturns(@Req() request: CustomerRequest) { return this.support.customerReturns(request.customer!.id); }

  @Post("orders/:orderNumber/return")
  createReturn(@Req() request: CustomerRequest, @Param("orderNumber") orderNumber: string, @Body() body: CreateReturnDto) {
    return this.support.createReturn(request.customer!.id, orderNumber, body);
  }

  @Get("profile")
  @ApiOperation({ summary: "نمایش اطلاعات و نشانی‌های ذخیره‌شدهٔ مشتری" })
  getProfile(@Req() request: CustomerRequest) {
    return this.customers.getProfile(request);
  }

  @Patch("profile")
  @ApiOperation({ summary: "ذخیرهٔ نام و ایمیل مشتری" })
  updateProfile(@Req() request: CustomerRequest, @Body() body: UpdateCustomerProfileDto) {
    return this.customers.updateProfile(request, body);
  }

  @Post("rubika/link-code")
  @ApiOperation({ summary: "ساخت کد یک‌بارمصرف اتصال حساب روبیکا" })
  createRubikaLinkCode(@Req() request: CustomerRequest) {
    return this.customers.createRubikaLinkCode(request);
  }

  @Delete("rubika/link")
  @ApiOperation({ summary: "قطع اتصال روبیکا از حساب مشتری" })
  unlinkRubika(@Req() request: CustomerRequest) {
    return this.customers.unlinkRubika(request);
  }

  @Get("orders")
  @ApiOperation({ summary: "نمایش سفارش‌های حساب مشتری" })
  listOrders(@Req() request: CustomerRequest) {
    return this.customers.listOrders(request);
  }

  @Get("addresses")
  @ApiOperation({ summary: "نمایش نشانی‌های ذخیره‌شدهٔ مشتری" })
  listAddresses(@Req() request: CustomerRequest) {
    return this.customers.listAddresses(request);
  }

  @Post("addresses")
  @ApiOperation({ summary: "ذخیرهٔ نشانی تحویل جدید" })
  saveAddress(@Req() request: CustomerRequest, @Body() body: SaveCustomerAddressDto) {
    return this.customers.saveAddress(request, body);
  }

  @Patch("addresses/:id")
  @ApiOperation({ summary: "ویرایش نشانی ذخیره‌شده" })
  updateAddress(@Req() request: CustomerRequest, @Param("id") id: string, @Body() body: SaveCustomerAddressDto) {
    return this.customers.updateAddress(request, id, body);
  }

  @Post("addresses/:id/default")
  @ApiOperation({ summary: "انتخاب نشانی پیش‌فرض مشتری" })
  setDefaultAddress(@Req() request: CustomerRequest, @Param("id") id: string) {
    return this.customers.setDefaultAddress(request, id);
  }

  @Delete("addresses/:id")
  @ApiOperation({ summary: "حذف نشانی ذخیره‌شده" })
  deleteAddress(@Req() request: CustomerRequest, @Param("id") id: string) {
    return this.customers.deleteAddress(request, id);
  }
}
