import { hasAdminPermission, requireAdminPermission } from "../admin-auth/admin-permissions";
import { BadRequestException, ConflictException, ForbiddenException, Injectable, NotFoundException } from "@nestjs/common";
import { Prisma } from "@prisma/client";
import { AuthenticatedAdmin } from "../admin-auth/admin-session.guard";
import { PrismaService } from "../database/prisma.service";
import { SaveAdminBannerDto } from "./dto/save-admin-banner.dto";
import { SaveAdminCategoryDto } from "./dto/save-admin-category.dto";
import { ReorderHomepageSectionsDto } from "./dto/reorder-homepage-sections.dto";
import { UpdateHomepageSectionDto } from "./dto/update-homepage-section.dto";
import { STORE_THEMES, UpdateStoreThemeDto } from "./dto/update-store-theme.dto";
import { SaveShippingSettingsDto } from "./dto/save-shipping-settings.dto";
import { UpdateStoreAboutDto } from "./dto/update-store-about.dto";
import { UpdateStorePopupDto } from "./dto/update-store-popup.dto";

const defaultSections = [
  { sectionKey: "hero", title: "بنر اصلی", isActive: true, sortOrder: 0 },
  { sectionKey: "categories", title: "دسته‌بندی‌ها", isActive: true, sortOrder: 1 },
  { sectionKey: "products", title: "محصولات", isActive: true, sortOrder: 2 },
  { sectionKey: "benefits", title: "خدمات فروشگاه", isActive: true, sortOrder: 3 },
] as const;

type StoreTheme = (typeof STORE_THEMES)[number];
type CategoryWriteData = {
  name?: string;
  slug?: string;
  description?: string | null;
  imagePath?: string | null;
  sortOrder?: number;
  isActive?: boolean;
};
type BannerWriteData = {
  title?: string;
  altText?: string;
  description?: string | null;
  imagePath?: string;
  targetUrl?: string | null;
  eyebrowText?: string | null;
  buttonLabel?: string | null;
  buttonSideText?: string | null;
  stickerLabel?: string | null;
  stickerText?: string | null;
  backgroundColor?: string | null;
  startsAt?: Date | null;
  endsAt?: Date | null;
  sortOrder?: number;
  isActive?: boolean;
};

@Injectable()
export class StoreManagementService {
  constructor(private readonly prisma: PrismaService) {}

  async publicConfig() {
    const now = new Date();
    const [themeSetting, logoSetting, aboutSetting, popupSetting, savedSections, banners, shipping] = await Promise.all([
      this.prisma.storeSetting.findUnique({ where: { settingKey: "store.theme" }, select: { settingValue: true } }),
      this.prisma.storeSetting.findUnique({ where: { settingKey: "store.logoPath" }, select: { settingValue: true } }),
      this.prisma.storeSetting.findUnique({ where: { settingKey: "store.about" }, select: { settingValue: true } }),
      this.prisma.storeSetting.findUnique({ where: { settingKey: "store.popup" }, select: { settingValue: true, updatedAt: true } }),
      this.prisma.homepageSection.findMany({ orderBy: [{ sortOrder: "asc" }, { id: "asc" }] }),
      this.prisma.banner.findMany({
        where: {
          isActive: true,
          archivedAt: null,
          AND: [
            { OR: [{ startsAt: null }, { startsAt: { lte: now } }] },
            { OR: [{ endsAt: null }, { endsAt: { gt: now } }] },
          ],
        },
        orderBy: [{ sortOrder: "asc" }, { id: "asc" }],
        select: {
          id: true,
          title: true,
          altText: true,
          imagePath: true,
          backgroundColor: true,
        },
      }),
      this.prisma.shippingMethod.findFirst({ where: { isActive: true }, orderBy: [{ sortOrder: "asc" }, { id: "asc" }], select: { name: true, description: true, estimatedDaysMin: true, estimatedDaysMax: true, baseCostToman: true, freeOverToman: true } }),
    ]);

    return {
      data: {
        theme: safeTheme(themeSetting?.settingValue),
        logoPath: logoSetting?.settingValue || null,
        about: safeStoreAbout(aboutSetting?.settingValue),
        popup: safeStorePopup(popupSetting?.settingValue, popupSetting?.updatedAt),
        sections: mergeSections(savedSections),
        banners: banners.map((banner) => ({
          id: banner.id.toString(),
          altText: banner.altText?.trim() || banner.title,
          imagePath: banner.imagePath,
          backgroundColor: banner.backgroundColor,
        })),
        shipping: shipping ? { name: shipping.name, description: shipping.description, estimatedDaysMin: shipping.estimatedDaysMin, estimatedDaysMax: shipping.estimatedDaysMax, baseCostToman: safeNumber(shipping.baseCostToman), freeOverToman: shipping.freeOverToman === null ? null : safeNumber(shipping.freeOverToman) } : null,
      },
    };
  }

