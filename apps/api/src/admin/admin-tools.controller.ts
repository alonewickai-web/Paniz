import { Body, Controller, Get, Param, Patch, Post, Query, Req, UseGuards } from "@nestjs/common";
import { ApiBearerAuth, ApiTags } from "@nestjs/swagger";
import { AdminRequest, AdminSessionGuard } from "../admin-auth/admin-session.guard";
import { AdminToolsService } from "./admin-tools.service";

@ApiTags("مدیریت مشتریان و ارتباطات")
@ApiBearerAuth("admin-session")
@UseGuards(AdminSessionGuard)
@Controller("admin")
export class AdminToolsController {
  constructor(private readonly tools: AdminToolsService) {}

  @Get("customers")
  customers(@Req() request: AdminRequest, @Query() query: Record<string, string>) {
    return this.tools.listCustomers(request.admin!, query);
  }

  @Get("products/options")
  productOptions(@Req() request: AdminRequest) {
    return this.tools.productOptions(request.admin!);
  }

  @Get("coupons")
  coupons(@Req() request: AdminRequest) {
    return this.tools.listCoupons(request.admin!);
  }

  @Post("coupons")
  createCoupon(@Req() request: AdminRequest, @Body() body: Record<string, unknown>) {
    return this.tools.saveCoupon(request.admin!, null, body);
  }

  @Patch("coupons/:id")
  updateCoupon(@Req() request: AdminRequest, @Param("id") id: string, @Body() body: Record<string, unknown>) {
    return this.tools.saveCoupon(request.admin!, id, body);
  }

  @Post("sms-campaigns/preview")
  previewSms(@Req() request: AdminRequest, @Body() body: Record<string, unknown>) {
    return this.tools.previewSmsAudience(request.admin!, body.filters);
  }

  @Get("sms-campaigns")
  smsCampaigns(@Req() request: AdminRequest) {
    return this.tools.listSmsCampaigns(request.admin!);
  }

  @Post("sms-campaigns")
  createSms(@Req() request: AdminRequest, @Body() body: Record<string, unknown>) {
    return this.tools.createSmsCampaign(request.admin!, body);
  }

  @Post("sms-campaigns/:id/send")
  sendSms(@Req() request: AdminRequest, @Param("id") id: string) {
    return this.tools.sendSmsCampaign(request.admin!, id);
  }

  @Post("rubika-campaigns/preview")
  previewRubika(@Req() request: AdminRequest, @Body() body: Record<string, unknown>) {
    return this.tools.previewRubikaAudience(request.admin!, body.filters);
  }

  @Get("rubika-campaigns")
  rubikaCampaigns(@Req() request: AdminRequest) {
    return this.tools.listRubikaCampaigns(request.admin!);
  }

  @Post("rubika-campaigns")
  createRubika(@Req() request: AdminRequest, @Body() body: Record<string, unknown>) {
    return this.tools.createRubikaCampaign(request.admin!, body);
  }

  @Post("rubika-campaigns/:id/send")
  sendRubika(@Req() request: AdminRequest, @Param("id") id: string) {
    return this.tools.sendRubikaCampaign(request.admin!, id);
  }

  @Get("social/status")
  socialStatus(@Req() request: AdminRequest) {
    return this.tools.socialStatus(request.admin!);
  }

  @Get("social/products")
  socialProducts(@Req() request: AdminRequest) {
    return this.tools.socialProducts(request.admin!);
  }

  @Get("social/posts")
  socialPosts(@Req() request: AdminRequest) {
    return this.tools.listSocialPosts(request.admin!);
  }

  @Post("social/posts")
  createSocialPost(@Req() request: AdminRequest, @Body() body: Record<string, unknown>) {
    return this.tools.createSocialPost(request.admin!, body);
  }

  @Get("operations/status")
  operationsStatus(@Req() request: AdminRequest) {
    return this.tools.operationsStatus(request.admin!);
  }

  @Get("operations/backups")
  backups(@Req() request: AdminRequest) {
    return this.tools.listBackups(request.admin!);
  }

  @Post("operations/backups")
  createBackup(@Req() request: AdminRequest) {
    return this.tools.createBackup(request.admin!);
  }
}
