import { hasAdminPermission, requireAdminPermission } from "../admin-auth/admin-permissions";
import { randomUUID } from "node:crypto";
import {
  BadRequestException,
  ConflictException,
  HttpException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
} from "@nestjs/common";
import { Prisma } from "@prisma/client";
import { AuthenticatedAdmin } from "../admin-auth/admin-session.guard";
import { PrismaService } from "../database/prisma.service";
import { AdjustInventoryDto } from "./dto/adjust-inventory.dto";
import { AddAdminProductVariantDto } from "./dto/add-admin-product-variant.dto";
import { AddAdminProductImageDto } from "./dto/add-admin-product-image.dto";
import { CreateAdminProductDto } from "./dto/create-admin-product.dto";
import { ListAdminProductsQuery } from "./dto/list-admin-products.query";
import { ListAdminOrdersQuery } from "./dto/list-admin-orders.query";
import { UpdateAdminProductDto } from "./dto/update-admin-product.dto";
import { UpdateAdminProductImageDto } from "./dto/update-admin-product-image.dto";
import { UpdateAdminVariantDto } from "./dto/update-admin-variant.dto";
import { UpdateAdminOrderDto } from "./dto/update-admin-order.dto";
import { productColorKey, resolveProductColorHex, resolveProductColorName } from "../catalog/product-color";
import { WebPushService } from "../push/web-push.service";
import { AdminToolsService } from "./admin-tools.service";

const statusTransitions: Record<string, readonly string[]> = {
  pending_payment: ["cancelled"],
  paid: ["confirmed"],
  confirmed: ["preparing"],
  preparing: ["shipped"],
  shipped: ["delivered"],
  delivered: ["returned"],
};
const IRAN_UTC_OFFSET_MINUTES = 210;

@Injectable()
export class AdminService {
  private readonly logger = new Logger(AdminService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly push: WebPushService,
    private readonly tools: AdminToolsService,
  ) {}

  async dashboard(admin: AuthenticatedAdmin) {

    const now = new Date();
    const iranLocalNow = new Date(now.getTime() + IRAN_UTC_OFFSET_MINUTES * 60_000);
    const iranOffsetMs = IRAN_UTC_OFFSET_MINUTES * 60_000;
    const today = new Date(Date.UTC(iranLocalNow.getUTCFullYear(), iranLocalNow.getUTCMonth(), iranLocalNow.getUTCDate()) - iranOffsetMs);
    const month = new Date(Date.UTC(iranLocalNow.getUTCFullYear(), iranLocalNow.getUTCMonth(), 1) - iranOffsetMs);
    const [todaySales, monthSales, orderGroups, lowStockRows, recentOrders, productCount, customerCount] = await Promise.all([
      this.prisma.order.aggregate({
        where: { paymentStatus: "paid", placedAt: { gte: today } },
        _sum: { totalToman: true },
        _count: { _all: true },
      }),
      this.prisma.order.aggregate({
        where: { paymentStatus: "paid", placedAt: { gte: month } },
        _sum: { totalToman: true },
        _count: { _all: true },
      }),
      this.prisma.order.groupBy({ by: ["status"], _count: { _all: true } }),
      this.prisma.productVariant.findMany({
        where: { isActive: true },
        select: {
          id: true,
          sku: true,
          colorName: true,
          sizeLabel: true,
          stockQuantity: true,
          reservedQuantity: true,
          lowStockThreshold: true,
          product: { select: { name: true } },
        },
      }),
      this.prisma.order.findMany({
        take: 8,
        orderBy: { placedAt: "desc" },
        select: {
          id: true,
          orderNumber: true,
          status: true,
          paymentStatus: true,
          totalToman: true,
          recipientNameSnapshot: true,
          placedAt: true,
          _count: { select: { items: true } },
        },
      }),
      this.prisma.product.count({ where: { status: "published", deletedAt: null } }),
      this.prisma.customer.count({ where: { status: "active" } }),
    ]);

    const lowStock = lowStockRows
      .filter((variant) => variant.stockQuantity - variant.reservedQuantity <= variant.lowStockThreshold)
      .sort((left, right) => (left.stockQuantity - left.reservedQuantity) - (right.stockQuantity - right.reservedQuantity))
      .slice(0, 10)
      .map((variant) => ({
        variantId: variant.id.toString(),
        sku: variant.sku,
        productName: variant.product.name,
        color: variant.colorName,
        size: variant.sizeLabel,
        availableQuantity: Math.max(0, variant.stockQuantity - variant.reservedQuantity),
        threshold: variant.lowStockThreshold,
      }));

    return {
      data: {
        financialAccess: hasAdminPermission(admin, "reports.financial"),
        today: hasAdminPermission(admin, "reports.financial") ? { paidOrderCount: todaySales._count._all, paidSalesToman: toSafeNumber(todaySales._sum.totalToman ?? 0n) } : null,
        month: hasAdminPermission(admin, "reports.financial") ? { paidOrderCount: monthSales._count._all, paidSalesToman: toSafeNumber(monthSales._sum.totalToman ?? 0n) } : null,
        activeProductCount: hasAdminPermission(admin, "products.view") ? productCount : null,
        customerCount: hasAdminPermission(admin, "customers.view") ? customerCount : null,
        orderCounts: hasAdminPermission(admin, "orders.view") ? Object.fromEntries(orderGroups.map((row) => [row.status, row._count._all])) : {},
        lowStockCount: hasAdminPermission(admin, "products.view") ? lowStockRows.filter((variant) => variant.stockQuantity - variant.reservedQuantity <= variant.lowStockThreshold).length : null,
        lowStock: hasAdminPermission(admin, "products.view") ? lowStock : [],
        recentOrders: hasAdminPermission(admin, "orders.view") ? recentOrders.map((order) => ({
          id: order.id.toString(),
          orderNumber: order.orderNumber,
          status: order.status,
          paymentStatus: order.paymentStatus,
          totalToman: hasAdminPermission(admin, "reports.financial") ? toSafeNumber(order.totalToman) : null,
          recipientName: hasAdminPermission(admin, "orders.view_contact") ? order.recipientNameSnapshot : "مشتری",
          itemCount: order._count.items,
          placedAt: order.placedAt.toISOString(),
        })) : [],
      },
    };
  }

