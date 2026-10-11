import { Body, Controller, Delete, Get, Param, Patch, Post, Req, UseGuards } from "@nestjs/common";
import { ApiOperation, ApiTags } from "@nestjs/swagger";
import { CustomerService } from "./customer.service";
import { CustomerRequest, CustomerSessionGuard } from "./customer-session.guard";
import { UpdateCustomerProfileDto } from "./dto/update-customer-profile.dto";
import { SaveCustomerAddressDto } from "./dto/save-customer-address.dto";

@ApiTags("پروفایل و سفارش‌های مشتری")
@Controller("customer")
@UseGuards(CustomerSessionGuard)
export class CustomerController {
  constructor(private readonly customers: CustomerService) {}

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