  async adminConfiguration() {
    const [themeSetting, logoSetting, aboutSetting, popupSetting, sections, categories, banners, shipping] = await Promise.all([
      this.prisma.storeSetting.findUnique({ where: { settingKey: "store.theme" }, select: { settingValue: true } }),
      this.prisma.storeSetting.findUnique({ where: { settingKey: "store.logoPath" }, select: { settingValue: true } }),
      this.prisma.storeSetting.findUnique({ where: { settingKey: "store.about" }, select: { settingValue: true } }),
      this.prisma.storeSetting.findUnique({ where: { settingKey: "store.popup" }, select: { settingValue: true, updatedAt: true } }),
      this.prisma.homepageSection.findMany({ orderBy: [{ sortOrder: "asc" }, { id: "asc" }] }),
      this.prisma.category.findMany({ orderBy: [{ parentId: "asc" }, { sortOrder: "asc" }, { name: "asc" }] }),
      this.prisma.banner.findMany({ orderBy: [{ sortOrder: "asc" }, { id: "asc" }] }),
      this.prisma.shippingMethod.findFirst({ orderBy: [{ sortOrder: "asc" }, { id: "asc" }] }),
    ]);
    return {
      data: {
        theme: safeTheme(themeSetting?.settingValue),
        logoPath: logoSetting?.settingValue || null,
        about: safeStoreAbout(aboutSetting?.settingValue),
        popup: safeStorePopup(popupSetting?.settingValue, popupSetting?.updatedAt),
        sections: mergeSections(sections),
        categories: categories.map((category) => ({ ...category, id: category.id.toString(), parentId: category.parentId?.toString() ?? null })),
        banners: banners.map((banner) => ({ ...banner, id: banner.id.toString(), altText: banner.altText?.trim() || banner.title, isArchived: banner.archivedAt !== null })),
        shipping: shipping ? { id: shipping.id.toString(), name: shipping.name, description: shipping.description, estimatedDaysMin: shipping.estimatedDaysMin, estimatedDaysMax: shipping.estimatedDaysMax, baseCostToman: safeNumber(shipping.baseCostToman), freeOverToman: shipping.freeOverToman === null ? null : safeNumber(shipping.freeOverToman), isActive: shipping.isActive } : null,
      },
    };
  }

  async saveShippingSettings(admin: AuthenticatedAdmin, input: SaveShippingSettingsDto) {
    requireAdminPermission(admin, "store.content");
    if (input.freeShippingEnabled && !input.alwaysFree && !input.freeOverToman) throw new BadRequestException({ code: "FREE_SHIPPING_THRESHOLD_REQUIRED", message: "حد خرید برای ارسال رایگان را وارد کن." });
    const baseCostToman = input.alwaysFree ? 0n : BigInt(input.baseCostToman);
    const freeOverToman = input.freeShippingEnabled && !input.alwaysFree ? BigInt(input.freeOverToman!) : null;
    const result = await this.prisma.$transaction(async (tx) => {
      const current = await tx.shippingMethod.findFirst({ orderBy: [{ sortOrder: "asc" }, { id: "asc" }] });
      const estimatedDaysMin = input.estimatedDaysMin === undefined ? current?.estimatedDaysMin ?? null : input.estimatedDaysMin;
      const estimatedDaysMax = input.estimatedDaysMax === undefined ? current?.estimatedDaysMax ?? null : input.estimatedDaysMax;
      if (estimatedDaysMin !== null && estimatedDaysMax !== null && estimatedDaysMax < estimatedDaysMin) {
        throw new BadRequestException({ code: "INVALID_SHIPPING_ESTIMATE", message: "حداکثر زمان ارسال نباید از حداقل آن کمتر باشد." });
      }
      const data = {
        name: input.name.trim() || current?.name || "ارسال پستی",
        description: input.description === undefined ? current?.description ?? null : input.description?.trim() || null,
        estimatedDaysMin,
        estimatedDaysMax,
        baseCostToman,
        freeOverToman,
        isActive: true,
        sortOrder: 0,
      };
      const saved = current
        ? await tx.shippingMethod.update({ where: { id: current.id }, data })
        : await tx.shippingMethod.create({ data });
      await tx.adminAuditLog.create({ data: { adminId: admin.id, action: "shipping.settings.updated", entityType: "shipping_method", entityId: saved.id, details: { baseCostToman: baseCostToman.toString(), freeOverToman: input.freeShippingEnabled && !input.alwaysFree ? input.freeOverToman : null, alwaysFree: input.alwaysFree } } });
      return saved;
    });
    return { data: { id: result.id.toString(), name: result.name, description: result.description, estimatedDaysMin: result.estimatedDaysMin, estimatedDaysMax: result.estimatedDaysMax, baseCostToman: safeNumber(result.baseCostToman), freeOverToman: result.freeOverToman === null ? null : safeNumber(result.freeOverToman), alwaysFree: result.baseCostToman === 0n, isActive: result.isActive } };
  }

