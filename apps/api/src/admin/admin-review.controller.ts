import { Body, Controller, Get, Param, Patch, Query, Req, UseGuards } from "@nestjs/common";
import { ApiBearerAuth, ApiOperation, ApiTags } from "@nestjs/swagger";
import { AdminPermissionGuard, RequireAdminPermission } from "../admin-auth/admin-permission.guard";
import { AdminRequest, AdminSessionGuard } from "../admin-auth/admin-session.guard";
import { AdminReviewService } from "./admin-review.service";
import { UpdateAdminReviewStatusDto } from "./dto/update-admin-review-status.dto";

@ApiTags("مدیریت نظرهای محصولات")
@ApiBearerAuth("admin-session")
@UseGuards(AdminSessionGuard, AdminPermissionGuard)
@Controller("admin/reviews")
export class AdminReviewController {
  constructor(private readonly reviews: AdminReviewService) {}

  @Get()
  @ApiOperation({ summary: "فهرست نظرهای محصول برای مدیریت" })
  @RequireAdminPermission("products.view")
  list(@Query("status") status: string | undefined) {
    return this.reviews.list(status);
  }

  @Patch(":id/status")
  @ApiOperation({ summary: "تأیید، رد یا بازگرداندن نظر به صف بررسی" })
  @RequireAdminPermission("products.edit")
  updateStatus(@Req() request: AdminRequest, @Param("id") id: string, @Body() body: UpdateAdminReviewStatusDto) {
    return this.reviews.updateStatus(request.admin!, id, body.status);
  }
}
