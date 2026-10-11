import { Body, BadRequestException, Controller, Delete, ForbiddenException, Get, Param, Patch, Post, Query, Req, UploadedFile, UseGuards, UseInterceptors } from "@nestjs/common";
import { FileInterceptor } from "@nestjs/platform-express";
import { ApiBearerAuth, ApiBody, ApiOperation, ApiQuery, ApiTags } from "@nestjs/swagger";
import { randomUUID } from "node:crypto";
import { diskStorage } from "multer";
import { AdminRequest, AdminSessionGuard } from "../admin-auth/admin-session.guard";
import { productImageRoot } from "../uploads/upload-storage";
import { AdminService } from "./admin.service";
import { AdjustInventoryDto } from "./dto/adjust-inventory.dto";
import { AddAdminProductVariantDto } from "./dto/add-admin-product-variant.dto";
import { AddAdminProductImageDto } from "./dto/add-admin-product-image.dto";
import { CreateAdminProductDto } from "./dto/create-admin-product.dto";
import { ListAdminOrdersQuery } from "./dto/list-admin-orders.query";
import { ListAdminProductsQuery } from "./dto/list-admin-products.query";
import { UpdateAdminProductDto } from "./dto/update-admin-product.dto";
import { UpdateAdminVariantDto } from "./dto/update-admin-variant.dto";
import { UpdateAdminOrderDto } from "./dto/update-admin-order.dto";

@ApiTags("مدیریت فروشگاه")
@ApiBearerAuth("admin-session")
@UseGuards(AdminSessionGuard)
@Controller("admin")
export class AdminController {
  constructor(private readonly admin: AdminService) {}

  @Get("dashboard")
  @ApiOperation({ summary: "خلاصهٔ فروش، سفارش‌ها و هشدار کمبود موجودی" })
  dashboard(@Req() request: AdminRequest) {
    return this.admin.dashboard(request.admin!);
  }

  @Post("uploads/product-image")
  @UseInterceptors(FileInterceptor("file", {
    storage: diskStorage({
      destination: productImageRoot(),
      filename: (_request, file, callback) => {
        const extension = ({ "image/jpeg": ".jpg", "image/png": ".png", "image/webp": ".webp" } as Record<string, string>)[file.mimetype];
        callback(null, `${randomUUID()}${extension ?? ".img"}`);
      },
    }),
    limits: { fileSize: 8 * 1024 * 1024, files: 1 },
    fileFilter: (_request, file, callback) => {
      const supported = ["image/jpeg", "image/png", "image/webp"].includes(file.mimetype);
      callback(supported ? null : new BadRequestException({ code: "UNSUPPORTED_IMAGE_TYPE", message: "Only JPG, PNG, and WebP images are supported." }), supported);
    },
  }))
  @ApiOperation({ summary: "Upload a product image from the admin app" })
  uploadProductImage(@Req() request: AdminRequest, @UploadedFile() file?: { filename: string; mimetype: string }) {
    if (request.admin?.role !== "owner" && request.admin?.role !== "admin") {
      throw new ForbiddenException({ code: "ADMIN_PERMISSION_REQUIRED", message: "Manager access is required." });
    }
    if (!file) throw new BadRequestException({ code: "PRODUCT_IMAGE_REQUIRED", message: "Select a product image first." });
    return { data: { imagePath: `/uploads/products/${file.filename}`, mimeType: file.mimetype } };
  }

  @Get("orders")
  @ApiOperation({ summary: "فهرست صفحه‌بندی‌شدهٔ سفارش‌ها برای مدیر" })
  @ApiQuery({ name: "page", required: false, type: Number })
  @ApiQuery({ name: "pageSize", required: false, type: Number })
  @ApiQuery({ name: "status", required: false, type: String })
  @ApiQuery({ name: "q", required: false, type: String })
  listOrders(@Req() request: AdminRequest, @Query() query: ListAdminOrdersQuery) {
    return this.admin.listOrders(request.admin!, query);
  }