  async saveLogo(admin: AuthenticatedAdmin, input: { logoPath?: string | null }) {
    requireAdminPermission(admin, "store.content");
    const logoPath = input.logoPath?.trim() || null;
    await this.prisma.$transaction(async (tx) => {
      await tx.storeSetting.upsert({
        where: { settingKey: "store.logoPath" },
        create: { settingKey: "store.logoPath", settingValue: logoPath ?? "" },
        update: { settingValue: logoPath ?? "" },
      });
      await tx.adminAuditLog.create({ data: { adminId: admin.id, action: "store.logo.updated", entityType: "store_setting", details: { logoPath } } });
    });
    return { data: { logoPath } };
  }

  async savePopup(admin: AuthenticatedAdmin, input: UpdateStorePopupDto) {
    requireAdminPermission(admin, "store.content");
    const imagePath = input.imagePath?.trim() || null;
    const linkUrl = input.linkUrl?.trim() || null;
    if (input.enabled && !imagePath) {
      throw new BadRequestException({ code: "STORE_POPUP_IMAGE_REQUIRED", message: "برای نمایش پاپ‌آپ، تصویر انتخاب کن." });
    }
    if (imagePath && !/^\/uploads\/products\/[A-Za-z0-9_-]+\.(?:jpe?g|png|webp)$/i.test(imagePath)) {
      throw new BadRequestException({ code: "INVALID_STORE_POPUP_IMAGE", message: "تصویر پاپ‌آپ باید از گالری برنامه بارگذاری شود." });
    }
    if (linkUrl && !allowedPath(linkUrl)) {
      throw new BadRequestException({ code: "INVALID_STORE_POPUP_LINK", message: "پیوند مقصد باید نشانی HTTPS یا مسیر داخلی سایت باشد." });
    }
    const popup = { enabled: input.enabled, imagePath, linkUrl };
    const updatedAt = await this.prisma.$transaction(async (tx) => {
      const saved = await tx.storeSetting.upsert({
        where: { settingKey: "store.popup" },
        create: { settingKey: "store.popup", settingValue: popup, isPublic: true, updatedByAdminId: admin.id },
        update: { settingValue: popup, isPublic: true, updatedByAdminId: admin.id },
        select: { updatedAt: true },
      });
      await tx.adminAuditLog.create({
        data: { adminId: admin.id, action: "store.popup.updated", entityType: "store_setting", details: popup },
      });
      return saved.updatedAt;
    });
    return { data: { popup: { ...popup, updatedAt: updatedAt.toISOString() } } };
  }

  async saveAboutInfo(admin: AuthenticatedAdmin, input: UpdateStoreAboutDto) {
    requireAdminPermission(admin, "store.content");
    const about = await this.prisma.$transaction(async (tx) => {
      const current = await tx.storeSetting.findUnique({ where: { settingKey: "store.about" }, select: { settingValue: true } });
      const previousAbout = safeStoreAbout(current?.settingValue);
      const about = {
        introTitle: input.introTitle?.trim() ?? previousAbout.introTitle,
        introDescription: input.introDescription?.trim() ?? previousAbout.introDescription,
        address: input.address.trim(),
        phone: input.phone.trim(),
        rubikaUrl: input.rubikaUrl.trim(),
        instagramUrl: input.instagramUrl.trim(),
        physicalAddress: input.physicalAddress.trim(),
        mapUrl: input.mapUrl.trim(),
        latitude: typeof input.latitude === "number" && Number.isFinite(input.latitude) ? input.latitude : null,
        longitude: typeof input.longitude === "number" && Number.isFinite(input.longitude) ? input.longitude : null,
      };
      await tx.storeSetting.upsert({
        where: { settingKey: "store.about" },
        create: { settingKey: "store.about", settingValue: about, isPublic: true, updatedByAdminId: admin.id },
        update: { settingValue: about, isPublic: true, updatedByAdminId: admin.id },
      });
      await tx.adminAuditLog.create({
        data: { adminId: admin.id, action: "store.about.updated", entityType: "store_setting", details: { fields: Object.keys(about) } },
      });
      return about;
    });
    return { data: { about } };
  }