  async listOrders(admin: AuthenticatedAdmin, query: ListAdminOrdersQuery, exactId?: bigint) {
    requireAdminPermission(admin, "orders.view");
    const where: Prisma.OrderWhereInput = {
      ...(exactId ? { id: exactId } : {}),
      ...(query.status ? { status: query.status } : {}),
      ...(query.q?.trim()
        ? {
            OR: [
              { orderNumber: { contains: query.q.trim() } },
              ...(hasAdminPermission(admin, "orders.view_contact") ? [{ recipientPhoneSnapshot: { contains: query.q.trim() } }, { recipientNameSnapshot: { contains: query.q.trim() } }] : []),
            ],
          }
        : {}),
    };
    const [total, orders] = await Promise.all([
      this.prisma.order.count({ where }),
      this.prisma.order.findMany({
        where,
        skip: (query.page - 1) * query.pageSize,
        take: query.pageSize,
        orderBy: { placedAt: "desc" },
        include: {
          items: {
            select: {
              productNameSnapshot: true,
              colorNameSnapshot: true,
              sizeLabelSnapshot: true,
              quantity: true,
              lineTotalToman: true,
            },
          },
          shipments: { select: { trackingCode: true, status: true, shippedAt: true } },
        },
      }),
    ]);
    return {
      data: orders.map((order) => ({
        id: order.id.toString(),
        orderNumber: order.orderNumber,
        status: order.status,
        paymentStatus: order.paymentStatus,
        recipientName: hasAdminPermission(admin, "orders.view_contact") ? order.recipientNameSnapshot : "مشتری",
        recipientPhone: hasAdminPermission(admin, "orders.view_contact") ? order.recipientPhoneSnapshot : null,
        address: hasAdminPermission(admin, "orders.view_contact") ? order.shippingAddressSnapshot : null,
        customerNote: hasAdminPermission(admin, "orders.view_contact") ? order.customerNote : null,
        subtotalToman: hasAdminPermission(admin, "reports.financial") ? toSafeNumber(order.subtotalToman) : null,
        discountToman: hasAdminPermission(admin, "reports.financial") ? toSafeNumber(order.discountToman) : null,
        shippingToman: hasAdminPermission(admin, "reports.financial") ? toSafeNumber(order.shippingToman) : null,
        totalToman: hasAdminPermission(admin, "reports.financial") ? toSafeNumber(order.totalToman) : null,
        placedAt: order.placedAt.toISOString(),
        items: order.items.map((item) => ({
          name: item.productNameSnapshot,
          color: item.colorNameSnapshot,
          size: item.sizeLabelSnapshot,
          quantity: item.quantity,
          lineTotalToman: hasAdminPermission(admin, "reports.financial") ? toSafeNumber(item.lineTotalToman) : null,
        })),
        shipments: order.shipments.map((shipment) => ({
          trackingCode: shipment.trackingCode,
          status: shipment.status,
          shippedAt: shipment.shippedAt?.toISOString() ?? null,
        })),
      })),
      meta: { page: query.page, pageSize: query.pageSize, total, totalPages: Math.ceil(total / query.pageSize) },
    };
  }

  async listProducts(query: ListAdminProductsQuery, exactId?: bigint, admin?: AuthenticatedAdmin) {
    const where: Prisma.ProductWhereInput = {
      ...(exactId ? { id: exactId } : {}),
      ...(query.status === "archived"
        ? { deletedAt: { not: null } }
        : { deletedAt: null, ...(query.status ? { status: query.status } : {}) }),
      ...(query.q?.trim()
        ? {
            OR: [
              { name: { contains: query.q.trim() } },
              { slug: { contains: query.q.trim() } },
              { variants: { some: { sku: { contains: query.q.trim() } } } },
            ],
          }
        : {}),
    };
    const [total, products] = await Promise.all([
      this.prisma.product.count({ where }),
      this.prisma.product.findMany({
        where,
        skip: (query.page - 1) * query.pageSize,
        take: query.pageSize,
        orderBy: [{ updatedAt: "desc" }, { id: "desc" }],
        include: {
          category: { select: { id: true, name: true, slug: true } },
          images: { orderBy: [{ isPrimary: "desc" }, { sortOrder: "asc" }] },
          variants: { orderBy: [{ colorSortOrder: "asc" }, { colorName: "asc" }, { sizeLabel: "asc" }] },
          _count: { select: { wishlistItems: true, anonymousFavorites: true } },
        },
      }),
    ]);
    const soldQuantities = products.length
      ? await this.prisma.orderItem.groupBy({
          by: ["productId"],
          where: {
            productId: { in: products.map((product) => product.id) },
            order: { is: { paymentStatus: "paid" } },
          },
          _sum: { quantity: true },
        })
      : [];
    const soldByProductId = new Map(
      soldQuantities
        .filter((item) => item.productId !== null)
        .map((item) => [item.productId!.toString(), item._sum.quantity ?? 0]),
    );
    return {
      data: products.map((product) => ({
        id: product.id.toString(),
        name: product.name,
        categoryId: product.categoryId?.toString() ?? null,
        slug: product.slug,
        status: product.deletedAt ? "archived" : product.status,
        shortDescription: product.shortDescription,
        description: product.description,
        material: product.material,
        careInstructions: product.careInstructions,
        purchaseCostToman: admin && hasAdminPermission(admin, "reports.financial") ? toSafeNumber(product.purchaseCostToman) : null,
        sizeGuide: product.sizeGuide,
        seoTitle: product.seoTitle,
        seoDescription: product.seoDescription,
        seoCanonicalUrl: product.seoCanonicalUrl,
        category: product.category ? { id: product.category.id.toString(), name: product.category.name, slug: product.category.slug } : null,
        images: product.images.map((image) => ({ id: image.id.toString(), imagePath: image.imagePath, altText: image.altText, colorName: image.colorName, fileSizeBytes: image.fileSizeBytes, isPrimary: image.isPrimary, sortOrder: image.sortOrder })),
        soldQuantity: soldByProductId.get(product.id.toString()) ?? 0,
        favoriteCount: product._count.wishlistItems + product._count.anonymousFavorites,
        createdAt: product.createdAt.toISOString(),
        variants: product.variants.map((variant) => ({
          colorSortOrder: variant.colorSortOrder,
          id: variant.id.toString(),
          sku: variant.sku,
          colorName: variant.colorName,
          colorHex: variant.colorHex,
          sizeLabel: variant.sizeLabel,
          priceToman: toSafeNumber(variant.priceToman),
          compareAtPriceToman: variant.compareAtPriceToman === null ? null : toSafeNumber(variant.compareAtPriceToman),
          stockQuantity: variant.stockQuantity,
          reservedQuantity: variant.reservedQuantity,
          availableQuantity: Math.max(0, variant.stockQuantity - variant.reservedQuantity),
          lowStockThreshold: variant.lowStockThreshold,
          isActive: variant.isActive,
        })),
        updatedAt: product.updatedAt.toISOString(),
      })),
      meta: { page: query.page, pageSize: query.pageSize, total, totalPages: Math.ceil(total / query.pageSize) },
    };
  }