  @Get("products")
  @ApiOperation({ summary: "فهرست محصولات مدیریتی، شامل پیش‌نویس و بایگانی" })
  @ApiQuery({ name: "page", required: false, type: Number })
  @ApiQuery({ name: "pageSize", required: false, type: Number })
  @ApiQuery({ name: "status", required: false, enum: ["draft", "published", "archived"] })
  @ApiQuery({ name: "q", required: false, type: String })
  listProducts(@Query() query: ListAdminProductsQuery) {
    return this.admin.listProducts(query);
  }

  @Post("products")
  @ApiOperation({ summary: "ثبت محصول همراه تصویرها و تنوع‌های اولیه" })
  @ApiBody({ type: CreateAdminProductDto })
  createProduct(@Req() request: AdminRequest, @Body() body: CreateAdminProductDto) {
    return this.admin.createProduct(request.admin!, body);
  }

  @Patch("products/:id")
  @ApiOperation({ summary: "ویرایش اطلاعات و انتشار یا پیش‌نویس محصول" })
  @ApiBody({ type: UpdateAdminProductDto })
  updateProduct(@Req() request: AdminRequest, @Param("id") id: string, @Body() body: UpdateAdminProductDto) {
    return this.admin.updateProduct(request.admin!, id, body);
  }

  @Post("products/:id/variants")
  @ApiOperation({ summary: "افزودن تنوع رنگ و سایز به محصول" })
  @ApiBody({ type: AddAdminProductVariantDto })
  addProductVariant(@Req() request: AdminRequest, @Param("id") id: string, @Body() body: AddAdminProductVariantDto) {
    return this.admin.addProductVariant(request.admin!, id, body);
  }

  @Post("products/:id/images")
  @ApiOperation({ summary: "افزودن تصویر میزبانی‌شده به گالری محصول" })
  @ApiBody({ type: AddAdminProductImageDto })
  addProductImage(@Req() request: AdminRequest, @Param("id") id: string, @Body() body: AddAdminProductImageDto) {
    return this.admin.addProductImage(request.admin!, id, body);
  }

  @Delete("products/:id/images/:imageId")
  @ApiOperation({ summary: "حذف تصویر از گالری؛ تصویر اصلی در صورت نیاز جایگزین می‌شود" })
  deleteProductImage(@Req() request: AdminRequest, @Param("id") id: string, @Param("imageId") imageId: string) {
    return this.admin.deleteProductImage(request.admin!, id, imageId);
  }

  @Delete("products/:id")
  @ApiOperation({ summary: "بایگانی نرم محصول و نگهداری سابقهٔ سفارش" })
  archiveProduct(@Req() request: AdminRequest, @Param("id") id: string) {
    return this.admin.archiveProduct(request.admin!, id);
  }

  @Patch("orders/:id/status")
  @ApiOperation({ summary: "تغییر وضعیت سفارش طبق گردش مجاز و ثبت در تاریخچه" })
  @ApiBody({ type: UpdateAdminOrderDto })
  updateOrderStatus(@Req() request: AdminRequest, @Param("id") id: string, @Body() body: UpdateAdminOrderDto) {
    return this.admin.updateOrderStatus(request.admin!, id, body);
  }

  @Patch("inventory/variants/:variantId")
  @ApiOperation({ summary: "تغییر موجودی تنوع با کنترل رزرو و ثبت گردش انبار" })
  @ApiBody({ type: AdjustInventoryDto })
  adjustInventory(@Req() request: AdminRequest, @Param("variantId") variantId: string, @Body() body: AdjustInventoryDto) {
    return this.admin.adjustInventory(request.admin!, variantId, body);
  }

  @Patch("products/variants/:variantId")
  @ApiOperation({ summary: "ویرایش قیمت، تخفیف، وضعیت فعال یا آستانهٔ کمبود تنوع" })
  @ApiBody({ type: UpdateAdminVariantDto })
  updateVariant(@Req() request: AdminRequest, @Param("variantId") variantId: string, @Body() body: UpdateAdminVariantDto) {
    return this.admin.updateVariant(request.admin!, variantId, body);
  }
}