  async saveTheme(admin: AuthenticatedAdmin, input: UpdateStoreThemeDto) {
    requireAdminPermission(admin, "store.content");
    await this.prisma.$transaction(async (tx) => {
      await tx.storeSetting.upsert({
        where: { settingKey: "store.theme" },
        create: { settingKey: "store.theme", settingValue: input.theme, isPublic: true, updatedByAdminId: admin.id },
        update: { settingValue: input.theme, isPublic: true, updatedByAdminId: admin.id },
      });
      await tx.adminAuditLog.create({
        data: { adminId: admin.id, action: "store.theme.updated", entityType: "store_setting", details: { theme: input.theme } },
      });
    });
    return { data: { theme: input.theme } };
  }

  async updateHomepageSection(admin: AuthenticatedAdmin, sectionKey: string, input: UpdateHomepageSectionDto) {
    requireAdminPermission(admin, "store.content");
    if (!defaultSections.some((section) => section.sectionKey === sectionKey)) {
      throw new NotFoundException({ code: "HOMEPAGE_SECTION_NOT_FOUND", message: "بخش صفحهٔ اصلی پیدا نشد" });
    }
    if (Object.keys(input).length === 0) throw new BadRequestException({ code: "EMPTY_SECTION_UPDATE", message: "تغییری برای ذخیره انتخاب نشده است" });
    const fallback = defaultSections.find((section) => section.sectionKey === sectionKey)!;
    const changed = await this.prisma.$transaction(async (tx) => {
      const row = await tx.homepageSection.upsert({
        where: { sectionKey },
        create: {
          sectionKey,
          title: input.title === undefined ? fallback.title : input.title,
          isActive: input.isActive ?? fallback.isActive,
          sortOrder: input.sortOrder ?? fallback.sortOrder,
          updatedByAdminId: admin.id,
        },
        update: { ...input, updatedByAdminId: admin.id },
      });
      await tx.adminAuditLog.create({
        data: {
          adminId: admin.id,
          action: "homepage_section.updated",
          entityType: "homepage_section",
          entityId: row.id,
          details: { sectionKey, isActive: row.isActive, sortOrder: row.sortOrder, title: row.title },
        },
      });
      return row;
    });
    return { data: { ...changed, id: changed.id.toString() } };
  }

  async reorderHomepageSections(admin: AuthenticatedAdmin, input: ReorderHomepageSectionsDto) {
    requireAdminPermission(admin, "store.content");
    const allowedKeys = defaultSections.map((section) => section.sectionKey);
    if (input.sectionKeys.length !== allowedKeys.length || input.sectionKeys.some((key) => !allowedKeys.includes(key as typeof allowedKeys[number]))) {
      throw new BadRequestException({ code: "INVALID_HOMEPAGE_SECTION_ORDER", message: "ترتیب ارسالی بخش‌های صفحهٔ اصلی معتبر نیست" });
    }

    await this.prisma.$transaction(async (tx) => {
      for (const [sortOrder, sectionKey] of input.sectionKeys.entries()) {
        const fallback = defaultSections.find((section) => section.sectionKey === sectionKey)!;
        await tx.homepageSection.upsert({
          where: { sectionKey },
          create: { ...fallback, updatedByAdminId: admin.id },
          update: { sortOrder, updatedByAdminId: admin.id },
        });
      }
      await tx.adminAuditLog.create({
        data: {
          adminId: admin.id,
          action: "homepage_sections.reordered",
          entityType: "homepage_section",
          details: { sectionKeys: input.sectionKeys },
        },
      });
    });

    return { data: { sectionKeys: input.sectionKeys } };
  }