  async createProduct(admin: AuthenticatedAdmin, input: CreateAdminProductDto) {
    requireAdminPermission(admin, "products.create");
    if (input.status === "published") requireAdminPermission(admin, "products.publish");
    const categoryId = parseId(input.categoryId, "شناسهٔ دسته‌بندی");
    const primaryIndex = Math.max(0, input.images.findIndex((image) => image.isPrimary));
    validateVariants(input.variants);

    try {
      const created = await this.prisma.$transaction(async (tx) => {
        const category = await tx.category.findFirst({ where: { id: categoryId, isActive: true } });
        if (!category) throw new NotFoundException({ code: "CATEGORY_NOT_FOUND", message: "دسته‌بندی فعال پیدا نشد" });
        if (input.slug && await tx.productSlugRedirect.findUnique({ where: { oldSlug: input.slug.trim() } })) {
          throw new ConflictException({ code: "PRODUCT_SLUG_RESERVED", message: "این آدرس برای تغییر مسیر یک محصول قبلی نگه داشته شده است." });
        }
        const product = await tx.product.create({
          data: {
            categoryId,
            name: input.name.trim(),
            slug: input.slug?.trim() || `pending-${randomUUID()}`,
            shortDescription: input.shortDescription?.trim() || null,
            description: input.description?.trim() || null,
            material: input.material?.trim() || null,
            careInstructions: input.careInstructions?.trim() || null,
            seoTitle: input.seoTitle?.trim() || null,
            seoDescription: input.seoDescription?.trim() || null,
            seoCanonicalUrl: input.seoCanonicalUrl?.trim() || null,
            purchaseCostToman: BigInt(input.purchaseCostToman ?? "0"),
            status: input.status,
            publishedAt: input.status === "published" ? new Date() : null,
            images: {
              create: [input.images[primaryIndex], ...input.images.filter((_, index) => index !== primaryIndex)]
                .map((image, index) => ({
                  imagePath: image.imagePath.trim(),
                  altText: image.altText?.trim() || null,
                  colorName: image.colorName?.trim() || null,
                  fileSizeBytes: image.fileSizeBytes ?? 0,
                  sortOrder: index,
                  isPrimary: index === 0,
                })),
            },
          },
        });
        const productCode = `PDC-${product.id.toString().padStart(3, "0")}`;
        const requestedSlug = input.slug?.trim();
        const slugBase = `${toAsciiSlug(product.name) || "product"}-${product.id.toString()}`;
        let generatedSlug = requestedSlug || slugBase;
        let slugSuffix = 2;
        while (await tx.product.findUnique({ where: { slug: generatedSlug }, select: { id: true } })) {
          generatedSlug = `${requestedSlug || slugBase}-${slugSuffix++}`;
        }
        const updatedProduct = requestedSlug ? product : await tx.product.update({ where: { id: product.id }, data: { slug: generatedSlug } });
        const variants = [];
        for (const variant of input.variants) {
          const sku = variant.sku?.trim().toUpperCase() || await nextProductSku(tx, product.id);
          const createdVariant = await tx.productVariant.create({
            data: {
              productId: product.id,
              sku,
              colorName: resolveProductColorName(variant.colorName),
              colorHex: resolveProductColorHex(variant.colorName, variant.colorHex),
              sizeLabel: variant.sizeLabel.trim(),
              priceToman: BigInt(variant.priceToman),
              compareAtPriceToman: variant.compareAtPriceToman ? BigInt(variant.compareAtPriceToman) : null,
              stockQuantity: variant.stockQuantity ?? 0,
              isActive: true,
            },
            select: { id: true, sku: true, stockQuantity: true },
          });
          variants.push(createdVariant);
        }
        const initialStock = variants.filter((variant) => variant.stockQuantity > 0);
        if (initialStock.length) {
          await tx.inventoryMovement.createMany({
            data: initialStock.map((variant) => ({
              variantId: variant.id,
              movementType: "initial_stock",
              quantityDelta: variant.stockQuantity,
              referenceType: "product_create",
              note: `موجودی اولیه هنگام ثبت محصول ${product.name}`,
              createdByAdminId: admin.id,
            })),
          });
        }
        await tx.adminAuditLog.create({
          data: {
            adminId: admin.id,
            action: "product.created",
            entityType: "product",
            entityId: product.id,
            details: { sku: variants[0]?.sku ?? productCode, productName: product.name, slug: updatedProduct.slug, status: updatedProduct.status, variantCount: variants.length },
          },
        });
        return { data: { id: product.id.toString(), slug: updatedProduct.slug, status: updatedProduct.status, sku: variants[0]?.sku ?? productCode } };
      }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
      if (input.status === "published") {
        await this.push.notifyMarketingCustomers("محصول تازه در پانیذ", `محصول «${input.name.trim()}» به فروشگاه اضافه شد.`, `/products/${created.data.slug}`);
        void this.tools.publishProductToRubika(created.data.id, admin.id).catch((error) => {
          this.logger.warn(`Immediate Rubika product post failed: ${error instanceof Error ? error.message : "unknown error"}`);
        });
      }
      return created;
    } catch (error) {
      if (error instanceof HttpException) throw error;
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === "P2002") {
        throw new ConflictException({ code: "PRODUCT_ALREADY_EXISTS", message: "شناسهٔ محصول یا SKU تکراری است" });
      }
      throw error;
    }
  }

