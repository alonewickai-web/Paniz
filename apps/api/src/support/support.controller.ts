import { BadRequestException, Body, Controller, Get, Param, Patch, Post, Req, UploadedFile, UseGuards, UseInterceptors } from "@nestjs/common";
import { FileInterceptor } from "@nestjs/platform-express";
import { diskStorage } from "multer";
import { randomUUID } from "node:crypto";
import { ApiBearerAuth, ApiOperation, ApiTags } from "@nestjs/swagger";
import { AdminPermissionGuard, RequireAdminPermission } from "../admin-auth/admin-permission.guard";
import { AdminRequest, AdminSessionGuard } from "../admin-auth/admin-session.guard";
import { SupportMessageDto } from "./dto/create-ticket.dto";
import { UpdateReturnDto } from "./dto/create-return.dto";
import { SupportService } from "./support.service";
import { returnReceiptRoot, supportImageRoot } from "../uploads/upload-storage";

@ApiTags("پشتیبانی مشتریان")
@ApiBearerAuth("admin-session")
@UseGuards(AdminSessionGuard, AdminPermissionGuard)
@Controller("admin/support")
export class AdminSupportController {
  constructor(private readonly support: SupportService) {}

  @Get("tickets")
  @RequireAdminPermission("customers.view")
  @ApiOperation({ summary: "نمایش گفت‌وگوهای پشتیبانی مشتریان" })
  tickets() { return this.support.adminTickets(); }

  @Post("tickets/:id/messages")
  @RequireAdminPermission("customers.message")
  @ApiOperation({ summary: "پاسخ به مشتری در گفت‌وگوی پشتیبانی" })
  reply(@Req() request: AdminRequest, @Param("id") id: string, @Body() body: SupportMessageDto) {
    return this.support.adminReply(request.admin!.id, id, body);
  }

  @Post("uploads/image")
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
  @RequireAdminPermission("customers.message")
  uploadSupportImage(@UploadedFile() file?: { filename: string; size: number }) {
    if (!file) throw new BadRequestException({ code: "SUPPORT_IMAGE_REQUIRED", message: "یک تصویر انتخاب کن." });
    return { data: { imagePath: `/uploads/support/${file.filename}`, fileSizeBytes: file.size } };
  }

  @Get("returns")
  @RequireAdminPermission("orders.refund")
  @ApiOperation({ summary: "نمایش درخواست‌های مرجوعی" })
  returns() { return this.support.adminReturns(); }

  @Patch("returns/:id")
  @RequireAdminPermission("orders.refund")
  @ApiOperation({ summary: "ثبت وضعیت بررسی مرجوعی و بازپرداخت" })
  updateReturn(@Param("id") id: string, @Body() body: UpdateReturnDto) {
    return this.support.updateReturn(id, body);
  }

  @Post("returns/:id/receipt")
  @UseInterceptors(FileInterceptor("file", {
    storage: diskStorage({ destination: returnReceiptRoot(), filename: (_request, file, callback) => {
      const extension = ({ "image/jpeg": ".jpg", "image/png": ".png", "image/webp": ".webp" } as Record<string, string>)[file.mimetype];
      callback(null, `${randomUUID()}${extension ?? ".img"}`);
    } }),
    limits: { fileSize: 5 * 1024 * 1024, files: 1 },
    fileFilter: (_request, file, callback) => {
      const supported = ["image/jpeg", "image/png", "image/webp"].includes(file.mimetype);
      callback(supported ? null : new BadRequestException({ code: "UNSUPPORTED_IMAGE_TYPE", message: "تصویر باید JPG، PNG یا WebP باشد." }), supported);
    },
  }))
  @RequireAdminPermission("orders.refund")
  receipt(@Param("id") id: string, @UploadedFile() file?: { filename: string; size: number }) {
    if (!file) throw new BadRequestException({ code: "RETURN_RECEIPT_REQUIRED", message: "تصویر رسید را انتخاب کن." });
    return this.support.attachReturnReceipt(id, `/uploads/returns/${file.filename}`);
  }
}