  async createCategory(admin: AuthenticatedAdmin, input: SaveAdminCategoryDto) {
    requireAdminPermission(admin, "store.content");
    const values = this.categoryValues(input, true);
    const parentId = await this.validateParent(input.parentId);
    try {
      const category = await this.prisma.$transaction(async (tx) => {
        const slug = values.slug ?? await this.uniqueCategorySlug(tx, values.name!);
        const created = await tx.category.create({ data: { ...values, slug, parentId } as Prisma.CategoryUncheckedCreateInput });
        await tx.adminAuditLog.create({
          data: { adminId: admin.id, action: "category.created", entityType: "category", entityId: created.id, details: { name: created.name, slug: created.slug } },
        });
        return created;
      });
      return { data: { ...category, id: category.id.toString(), parentId: category.parentId?.toString() ?? null } };
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === "P2002") {
        throw new ConflictException({ code: "CATEGORY_SLUG_EXISTS", message: "این نشانی دسته‌بندی قبلاً استفاده شده است" });
      }
      throw error;
    }
  }

  async updateCategory(admin: AuthenticatedAdmin, rawId: string, input: SaveAdminCategoryDto) {
    requireAdminPermission(admin, "store.content");
    const id = parseId(rawId, "شناسهٔ دسته‌بندی");
    if (Object.keys(input).length === 0) throw new BadRequestException({ code: "EMPTY_CATEGORY_UPDATE", message: "تغییری برای ذخیره انتخاب نشده است" });
    const current = await this.prisma.category.findUnique({ where: { id } });
    if (!current) throw new NotFoundException({ code: "CATEGORY_NOT_FOUND", message: "دسته‌بندی پیدا نشد" });
    const values = this.categoryValues(input, false);
    const parentId = input.parentId === undefined ? current.parentId : await this.validateParent(input.parentId, id);
    if (input.parentId !== undefined && parentId !== null && await this.prisma.category.count({ where: { parentId: id } }) > 0) {
      throw new BadRequestException({ code: "CATEGORY_DEPTH_LIMIT", message: "دسته‌ای که زیردسته دارد نمی‌تواند زیرمجموعه شود" });
    }
    const data: Prisma.CategoryUncheckedUpdateInput = { ...values };
    if (input.parentId !== undefined) data.parentId = parentId;
    try {
      const category = await this.prisma.$transaction(async (tx) => {
        const changed = await tx.category.update({ where: { id }, data });
        await tx.adminAuditLog.create({
          data: { adminId: admin.id, action: "category.updated", entityType: "category", entityId: id, details: { name: changed.name, slug: changed.slug, isActive: changed.isActive } },
        });
        return changed;
      });
      return { data: { ...category, id: category.id.toString(), parentId: category.parentId?.toString() ?? null } };
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === "P2002") {
        throw new ConflictException({ code: "CATEGORY_SLUG_EXISTS", message: "این نشانی دسته‌بندی قبلاً استفاده شده است" });
      }
      throw error;
    }
  }

  async archiveCategory(admin: AuthenticatedAdmin, rawId: string) {
    requireAdminPermission(admin, "store.content");
    const id = parseId(rawId, "شناسهٔ دسته‌بندی");
    const current = await this.prisma.category.findUnique({ where: { id } });
    if (!current) throw new NotFoundException({ code: "CATEGORY_NOT_FOUND", message: "دسته‌بندی پیدا نشد" });
    await this.prisma.$transaction(async (tx) => {
      await tx.category.update({ where: { id }, data: { isActive: false } });
      await tx.adminAuditLog.create({
        data: { adminId: admin.id, action: "category.archived", entityType: "category", entityId: id, details: { slug: current.slug } },
      });
    });
    return { data: { id: id.toString(), archived: true } };
  }

  async createBanner(admin: AuthenticatedAdmin, input: SaveAdminBannerDto) {
    requireAdminPermission(admin, "store.content");
    const values = this.bannerValues(input, true);
    const banner = await this.prisma.$transaction(async (tx) => {
      const created = await tx.banner.create({ data: values as Prisma.BannerUncheckedCreateInput });
      await tx.adminAuditLog.create({
        data: { adminId: admin.id, action: "banner.created", entityType: "banner", entityId: created.id, details: { title: created.title } },
      });
      return created;
    });
    return { data: { ...banner, id: banner.id.toString() } };
  }

  async updateBanner(admin: AuthenticatedAdmin, rawId: string, input: SaveAdminBannerDto) {
    requireAdminPermission(admin, "store.content");
    const id = parseId(rawId, "شناسهٔ بنر");
    if (Object.keys(input).length === 0) throw new BadRequestException({ code: "EMPTY_BANNER_UPDATE", message: "تغییری برای ذخیره انتخاب نشده است" });
    const values = this.bannerValues(input, false);
    const current = await this.prisma.banner.findUnique({ where: { id } });
    if (!current) throw new NotFoundException({ code: "BANNER_NOT_FOUND", message: "بنر پیدا نشد" });
    const startsAt = values.startsAt === undefined ? current.startsAt : values.startsAt;
    const endsAt = values.endsAt === undefined ? current.endsAt : values.endsAt;
    validateWindow(startsAt, endsAt);
    const banner = await this.prisma.$transaction(async (tx) => {
      const changed = await tx.banner.update({ where: { id }, data: values as Prisma.BannerUncheckedUpdateInput });
      await tx.adminAuditLog.create({
        data: { adminId: admin.id, action: "banner.updated", entityType: "banner", entityId: id, details: { title: changed.title, isActive: changed.isActive } },
      });
      return changed;
    });
    return { data: { ...banner, id: banner.id.toString() } };
  }

  async deleteBanner(admin: AuthenticatedAdmin, rawId: string) {
    requireAdminPermission(admin, "store.content");
    const id = parseId(rawId, "شناسهٔ بنر");
    const current = await this.prisma.banner.findUnique({ where: { id } });
    if (!current) throw new NotFoundException({ code: "BANNER_NOT_FOUND", message: "بنر پیدا نشد" });
    if (current.archivedAt) return { data: { id: id.toString(), archived: true } };
    const archivedAt = new Date();
    await this.prisma.$transaction(async (tx) => {
      await tx.banner.update({ where: { id }, data: { archivedAt, isActive: false } });
      await tx.adminAuditLog.create({
        data: { adminId: admin.id, action: "banner.archived", entityType: "banner", entityId: id, details: { title: current.title } },
      });
    });
    return { data: { id: id.toString(), archived: true } };
  }

  async restoreBanner(admin: AuthenticatedAdmin, rawId: string) {
    requireAdminPermission(admin, "store.content");
    const id = parseId(rawId, "شناسهٔ بنر");
    const current = await this.prisma.banner.findUnique({ where: { id } });
    if (!current) throw new NotFoundException({ code: "BANNER_NOT_FOUND", message: "بنر پیدا نشد" });
    if (!current.archivedAt) return { data: { id: id.toString(), archived: false, isActive: current.isActive } };

    await this.prisma.$transaction(async (tx) => {
      await tx.banner.update({ where: { id }, data: { archivedAt: null, isActive: true } });
      await tx.adminAuditLog.create({
        data: { adminId: admin.id, action: "banner.restored", entityType: "banner", entityId: id, details: { title: current.title } },
      });
    });
    return { data: { id: id.toString(), archived: false, isActive: true } };
  }

  private categoryValues(input: SaveAdminCategoryDto, create: boolean): CategoryWriteData {
    if (create && !input.name?.trim()) {
      throw new BadRequestException({ code: "CATEGORY_NAME_REQUIRED", message: "نام دسته‌بندی را وارد کن" });
    }
    if (input.name !== undefined && !input.name.trim()) throw new BadRequestException({ code: "CATEGORY_NAME_REQUIRED", message: "نام دسته‌بندی را وارد کن" });
    if (input.slug !== undefined && !input.slug.trim()) throw new BadRequestException({ code: "CATEGORY_SLUG_REQUIRED", message: "نشانی دسته‌بندی را وارد کن" });
    if (input.imagePath !== undefined && input.imagePath !== null && input.imagePath.trim() && !allowedPath(input.imagePath)) {
      throw new BadRequestException({ code: "INVALID_CATEGORY_IMAGE", message: "تصویر باید مسیر داخلی سایت یا نشانی HTTPS باشد" });
    }
    return {
      ...(input.name !== undefined ? { name: input.name.trim() } : {}),
      ...(input.slug !== undefined ? { slug: input.slug.trim().toLowerCase() } : {}),
      ...(input.description !== undefined ? { description: input.description?.trim() || null } : {}),
      ...(input.imagePath !== undefined ? { imagePath: input.imagePath?.trim() || null } : {}),
      ...(input.sortOrder !== undefined ? { sortOrder: input.sortOrder } : {}),
      ...(input.isActive !== undefined ? { isActive: input.isActive } : {}),
    };
  }

  private async uniqueCategorySlug(tx: Prisma.TransactionClient, name: string): Promise<string> {
    const base = persianSlug(name) || "category";
    let slug = base;
    let suffix = 2;
    while (await tx.category.findUnique({ where: { slug }, select: { id: true } })) {
      slug = `${base}-${suffix++}`;
    }
    return slug;
  }

  private async validateParent(rawParentId?: string | null, currentId?: bigint): Promise<bigint | null> {
    if (rawParentId === undefined || rawParentId === null || rawParentId === "") return null;
    const parentId = parseId(rawParentId, "دسته‌بندی مادر");
    if (parentId === currentId) throw new BadRequestException({ code: "CATEGORY_PARENT_CYCLE", message: "یک دسته نمی‌تواند زیرمجموعهٔ خودش باشد" });
    const parent = await this.prisma.category.findUnique({ where: { id: parentId }, select: { id: true, parentId: true, isActive: true } });
    if (!parent || !parent.isActive) throw new NotFoundException({ code: "CATEGORY_PARENT_NOT_FOUND", message: "دسته‌بندی مادر فعال پیدا نشد" });
    if (parent.parentId !== null) throw new BadRequestException({ code: "CATEGORY_DEPTH_LIMIT", message: "دسته‌بندی‌ها حداکثر دو سطح دارند" });
    return parentId;
  }

  private bannerValues(input: SaveAdminBannerDto, create: boolean): BannerWriteData {
    const altText = input.altText?.trim() || input.title?.trim();
    if (create && (!altText || !input.imagePath?.trim())) {
      throw new BadRequestException({ code: "BANNER_FIELDS_REQUIRED", message: "متن جایگزین و تصویر بنر الزامی است" });
    }
    if (input.altText !== undefined && !input.altText.trim()) throw new BadRequestException({ code: "BANNER_ALT_REQUIRED", message: "متن جایگزین تصویر را وارد کن" });
    if (input.title !== undefined && !input.title.trim()) throw new BadRequestException({ code: "BANNER_TITLE_REQUIRED", message: "عنوان بنر را وارد کن" });
    if (input.imagePath !== undefined && !allowedPath(input.imagePath)) {
      throw new BadRequestException({ code: "INVALID_BANNER_IMAGE", message: "تصویر باید مسیر داخلی سایت یا نشانی HTTPS باشد" });
    }
    if (input.targetUrl !== undefined && input.targetUrl !== null && input.targetUrl.trim() && !allowedPath(input.targetUrl)) {
      throw new BadRequestException({ code: "INVALID_BANNER_TARGET", message: "پیوند مقصد باید مسیر داخلی سایت یا نشانی HTTPS باشد" });
    }
    const startsAt = input.startsAt === undefined ? undefined : input.startsAt === null ? null : new Date(input.startsAt);
    const endsAt = input.endsAt === undefined ? undefined : input.endsAt === null ? null : new Date(input.endsAt);
    if (startsAt !== undefined && endsAt !== undefined) validateWindow(startsAt, endsAt);
    return {
      ...(altText !== undefined ? { title: altText, altText } : {}),
      ...(input.description !== undefined ? { description: input.description?.trim() || null } : {}),
      ...(input.imagePath !== undefined ? { imagePath: input.imagePath.trim() } : {}),
      ...(input.targetUrl !== undefined ? { targetUrl: input.targetUrl?.trim() || null } : {}),
      ...(input.eyebrowText !== undefined ? { eyebrowText: input.eyebrowText?.trim() || null } : {}),
      ...(input.buttonLabel !== undefined ? { buttonLabel: input.buttonLabel?.trim() || null } : {}),
      ...(input.buttonSideText !== undefined ? { buttonSideText: input.buttonSideText?.trim() || null } : {}),
      ...(input.stickerLabel !== undefined ? { stickerLabel: input.stickerLabel?.trim() || null } : {}),
      ...(input.stickerText !== undefined ? { stickerText: input.stickerText?.trim() || null } : {}),
      ...(input.backgroundColor !== undefined ? { backgroundColor: input.backgroundColor?.trim().toUpperCase() || null } : {}),
      ...(startsAt !== undefined ? { startsAt } : {}),
      ...(endsAt !== undefined ? { endsAt } : {}),
      ...(input.sortOrder !== undefined ? { sortOrder: input.sortOrder } : {}),
      ...(input.isActive !== undefined ? { isActive: input.isActive } : {}),
    };
  }
}