  async updateProduct(admin: AuthenticatedAdmin, rawProductId: string, input: UpdateAdminProductDto) {
    if (Object.keys(input).some((key) => key !== "status")) requireAdminPermission(admin, "products.edit");
    if (input.status !== undefined) requireAdminPermission(admin, "products.publish");
    const productId = parseId(rawProductId, "شناسهٔ محصول");
    const before = await this.prisma.product.findFirst({ where: { id: productId, deletedAt: null } });
    if (!before) throw new NotFoundException({ code: "PRODUCT_NOT_FOUND", message: "محصول پیدا نشد" });

    if (input.categoryId !== undefined && input.categoryId !== null) {
      const categoryId = parseId(input.categoryId, "شناسهٔ دسته‌بندی");
      const category = await this.prisma.category.findFirst({ where: { id: categoryId, isActive: true } });
      if (!category) throw new NotFoundException({ code: "CATEGORY_NOT_FOUND", message: "دسته‌بندی فعال پیدا نشد" });
    }
    if (input.status === "published") {
      const activeVariants = await this.prisma.productVariant.count({ where: { productId, isActive: true } });
      if (!activeVariants) throw new ConflictException({ code: "PRODUCT_HAS_NO_ACTIVE_VARIANTS", message: "برای انتشار، دست‌کم یک تنوع فعال لازم است" });
    }

    const data: Prisma.ProductUpdateInput = {};
    if (input.name !== undefined) data.name = input.name.trim();
    if (input.slug !== undefined) data.slug = input.slug.trim();
    if (input.categoryId !== undefined) {
      data.category = input.categoryId === null
        ? { disconnect: true }
        : { connect: { id: BigInt(input.categoryId) } };
    }
    if (input.shortDescription !== undefined) data.shortDescription = input.shortDescription.trim() || null;
    if (input.description !== undefined) data.description = input.description.trim() || null;
    if (input.material !== undefined) data.material = input.material.trim() || null;
    if (input.careInstructions !== undefined) data.careInstructions = input.careInstructions.trim() || null;
    if (input.purchaseCostToman !== undefined) {
      requireAdminPermission(admin, "reports.financial");
      data.purchaseCostToman = BigInt(input.purchaseCostToman);
    }
    if (input.seoTitle !== undefined) data.seoTitle = input.seoTitle.trim() || null;
    if (input.seoDescription !== undefined) data.seoDescription = input.seoDescription.trim() || null;
    if (input.seoCanonicalUrl !== undefined) data.seoCanonicalUrl = input.seoCanonicalUrl?.trim() || null;
    if (input.sizeGuide !== undefined) {
      data.sizeGuide = input.sizeGuide === null ? Prisma.JsonNull : input.sizeGuide as Prisma.InputJsonValue;
    }
    if (input.status !== undefined) {
      data.status = input.status;
      data.publishedAt = input.status === "published" ? before.publishedAt ?? new Date() : null;
    }

    try {
      const updated = await this.prisma.$transaction(async (tx) => {
        if (input.slug && input.slug.trim() !== before.slug) {
          const alias = await tx.productSlugRedirect.findUnique({ where: { oldSlug: input.slug.trim() } });
          if (alias && alias.productId !== productId) {
            throw new ConflictException({ code: "PRODUCT_SLUG_RESERVED", message: "این آدرس برای تغییر مسیر یک محصول دیگر نگه داشته شده است." });
          }
        }
        const product = await tx.product.update({ where: { id: productId }, data });
        if (before.slug !== product.slug) {
          await tx.productSlugRedirect.deleteMany({ where: { oldSlug: product.slug } });
          await tx.productSlugRedirect.upsert({
            where: { oldSlug: before.slug },
            create: { oldSlug: before.slug, productId },
            update: { productId },
          });
        }
        await tx.adminAuditLog.create({
          data: {
            adminId: admin.id,
            action: "product.updated",
            entityType: "product",
            entityId: product.id,
            details: { changedFields: Object.keys(input), slug: product.slug, productName: product.name,
              before: auditFields(before, Object.keys(input)), after: auditFields(product, Object.keys(input)) },
          },
        });
        return product;
      });
      if (input.status === "published" && before.status !== "published") {
        await this.push.notifyMarketingCustomers("محصول تازه در پانیذ", `محصول «${updated.name}» به فروشگاه اضافه شد.`, `/products/${updated.slug}`);
        void this.tools.publishProductToRubika(updated.id.toString(), admin.id).catch((error) => {
          this.logger.warn(`Immediate Rubika product post failed: ${error instanceof Error ? error.message : "unknown error"}`);
        });
      }
      return { data: { id: updated.id.toString(), slug: updated.slug, status: updated.status } };
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === "P2002") {
        throw new ConflictException({ code: "PRODUCT_SLUG_TAKEN", message: "این نشانی محصول قبلاً استفاده شده است" });
      }
      throw error;
    }
  }

  async addProductVariant(admin: AuthenticatedAdmin, rawProductId: string, input: AddAdminProductVariantDto) {
    requireAdminPermission(admin, "products.edit");
    const productId = parseId(rawProductId, "شناسهٔ محصول");
    const product = await this.prisma.product.findFirst({ where: { id: productId, deletedAt: null } });
    if (!product) throw new NotFoundException({ code: "PRODUCT_NOT_FOUND", message: "محصول پیدا نشد" });
    validateVariants([input]);

    try {
      const variant = await this.prisma.$transaction(async (tx) => {
        const colorKey = productColorKey(input.colorName);
        const colorHex = resolveProductColorHex(input.colorName, input.colorHex);
        const existingColors = await tx.productVariant.findMany({
          where: { productId },
          select: { colorName: true, colorHex: true },
        });
        if (existingColors.some((existing) =>
          productColorKey(existing.colorName) === colorKey &&
          resolveProductColorHex(existing.colorName, existing.colorHex) !== colorHex
        )) {
          throw new BadRequestException({
            code: "PRODUCT_COLOR_HEX_MISMATCH",
            message: "برای یک نام رنگ، کد رنگ باید در همهٔ سایزها یکسان باشد",
          });
        }
        const created = await tx.productVariant.create({
          data: {
            productId,
            sku: input.sku?.trim().toUpperCase() || await nextProductSku(tx, productId),
            colorName: resolveProductColorName(input.colorName),
            colorHex,
            sizeLabel: input.sizeLabel.trim(),
            priceToman: BigInt(input.priceToman),
            compareAtPriceToman: input.compareAtPriceToman ? BigInt(input.compareAtPriceToman) : null,
            stockQuantity: input.stockQuantity ?? 0,
            isActive: true,
          },
        });
        if (created.stockQuantity > 0) {
          await tx.inventoryMovement.create({
            data: {
              variantId: created.id,
              movementType: "initial_stock",
              quantityDelta: created.stockQuantity,
              referenceType: "variant_create",
              note: `موجودی اولیهٔ تنوع محصول ${product.name}`,
              createdByAdminId: admin.id,
            },
          });
        }
        await tx.adminAuditLog.create({
          data: {
            adminId: admin.id,
            action: "product_variant.created",
            entityType: "product_variant",
            entityId: created.id,
            details: { productId: product.id.toString(), productName: product.name, sku: created.sku },
          },
        });
        return created;
      });
      return { data: { id: variant.id.toString(), sku: variant.sku } };
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === "P2002") {
        throw new ConflictException({ code: "VARIANT_ALREADY_EXISTS", message: "کد SKU یا ترکیب رنگ و سایز تکراری است" });
      }
      throw error;
    }
  }

  async addProductImage(admin: AuthenticatedAdmin, rawProductId: string, input: AddAdminProductImageDto) {
    requireAdminPermission(admin, "products.edit");
    const productId = parseId(rawProductId, "شناسهٔ محصول");
    const product = await this.prisma.product.findFirst({ where: { id: productId, deletedAt: null } });
    if (!product) throw new NotFoundException({ code: "PRODUCT_NOT_FOUND", message: "محصول پیدا نشد" });

    const image = await this.prisma.$transaction(async (tx) => {
      const imageCount = await tx.productImage.count({ where: { productId } });
      if (input.isPrimary || imageCount === 0) {
        await tx.productImage.updateMany({ where: { productId, isPrimary: true }, data: { isPrimary: false } });
      }
      const created = await tx.productImage.create({
        data: {
          productId,
          imagePath: input.imagePath.trim(),
          altText: input.altText?.trim() || null,
          colorName: input.colorName?.trim() || null,
          fileSizeBytes: input.fileSizeBytes ?? 0,
          sortOrder: input.isPrimary ? 0 : input.sortOrder ?? imageCount,
          isPrimary: input.isPrimary || imageCount === 0,
        },
      });
      if (created.isPrimary) {
        const otherImages = await tx.productImage.findMany({ where: { productId, id: { not: created.id } }, orderBy: [{ sortOrder: "asc" }, { id: "asc" }] });
        for (const [index, other] of otherImages.entries()) {
          await tx.productImage.update({ where: { id: other.id }, data: { sortOrder: index + 1 } });
        }
      }
      await tx.adminAuditLog.create({
        data: {
          adminId: admin.id,
          action: "product_image.created",
          entityType: "product_image",
          entityId: created.id,
          details: { productId: productId.toString(), imagePath: created.imagePath, isPrimary: created.isPrimary },
        },
      });
      return created;
    }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
    return { data: { id: image.id.toString(), imagePath: image.imagePath, colorName: image.colorName, fileSizeBytes: image.fileSizeBytes, isPrimary: image.isPrimary } };
  }

  async deleteProductImage(admin: AuthenticatedAdmin, rawProductId: string, rawImageId: string) {
    requireAdminPermission(admin, "products.edit");
    const productId = parseId(rawProductId, "شناسهٔ محصول");
    const imageId = parseId(rawImageId, "شناسهٔ تصویر");
    const image = await this.prisma.$transaction(async (tx) => {
      const selected = await tx.productImage.findFirst({ where: { id: imageId, productId } });
      if (!selected) throw new NotFoundException({ code: "PRODUCT_IMAGE_NOT_FOUND", message: "تصویر محصول پیدا نشد" });
      if (await tx.productImage.count({ where: { productId } }) <= 1) {
        throw new ConflictException({ code: "PRODUCT_IMAGE_REQUIRED", message: "هر محصول باید دست‌کم یک تصویر داشته باشد" });
      }
      await tx.productImage.delete({ where: { id: imageId } });
      if (selected.isPrimary) {
        const nextPrimary = await tx.productImage.findFirst({ where: { productId }, orderBy: [{ sortOrder: "asc" }, { id: "asc" }] });
        if (nextPrimary) await tx.productImage.update({ where: { id: nextPrimary.id }, data: { isPrimary: true } });
      }
      await tx.adminAuditLog.create({
        data: {
          adminId: admin.id,
          action: "product_image.deleted",
          entityType: "product_image",
          entityId: imageId,
          details: { productId: productId.toString(), imagePath: selected.imagePath },
        },
      });
      return selected;
    }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
    return { data: { id: imageId.toString(), deleted: true } };
  }

  async updateProductImage(admin: AuthenticatedAdmin, rawProductId: string, rawImageId: string, input: UpdateAdminProductImageDto) {
    requireAdminPermission(admin, "products.edit");
    if (Object.keys(input).length === 0) {
      throw new BadRequestException({ code: "EMPTY_PRODUCT_IMAGE_UPDATE", message: "تغییری برای ذخیره انتخاب نشده است" });
    }
    const productId = parseId(rawProductId, "شناسهٔ محصول");
    const imageId = parseId(rawImageId, "شناسهٔ تصویر");
    const updated = await this.prisma.$transaction(async (tx) => {
      const current = await tx.productImage.findFirst({ where: { id: imageId, productId } });
      if (!current) throw new NotFoundException({ code: "PRODUCT_IMAGE_NOT_FOUND", message: "تصویر محصول پیدا نشد" });

      if (input.isPrimary === true) {
        const ordered = await tx.productImage.findMany({ where: { productId }, orderBy: [{ isPrimary: "desc" }, { sortOrder: "asc" }, { id: "asc" }] });
        const reordered = [current, ...ordered.filter((image) => image.id !== imageId)];
        for (const [sortOrder, image] of reordered.entries()) {
          await tx.productImage.update({ where: { id: image.id }, data: { sortOrder, isPrimary: image.id === imageId } });
        }
      } else if (input.isPrimary === false && current.isPrimary) {
        const nextPrimary = await tx.productImage.findFirst({
          where: { productId, id: { not: imageId } },
          orderBy: [{ sortOrder: "asc" }, { id: "asc" }],
        });
        if (!nextPrimary) {
          throw new ConflictException({ code: "PRODUCT_IMAGE_REQUIRED", message: "محصول باید دست‌کم یک تصویر اصلی داشته باشد" });
        }
        await tx.productImage.update({ where: { id: nextPrimary.id }, data: { isPrimary: true } });
      }

      const image = await tx.productImage.update({
        where: { id: imageId },
        data: {
          ...(input.imagePath !== undefined ? { imagePath: input.imagePath.trim() } : {}),
          ...(input.altText !== undefined ? { altText: input.altText.trim() || null } : {}),
          ...(input.colorName !== undefined ? { colorName: input.colorName?.trim() || null } : {}),
          ...(input.fileSizeBytes !== undefined ? { fileSizeBytes: input.fileSizeBytes } : {}),
          ...(input.isPrimary === true ? { sortOrder: 0 } : input.sortOrder !== undefined ? { sortOrder: input.sortOrder } : {}),
          ...(input.isPrimary !== undefined ? { isPrimary: input.isPrimary } : {}),
        },
      });
      await tx.adminAuditLog.create({
        data: {
          adminId: admin.id,
          action: "product_image.updated",
          entityType: "product_image",
          entityId: image.id,
          details: { productId: productId.toString(), imagePath: image.imagePath, altText: image.altText, colorName: image.colorName, fileSizeBytes: image.fileSizeBytes, isPrimary: image.isPrimary, sortOrder: image.sortOrder },
        },
      });
      return image;
    }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
    return { data: { id: updated.id.toString(), imagePath: updated.imagePath, altText: updated.altText, colorName: updated.colorName, fileSizeBytes: updated.fileSizeBytes, isPrimary: updated.isPrimary, sortOrder: updated.sortOrder } };
  }

  async archiveProduct(admin: AuthenticatedAdmin, rawProductId: string) {
    requireAdminPermission(admin, "products.archive");
    const productId = parseId(rawProductId, "شناسهٔ محصول");
    const product = await this.prisma.product.findFirst({ where: { id: productId, deletedAt: null } });
    if (!product) throw new NotFoundException({ code: "PRODUCT_NOT_FOUND", message: "محصول پیدا نشد" });
    await this.prisma.$transaction([
      this.prisma.product.update({ where: { id: productId }, data: { status: "archived", deletedAt: new Date() } }),
      this.prisma.adminAuditLog.create({
        data: { adminId: admin.id, action: "product.archived", entityType: "product", entityId: productId, details: { slug: product.slug } },
      }),
    ]);
    return { data: { id: productId.toString(), archived: true } };
  }

  async adjustInventory(admin: AuthenticatedAdmin, rawVariantId: string, input: AdjustInventoryDto) {
    requireAdminPermission(admin, "products.change_stock");
    if (input.delta === 0 || !input.note.trim()) {
      throw new BadRequestException({ code: "INVALID_INVENTORY_ADJUSTMENT", message: "مقدار تغییر و دلیل آن را وارد کن" });
    }
    const variantId = parseId(rawVariantId, "شناسهٔ تنوع کالا");

    const result = await this.prisma.$transaction(async (tx) => {
      const variant = await tx.productVariant.findUnique({
        where: { id: variantId },
        include: { product: { select: { name: true } } },
      });
      if (!variant) throw new NotFoundException({ code: "VARIANT_NOT_FOUND", message: "تنوع کالا پیدا نشد" });

      const changed = input.delta > 0
        ? await tx.$executeRaw`
            UPDATE product_variants
            SET stock_quantity = stock_quantity + ${input.delta}, updated_at = CURRENT_TIMESTAMP(3)
            WHERE id = ${variantId} AND stock_quantity <= ${4_294_967_295 - input.delta}
          `
        : await tx.$executeRaw`
            UPDATE product_variants
            SET stock_quantity = stock_quantity - ${-input.delta}, updated_at = CURRENT_TIMESTAMP(3)
            WHERE id = ${variantId} AND stock_quantity >= reserved_quantity + ${-input.delta}
          `;
      if (changed !== 1) {
        throw new ConflictException({ code: "INVENTORY_ADJUSTMENT_CONFLICT", message: "موجودی نمی‌تواند کمتر از رزروها باشد؛ دوباره بررسی کن" });
      }

      const updated = await tx.productVariant.findUniqueOrThrow({ where: { id: variantId } });
      await tx.inventoryMovement.create({
        data: {
          variantId,
          movementType: "adjustment",
          quantityDelta: input.delta,
          note: input.note.trim(),
          referenceType: "admin_adjustment",
          createdByAdminId: admin.id,
        },
      });
      await tx.adminAuditLog.create({
        data: {
          adminId: admin.id,
          action: "inventory.adjusted",
          entityType: "product_variant",
          entityId: variantId,
          details: {
            sku: variant.sku,
            productName: variant.product.name,
            delta: input.delta,
            availableBefore: variant.stockQuantity - variant.reservedQuantity,
            availableAfter: updated.stockQuantity - updated.reservedQuantity,
            note: input.note.trim(),
          },
        },
      });
      return {
        data: {
          variantId: updated.id.toString(),
          sku: updated.sku,
          stockQuantity: updated.stockQuantity,
          reservedQuantity: updated.reservedQuantity,
          availableQuantity: Math.max(0, updated.stockQuantity - updated.reservedQuantity),
          productName: variant.product.name,
        },
      };
    }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
    if (input.delta > 0 && result.data.availableQuantity > 0) {
      await this.push.notifyVariantSubscribers(variantId, result.data.productName);
    }
    const { productName: _productName, ...publicData } = result.data;
    return { data: publicData };
  }

  async updateVariant(admin: AuthenticatedAdmin, rawVariantId: string, input: UpdateAdminVariantDto) {
    if (input.priceToman !== undefined || input.compareAtPriceToman !== undefined) requireAdminPermission(admin, "products.change_price");
    if (input.lowStockThreshold !== undefined) requireAdminPermission(admin, "products.change_stock");
    if (Object.keys(input).some((key) => !["priceToman", "compareAtPriceToman", "lowStockThreshold"].includes(key))) requireAdminPermission(admin, "products.edit");
    if (Object.keys(input).length === 0) {
      throw new BadRequestException({ code: "EMPTY_VARIANT_UPDATE", message: "تغییری برای ذخیره انتخاب نشده است" });
    }
    const variantId = parseId(rawVariantId, "شناسهٔ تنوع کالا");
    const current = await this.prisma.productVariant.findUnique({
      where: { id: variantId },
      include: { product: { select: { name: true } } },
    });
    if (!current) throw new NotFoundException({ code: "VARIANT_NOT_FOUND", message: "تنوع کالا پیدا نشد" });

    const nextPrice = input.priceToman === undefined ? current.priceToman : BigInt(input.priceToman);
    const nextCompareAt = input.compareAtPriceToman === undefined
      ? current.compareAtPriceToman
      : input.compareAtPriceToman === null ? null : BigInt(input.compareAtPriceToman);
    if (nextCompareAt !== null && nextCompareAt <= nextPrice) {
      throw new BadRequestException({ code: "INVALID_COMPARE_AT_PRICE", message: "قیمت قبل از تخفیف باید بیشتر از قیمت فروش باشد" });
    }

    const data: Prisma.ProductVariantUpdateInput = {};
    const nextColorName = input.colorName === undefined
      ? current.colorName
      : resolveProductColorName(input.colorName);
    const nextColorHex = input.colorHex === undefined
      ? (input.colorName === undefined ? current.colorHex ?? resolveProductColorHex(nextColorName) : resolveProductColorHex(nextColorName))
      : resolveProductColorHex(nextColorName, input.colorHex);
    const nextSizeLabel = input.sizeLabel === undefined ? current.sizeLabel : input.sizeLabel.trim();
    if (input.colorName !== undefined || input.colorHex !== undefined || input.sizeLabel !== undefined) {
      const siblings = await this.prisma.productVariant.findMany({
        where: { productId: current.productId, id: { not: variantId } },
        select: { colorName: true, colorHex: true, sizeLabel: true },
      });
      const nextColorKey = productColorKey(nextColorName);
      if (siblings.some((sibling) =>
        productColorKey(sibling.colorName) === nextColorKey &&
        resolveProductColorHex(sibling.colorName, sibling.colorHex) !== nextColorHex
      )) {
        throw new BadRequestException({ code: "PRODUCT_COLOR_HEX_MISMATCH", message: "برای یک نام رنگ، کد رنگ باید در همهٔ سایزها یکسان باشد" });
      }
      if (siblings.some((sibling) =>
        productColorKey(sibling.colorName) === nextColorKey &&
        sibling.sizeLabel.trim().toLocaleLowerCase() === nextSizeLabel.toLocaleLowerCase()
      )) {
        throw new ConflictException({ code: "VARIANT_ALREADY_EXISTS", message: "این ترکیب رنگ و سایز قبلاً برای محصول ثبت شده است" });
      }
      data.colorName = nextColorName;
      data.colorHex = nextColorHex;
      data.sizeLabel = nextSizeLabel;
    }
    if (input.priceToman !== undefined) data.priceToman = nextPrice;
    if (input.compareAtPriceToman !== undefined) data.compareAtPriceToman = nextCompareAt;
    if (input.isActive !== undefined) data.isActive = input.isActive;
    if (input.lowStockThreshold !== undefined) data.lowStockThreshold = input.lowStockThreshold;
    if (input.colorSortOrder !== undefined) data.colorSortOrder = input.colorSortOrder;

    try {
      const updated = await this.prisma.$transaction(async (tx) => {
        const variant = await tx.productVariant.update({ where: { id: variantId }, data });
        if (input.colorSortOrder !== undefined) {
          await tx.productVariant.updateMany({
            where: { productId: current.productId, colorName: variant.colorName },
            data: { colorSortOrder: input.colorSortOrder },
          });
        }
        await tx.adminAuditLog.create({
          data: {
            adminId: admin.id,
            action: "product_variant.updated",
            entityType: "product_variant",
            entityId: variant.id,
            details: {
              productId: current.productId.toString(),
              productName: current.product.name,
              sku: current.sku,
              colorBefore: current.colorName,
              colorAfter: variant.colorName,
              colorSortOrderBefore: current.colorSortOrder,
              colorSortOrderAfter: input.colorSortOrder ?? current.colorSortOrder,
              sizeBefore: current.sizeLabel,
              sizeAfter: variant.sizeLabel,
              priceBefore: current.priceToman.toString(),
              priceAfter: variant.priceToman.toString(),
              compareAtPriceBefore: current.compareAtPriceToman?.toString() ?? null,
              compareAtPriceAfter: variant.compareAtPriceToman?.toString() ?? null,
              isActive: variant.isActive,
            },
          },
        });
        return variant;
      });
      return {
        data: {
          variantId: updated.id.toString(),
          sku: updated.sku,
          colorName: updated.colorName,
          colorHex: updated.colorHex,
          sizeLabel: updated.sizeLabel,
          priceToman: toSafeNumber(updated.priceToman),
          compareAtPriceToman: updated.compareAtPriceToman === null ? null : toSafeNumber(updated.compareAtPriceToman),
          isActive: updated.isActive,
        },
      };
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === "P2002") {
        throw new ConflictException({ code: "VARIANT_ALREADY_EXISTS", message: "این کد یا ترکیب رنگ و سایز قبلاً ثبت شده است" });
      }
      throw error;
    }
  }

  async updateOrderStatus(admin: AuthenticatedAdmin, rawOrderId: string, input: UpdateAdminOrderDto) {
    requireAdminPermission(admin, "orders.status");
    if (input.status === "cancelled") requireAdminPermission(admin, "orders.cancel");
    if (input.status === "returned") requireAdminPermission(admin, "orders.refund");
    const orderId = parseId(rawOrderId, "شناسهٔ سفارش");
    const result = await this.prisma.$transaction(async (tx) => {
      const order = await tx.order.findUnique({
        where: { id: orderId },
        include: { items: { select: { variantId: true, quantity: true } } },
      });
      if (!order) throw new NotFoundException({ code: "ORDER_NOT_FOUND", message: "سفارش پیدا نشد" });
      if (!statusTransitions[order.status]?.includes(input.status)) {
        throw new ConflictException({ code: "INVALID_ORDER_TRANSITION", message: "تغییر وضعیت سفارش با مسیر فعلی مجاز نیست" });
      }
      if (input.status !== "cancelled" && order.paymentStatus !== "paid") {
        throw new ConflictException({ code: "PAYMENT_NOT_VERIFIED", message: "تغییر وضعیت پردازش فقط پس از تأیید پرداخت سمت سرور مجاز است" });
      }
      if (input.status === "shipped" && !input.trackingCode?.trim()) {
        throw new BadRequestException({ code: "TRACKING_CODE_REQUIRED", message: "برای ارسال، کد رهگیری را وارد کن" });
      }

      const updated = await tx.order.updateMany({
        where: { id: order.id, status: order.status, paymentStatus: order.paymentStatus },
        data: { status: input.status },
      });
      if (updated.count !== 1) {
        throw new ConflictException({ code: "ORDER_CHANGED", message: "وضعیت سفارش هم‌زمان تغییر کرده؛ دوباره دریافتش کن" });
      }

      if (input.status === "cancelled" && order.status === "pending_payment") {
        for (const item of order.items) {
          if (item.variantId === null) continue;
          const released = await tx.productVariant.updateMany({
            where: { id: item.variantId, reservedQuantity: { gte: item.quantity } },
            data: { reservedQuantity: { decrement: item.quantity } },
          });
          if (released.count !== 1) {
            throw new ConflictException({ code: "RESERVATION_CHANGED", message: "رزرو موجودی تغییر کرده؛ سفارش را دوباره بررسی کن" });
          }
          await tx.inventoryMovement.create({
            data: {
              variantId: item.variantId,
              movementType: "reservation_release",
              quantityDelta: 0,
              reservedDelta: -item.quantity,
              referenceType: "order",
              referenceId: order.id,
              createdByAdminId: admin.id,
              note: `آزادسازی رزرو پس از لغو سفارش ${order.orderNumber}`,
            },
          });
        }
      }

      if (input.status === "cancelled" && order.paymentStatus !== "paid") {
        await tx.couponRedemption.deleteMany({ where: { orderId: order.id } });
      }

      if (input.status === "shipped") {
        await tx.shipment.create({
          data: {
            orderId: order.id,
            trackingCode: input.trackingCode!.trim(),
            status: "shipped",
            shippedAt: new Date(),
          },
        });
      }
      await tx.orderStatusHistory.create({
        data: {
          orderId: order.id,
          oldStatus: order.status,
          newStatus: input.status,
          note: input.note?.trim() || null,
          visibleToCustomer: true,
          changedByAdminId: admin.id,
        },
      });
      await tx.adminAuditLog.create({
        data: {
          adminId: admin.id,
          action: "order.status_changed",
          entityType: "order",
          entityId: order.id,
          details: {
            orderNumber: order.orderNumber,
            from: order.status,
            to: input.status,
            note: input.note?.trim() ?? "",
            trackingCode: input.status === "shipped" ? input.trackingCode!.trim() : "",
          },
        },
      });
      return { customerId: order.customerId, orderNumber: order.orderNumber, status: input.status, trackingCode: input.status === "shipped" ? input.trackingCode!.trim() : null };
    }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
    if (result.customerId !== null) {
      const statusText: Record<string, string> = {
        confirmed: "سفارش تأیید شد", preparing: "سفارش در حال آماده‌سازی است",
        shipped: "سفارش به پست تحویل شد", delivered: "سفارش تحویل داده شد",
        cancelled: "سفارش لغو شد", returned: "سفارش مرجوع شد",
      };
      const tracking = result.trackingCode ? ` کد رهگیری: ${result.trackingCode}` : "";
      await this.push.notifyCustomer(result.customerId, statusText[result.status] ?? "وضعیت سفارش تغییر کرد", `سفارش ${result.orderNumber}${tracking}`, "/account#orders");
    }
    return { data: { orderNumber: result.orderNumber, status: result.status } };
  }

  async productDetail(admin: AuthenticatedAdmin, idText: string) {
    requireAdminPermission(admin, "products.view");
    const result = await this.listProducts({ page: 1, pageSize: 1 } as ListAdminProductsQuery, parseId(idText, "شناسهٔ محصول"), admin);
    if (!result.data.length) throw new NotFoundException({ code: "PRODUCT_NOT_FOUND", message: "محصول پیدا نشد یا بایگانی شده است." });
    return { data: result.data[0] };
  }

  async orderDetail(admin: AuthenticatedAdmin, idText: string) {
    requireAdminPermission(admin, "orders.view");
    const result = await this.listOrders(admin, { page: 1, pageSize: 1 } as ListAdminOrdersQuery, parseId(idText, "شناسهٔ سفارش"));
    if (!result.data.length) throw new NotFoundException({ code: "ORDER_NOT_FOUND", message: "سفارش پیدا نشد." });
    return { data: result.data[0] };
  }

  async productCategories() {
    const categories = await this.prisma.category.findMany({ where: { isActive: true }, orderBy: [{ sortOrder: "asc" }, { name: "asc" }], select: { id: true, parentId: true, name: true, isActive: true } });
    return { data: categories.map((row) => ({ ...row, id: row.id.toString(), parentId: row.parentId?.toString() ?? null })) };
  }
}

function auditFields(row: object, fields: string[]): Prisma.InputJsonObject {
  const source = row as Record<string, unknown>;
  return JSON.parse(JSON.stringify(Object.fromEntries(fields.map((key) => [key, source[key] ?? null])), (_key, value) => typeof value === "bigint" ? value.toString() : value));
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

function toSafeNumber(value: bigint): number {
  const number = Number(value);
  if (!Number.isSafeInteger(number)) throw new Error("Admin report value exceeds JavaScript's safe integer range.");
  return number;
}

function validateVariants(variants: CreateAdminProductDto["variants"]): void {
  const combinations = new Set<string>();
  const skus = new Set<string>();
  const colors = new Map<string, string>();
  for (const variant of variants) {
    if (variant.sku?.trim()) {
      const sku = variant.sku.trim().toUpperCase();
      if (skus.has(sku)) throw new BadRequestException({ code: "DUPLICATE_VARIANT_SKU", message: "کد کالا تکراری است" });
      skus.add(sku);
    }
    if (variant.compareAtPriceToman && BigInt(variant.compareAtPriceToman) <= BigInt(variant.priceToman)) {
      throw new BadRequestException({ code: "INVALID_COMPARE_AT_PRICE", message: "قیمت قبل از تخفیف باید بیشتر از قیمت فروش باشد" });
    }
    const colorKey = productColorKey(variant.colorName);
    const colorHex = resolveProductColorHex(variant.colorName, variant.colorHex);
    const existingHex = colors.get(colorKey);
    if (existingHex && existingHex !== colorHex) {
      throw new BadRequestException({
        code: "PRODUCT_COLOR_HEX_MISMATCH",
        message: "برای یک نام رنگ، کد رنگ باید در همهٔ سایزها یکسان باشد",
      });
    }
    colors.set(colorKey, colorHex);
    const combination = `${colorKey}\u0000${variant.sizeLabel.trim().toLocaleLowerCase()}`;
    if (combinations.has(combination)) {
      throw new BadRequestException({ code: "DUPLICATE_VARIANT", message: "ترکیب رنگ و سایز تکراری است" });
    }
    combinations.add(combination);
  }
}

function toAsciiSlug(value: string): string {
  const transliteration: Record<string, string> = {
    ا: "a", آ: "a", ب: "b", پ: "p", ت: "t", ث: "s", ج: "j", چ: "ch", ح: "h", خ: "kh",
    د: "d", ذ: "z", ر: "r", ز: "z", ژ: "zh", س: "s", ش: "sh", ص: "s", ض: "z", ط: "t",
    ظ: "z", ع: "a", غ: "gh", ف: "f", ق: "gh", ک: "k", گ: "g", ل: "l", م: "m", ن: "n",
    و: "v", ه: "h", ی: "y", ئ: "y", ؤ: "v", ء: "",
  };
  return [...value.toLowerCase()]
    .map((character) => transliteration[character] ?? character)
    .join("")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

async function nextProductSku(tx: Prisma.TransactionClient, productId: bigint): Promise<string> {
  const base = `PDC-${productId.toString().padStart(3, "0")}`;
  const existingCount = await tx.productVariant.count({ where: { productId } });
  const ordinal = existingCount === 0 ? "" : `-${String(existingCount + 1).padStart(2, "0")}`;
  let sku = `${base}${ordinal}`;
  let suffix = 2;
  while (await tx.productVariant.findUnique({ where: { sku }, select: { id: true } })) {
    sku = `${base}${ordinal}-${suffix++}`;
  }
  return sku;
}
