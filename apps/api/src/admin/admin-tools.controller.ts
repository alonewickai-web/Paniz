import { AdminPermissionGuard, RequireAdminPermission, RequireAnyAdminPermission } from "../admin-auth/admin-permission.guard";
import { Body, Controller, Get, Param, Patch, Post, Query, Req, UseGuards } from "@nestjs/common";
import { ApiBearerAuth, ApiTags } from "@nestjs/swagger";
import { AdminRequest, AdminSessionGuard } from "../admin-auth/admin-session.guard";
import { AdminToolsService } from "./admin-tools.service";

@ApiTags("مدیریت مشتریان و ارتباطات")
@ApiBearerAuth("admin-session")
@UseGuards(AdminSessionGuard, AdminPermissionGuard)
@Controller("admin")
export class AdminToolsController {
  constructor(private readonly tools: AdminToolsService) {}

  @Get("customers")
  @RequireAdminPermission("customers.view")
  customers(@Req() request: AdminRequest, @Query() query: Record<string, string>) {
    return this.tools.listCustomers(request.admin!, query);
  }

  @Get("products/options")
  @RequireAnyAdminPermission("customers.view", "products.view", "marketing.sms.view", "marketing.rubika.view")
  productOptions(@Req() request: AdminRequest) {
    return this.tools.productOptions(request.admin!);
  }

  @Get("coupons")
  @RequireAdminPermission("marketing.campaign.manage")
  coupons(@Req() request: AdminRequest) {
    return this.tools.listCoupons(request.admin!);
  }

  @Post("coupons")
  @RequireAdminPermission("marketing.campaign.manage")
  createCoupon(@Req() request: AdminRequest, @Body() body: Record<string, unknown>) {
    return this.tools.saveCoupon(request.admin!, null, body);
  }

  @Patch("coupons/:id")
  @RequireAdminPermission("marketing.campaign.manage")
  updateCoupon(@Req() request: AdminRequest, @Param("id") id: string, @Body() body: Record<string, unknown>) {
    return this.tools.saveCoupon(request.admin!, id, body);
  }

  @Post("sms-campaigns/preview")
  @RequireAnyAdminPermission("marketing.sms.view", "marketing.sms.send")
  previewSms(@Req() request: AdminRequest, @Body() body: Record<string, unknown>) {
    return this.tools.previewSmsAudience(request.admin!, body.filters);
  }

  @Get("sms-campaigns")
  @RequireAnyAdminPermission("marketing.sms.view", "marketing.sms.send")
  smsCampaigns(@Req() request: AdminRequest) {
    return this.tools.listSmsCampaigns(request.admin!);
  }

  @Post("sms-campaigns")
  @RequireAdminPermission("marketing.sms.send")
  createSms(@Req() request: AdminRequest, @Body() body: Record<string, unknown>) {
    return this.tools.createSmsCampaign(request.admin!, body);
  }

  @Post("sms-campaigns/:id/send")
  @RequireAdminPermission("marketing.sms.send")
  sendSms(@Req() request: AdminRequest, @Param("id") id: string) {
    return this.tools.sendSmsCampaign(request.admin!, id);
  }

  @Post("rubika-campaigns/preview")
  @RequireAnyAdminPermission("marketing.rubika.view", "marketing.rubika.publish")
  previewRubika(@Req() request: AdminRequest, @Body() body: Record<string, unknown>) {
    return this.tools.previewRubikaAudience(request.admin!, body.filters);
  }

  @Get("rubika-campaigns")
  @RequireAnyAdminPermission("marketing.rubika.view", "marketing.rubika.publish")
  rubikaCampaigns(@Req() request: AdminRequest) {
    return this.tools.listRubikaCampaigns(request.admin!);
  }

  @Post("rubika-campaigns")
  @RequireAdminPermission("marketing.rubika.publish")
  createRubika(@Req() request: AdminRequest, @Body() body: Record<string, unknown>) {
    return this.tools.createRubikaCampaign(request.admin!, body);
  }

  @Post("rubika-campaigns/:id/send")
  @RequireAdminPermission("marketing.rubika.publish")
  sendRubika(@Req() request: AdminRequest, @Param("id") id: string) {
    return this.tools.sendRubikaCampaign(request.admin!, id);
  }

  @Get("social/status")
  @RequireAnyAdminPermission("marketing.rubika.view", "marketing.rubika.publish")
  socialStatus(@Req() request: AdminRequest) {
    return this.tools.socialStatus(request.admin!);
  }

  @Get("social/products")
  @RequireAnyAdminPermission("marketing.rubika.view", "marketing.rubika.publish")
  socialProducts(@Req() request: AdminRequest) {
    return this.tools.socialProducts(request.admin!);
  }

  @Get("social/posts")
  @RequireAnyAdminPermission("marketing.rubika.view", "marketing.rubika.publish")
  socialPosts(@Req() request: AdminRequest) {
    return this.tools.listSocialPosts(request.admin!);
  }

  @Post("social/posts")
  @RequireAdminPermission("marketing.rubika.publish")
  createSocialPost(@Req() request: AdminRequest, @Body() body: Record<string, unknown>) {
    return this.tools.createSocialPost(request.admin!, body);
  }

  @Post("social/posts/:id/approve")
  @RequireAdminPermission("marketing.rubika.publish")
  approveSocialPost(@Req() request: AdminRequest, @Param("id") id: string) {
    return this.tools.approveSocialPost(request.admin!, id);
  }

  @Post("social/posts/:id/send-now")
  @RequireAdminPermission("marketing.rubika.publish")
  sendSocialPostNow(@Req() request: AdminRequest, @Param("id") id: string) {
    return this.tools.sendSocialPostNow(request.admin!, id);
  }

  @Post("social/posts/:id/cancel")
  @RequireAdminPermission("marketing.rubika.publish")
  cancelSocialPost(@Req() request: AdminRequest, @Param("id") id: string) {
    return this.tools.cancelSocialPost(request.admin!, id);
  }

  @Get("operations/status")
  @RequireAdminPermission("system.monitor")
  operationsStatus(@Req() request: AdminRequest) {
    return this.tools.operationsStatus(request.admin!);
  }

  @Get("operations/backups")
  @RequireAdminPermission("system.backup")
  backups(@Req() request: AdminRequest) {
    return this.tools.listBackups(request.admin!);
  }

  @Post("operations/backups")
  @RequireAdminPermission("system.backup")
  createBackup(@Req() request: AdminRequest) {
    return this.tools.createBackup(request.admin!);
  }
}