function persianSlug(value: string): string {
  const replacements: Record<string, string> = {
    ا: "a", آ: "a", ب: "b", پ: "p", ت: "t", ث: "s", ج: "j", چ: "ch", ح: "h", خ: "kh",
    د: "d", ذ: "z", ر: "r", ز: "z", ژ: "zh", س: "s", ش: "sh", ص: "s", ض: "z", ط: "t",
    ظ: "z", ع: "a", غ: "gh", ف: "f", ق: "gh", ک: "k", گ: "g", ل: "l", م: "m", ن: "n",
    و: "v", ه: "h", ی: "y", ئ: "y", ؤ: "v", ء: "",
  };
  return [...value.toLowerCase()].map((character) => replacements[character] ?? character).join("")
    .replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "");
}

function requireManager(admin: AuthenticatedAdmin): void {
  if (admin.role !== "owner" && admin.role !== "admin") {
    throw new ForbiddenException({ code: "ADMIN_PERMISSION_REQUIRED", message: "برای این عملیات دسترسی مدیر لازم است" });
  }
}

function parseId(value: string, label: string): bigint {
  if (!/^\d{1,20}$/.test(value) || BigInt(value) < 1n) {
    throw new BadRequestException({ code: "INVALID_ID", message: `${label} معتبر نیست` });
  }
  return BigInt(value);
}

