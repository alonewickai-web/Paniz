import { Body, Controller, Delete, Get, Param, Patch, Post, Req, UseGuards } from "@nestjs/common";
import { ApiBearerAuth, ApiBody, ApiOperation, ApiTags } from "@nestjs/swagger";
import { AdminRequest, AdminSessionGuard } from "../admin-auth/admin-session.guard";
import { StoreManagementService } from "./store-management.service";
import { SaveAdminBannerDto } from "./dto/save-admin-banner.dto";
import { SaveAdminCategoryDto } from "./dto/save-admin-category.dto";
import { ReorderHomepageSectionsDto } from "./dto/reorder-homepage-sections.dto";
import { UpdateHomepageSectionDto } from "./dto/update-homepage-section.dto";
import { UpdateStoreThemeDto } from "./dto/update-store-theme.dto";

@ApiTags("مدیریت محتوای فروشگاه")
@ApiBearerAuth("admin-session")
@UseGuards(AdminSessionGuard)
@Controller("admin")
export class StoreManagementController {
  constructor(private readonly store: StoreManagementService) {}

  @Get("store")
  @ApiOperation({ summary: "تنظیمات فروشگاه، دسته‌بندی‌ها، بنرها و چیدمان خانه" })
  configuration() {
    return this.store.adminConfiguration();
  }

  @Patch("store/theme")
  @ApiOperation({ summary: "تغییر رنگ‌بندی فعال ویترین" })
  @ApiBody({ type: UpdateStoreThemeDto })
  updateTheme(@Req() request: AdminRequest, @Body() body: UpdateStoreThemeDto) {
    return this.store.saveTheme(request.admin!, body);
  }

  @Patch("homepage-sections/reorder")
  @ApiOperation({ summary: "ذخیرهٔ ترتیب همهٔ بخش‌های صفحهٔ اصلی" })
  @ApiBody({ type: ReorderHomepageSectionsDto })
  reorderSections(@Req() request: AdminRequest, @Body() body: ReorderHomepageSectionsDto) {
    return this.store.reorderHomepageSections(request.admin!, body);
  }

  @Patch("homepage-sections/:sectionKey")
  @ApiOperation({ summary: "فعال‌سازی، عنوان یا ترتیب یک بخش صفحهٔ اصلی" })
  @ApiBody({ type: UpdateHomepageSectionDto })
  updateSection(@Req() request: AdminRequest, @Param("sectionKey") key: string, @Body() body: UpdateHomepageSectionDto) {
    return this.store.updateHomepageSection(request.admin!, key, body);
  }

  @Post("categories")
  @ApiOperation({ summary: "ساخت دسته‌بندی اصلی یا زیردسته" })
  @ApiBody({ type: SaveAdminCategoryDto })
  createCategory(@Req() request: AdminRequest, @Body() body: SaveAdminCategoryDto) {
    return this.store.createCategory(request.admin!, body);
  }

  @Patch("categories/:id")
  @ApiOperation({ summary: "ویرایش دسته‌بندی و وضعیت انتشار آن" })
  @ApiBody({ type: SaveAdminCategoryDto })
  updateCategory(@Req() request: AdminRequest, @Param("id") id: string, @Body() body: SaveAdminCategoryDto) {
    return this.store.updateCategory(request.admin!, id, body);
  }

  @Delete("categories/:id")
  @ApiOperation({ summary: "بایگانی دسته‌بندی بدون حذف سوابق فروش" })
  archiveCategory(@Req() request: AdminRequest, @Param("id") id: string) {
    return this.store.archiveCategory(request.admin!, id);
  }

  @Post("banners")
  @ApiOperation({ summary: "ثبت بنر با بازهٔ زمانی اختیاری" })
  @ApiBody({ type: SaveAdminBannerDto })
  createBanner(@Req() request: AdminRequest, @Body() body: SaveAdminBannerDto) {
    return this.store.createBanner(request.admin!, body);
  }

  @Patch("banners/:id")
  @ApiOperation({ summary: "ویرایش، زمان‌بندی یا فعال‌سازی بنر" })
  @ApiBody({ type: SaveAdminBannerDto })
  updateBanner(@Req() request: AdminRequest, @Param("id") id: string, @Body() body: SaveAdminBannerDto) {
    return this.store.updateBanner(request.admin!, id, body);
  }

  @Post("banners/:id/restore")
  @ApiOperation({ summary: "بازگردانی بنر بایگانی‌شده به سایت" })
  restoreBanner(@Req() request: AdminRequest, @Param("id") id: string) {
    return this.store.restoreBanner(request.admin!, id);
  }

  @Delete("banners/:id")
  @ApiOperation({ summary: "برداشتن بنر از سایت و انتقال آن به آرشیو" })
  deleteBanner(@Req() request: AdminRequest, @Param("id") id: string) {
    return this.store.deleteBanner(request.admin!, id);
  }
}