function allowedPath(value: string): boolean {
  const path = value.trim();
  if (path.startsWith("https://")) {
    try { return new URL(path).protocol === "https:"; } catch { return false; }
  }
  return path.startsWith("/") && !path.startsWith("//") && !path.split("/").includes("..");
}

function validateWindow(startsAt: Date | null, endsAt: Date | null): void {
  if (startsAt && endsAt && startsAt >= endsAt) {
    throw new BadRequestException({ code: "INVALID_BANNER_WINDOW", message: "زمان پایان بنر باید بعد از زمان شروع باشد" });
  }
}

function safeTheme(value: Prisma.JsonValue | undefined): StoreTheme {
  return typeof value === "string" && STORE_THEMES.includes(value as StoreTheme) ? value as StoreTheme : "rose";
}

function safeStoreAbout(value: Prisma.JsonValue | undefined) {
  const source = value && typeof value === "object" && !Array.isArray(value)
    ? value as Prisma.JsonObject
    : {};
  const read = (key: string) => typeof source[key] === "string" ? source[key] as string : "";
  return {
    introTitle: read("introTitle"),
    introDescription: read("introDescription"),
    address: read("address"),
    phone: read("phone"),
    rubikaUrl: read("rubikaUrl"),
    instagramUrl: read("instagramUrl"),
    physicalAddress: read("physicalAddress"),
    mapUrl: read("mapUrl"),
    latitude: typeof source.latitude === "number" && Number.isFinite(source.latitude) ? source.latitude : null,
    longitude: typeof source.longitude === "number" && Number.isFinite(source.longitude) ? source.longitude : null,
  };
}

function safeStorePopup(value: Prisma.JsonValue | undefined, updatedAt?: Date) {
  const source = value && typeof value === "object" && !Array.isArray(value)
    ? value as Prisma.JsonObject
    : {};
  const rawImagePath = typeof source.imagePath === "string" ? source.imagePath.trim() : "";
  const imagePath = /^\/uploads\/products\/[A-Za-z0-9_-]+\.(?:jpe?g|png|webp)$/i.test(rawImagePath)
    ? rawImagePath
    : null;
  const rawLinkUrl = typeof source.linkUrl === "string" ? source.linkUrl.trim() : "";
  return {
    enabled: source.enabled === true && imagePath !== null,
    imagePath,
    linkUrl: rawLinkUrl && allowedPath(rawLinkUrl) ? rawLinkUrl : null,
    updatedAt: updatedAt?.toISOString() ?? null,
  };
}

function safeNumber(value: bigint): number {
  const result = Number(value);
  if (!Number.isSafeInteger(result)) throw new Error("Shipping amount exceeds JavaScript's safe integer range.");
  return result;
}

function mergeSections(saved: Array<{ id: bigint; sectionKey: string; title: string | null; config: Prisma.JsonValue | null; isActive: boolean; sortOrder: number; updatedAt: Date }>) {
  const map = new Map(saved.map((section) => [section.sectionKey, section]));
  return defaultSections.map((fallback) => {
    const section = map.get(fallback.sectionKey);
    return section
      ? { id: section.id.toString(), sectionKey: section.sectionKey, title: section.title, isActive: section.isActive, sortOrder: section.sortOrder }
      : { id: fallback.sectionKey, ...fallback };
  }).sort((left, right) => left.sortOrder - right.sortOrder);
}
