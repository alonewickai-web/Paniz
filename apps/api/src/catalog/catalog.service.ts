import { BadRequestException, Injectable, NotFoundException } from "@nestjs/common";
import { Prisma } from "@prisma/client";
import { PrismaService } from "../database/prisma.service";
import { ListProductsQuery } from "./dto/list-products.query";
import { StoreManagementService } from "../admin/store-management.service";

const publicProductRelations = {
  category: { select: { id: true, name: true, slug: true } },
  images: {
    orderBy: [{ isPrimary: "desc" }, { sortOrder: "asc" }],
  },
  variants: {
    where: { isActive: true },
    orderBy: [{ priceToman: "asc" }],
  },
} satisfies Prisma.ProductInclude;

type PublicProduct = Prisma.ProductGetPayload<{ include: typeof publicProductRelations }>;

@Injectable()
export class CatalogService {
  constructor(private readonly prisma: PrismaService, private readonly storeManagement: StoreManagementService) {}

  storefrontConfig() {
    return this.storeManagement.publicConfig();
  }

  async listCategories() {
    const categories = await this.prisma.category.findMany({
      where: { isActive: true, parentId: null },
      orderBy: [{ sortOrder: "asc" }, { name: "asc" }],
      select: {
        id: true,
        name: true,
        slug: true,
        description: true,
        imagePath: true,
        children: {
          where: { isActive: true },
          orderBy: [{ sortOrder: "asc" }, { name: "asc" }],
          select: { id: true, name: true, slug: true, imagePath: true },
        },
      },
    });

    return {
      data: categories.map((category) => ({
        ...category,
        id: category.id.toString(),
        children: category.children.map((child) => ({ ...child, id: child.id.toString() })),
      })),
    };
  }

  async listProducts(query: ListProductsQuery) {
    const page = query.page;
    const pageSize = query.pageSize;
    const normalizedQuery = normalizePersian(query.q ?? "");
    if (query.minPrice !== undefined && query.maxPrice !== undefined && query.minPrice > query.maxPrice) {
      throw new BadRequestException({ code: "INVALID_PRICE_RANGE", message: "بازهٔ قیمت معتبر نیست" });
    }

    const priceRange: { gte?: bigint; lte?: bigint } = {};
    if (query.minPrice !== undefined) priceRange.gte = BigInt(query.minPrice);
    if (query.maxPrice !== undefined) priceRange.lte = BigInt(query.maxPrice);
    const variantWhere: Prisma.ProductVariantWhereInput = {
      isActive: true,
      ...(query.size ? { sizeLabel: query.size } : {}),
      ...(query.color ? { colorName: { contains: normalizePersian(query.color) } } : {}),
      ...(query.inStock ? { stockQuantity: { gt: 0 } } : {}),
      ...(query.onSale ? { compareAtPriceToman: { not: null } } : {}),
      ...(Object.keys(priceRange).length ? { priceToman: priceRange } : {}),
    };
    const where: Prisma.ProductWhereInput = {
      status: "published",
      publishedAt: { lte: new Date() },
      deletedAt: null,
      variants: { some: variantWhere },
      category: {
        is: {
          isActive: true,
          ...(query.category
            ? { OR: [{ slug: query.category }, { parent: { slug: query.category } }] }
            : {}),
        },
      },
      ...(normalizedQuery
        ? {
            OR: [
              { name: { contains: normalizedQuery } },
              { shortDescription: { contains: normalizedQuery } },
              { description: { contains: normalizedQuery } },
              { variants: { some: { sku: { contains: normalizedQuery } } } },
            ],
          }
        : {}),
    };

    const total = await this.prisma.product.count({ where });
    const products = await this.prisma.product.findMany({
      where,
      include: publicProductRelations,
      orderBy: [{ publishedAt: "desc" }, { id: "desc" }],
      ...(query.sort === "price-asc" || query.sort === "price-desc"
        ? {}
        : { skip: (page - 1) * pageSize, take: pageSize }),
    });
    const orderedProducts = query.sort === "price-asc" || query.sort === "price-desc"
      ? products.sort((left, right) => {
          const leftPrice = left.variants[0]?.priceToman ?? 0n;
          const rightPrice = right.variants[0]?.priceToman ?? 0n;
          return query.sort === "price-asc"
            ? (leftPrice < rightPrice ? -1 : leftPrice > rightPrice ? 1 : 0)
            : (leftPrice > rightPrice ? -1 : leftPrice < rightPrice ? 1 : 0);
        }).slice((page - 1) * pageSize, page * pageSize)
      : products;

    return {
      data: orderedProducts.map((product) => this.toProductSummary(product)),
      meta: {
        page,
        pageSize,
        total,
        totalPages: Math.ceil(total / pageSize),
      },
    };
  }

  async getProduct(slug: string) {
    const product = await this.prisma.product.findFirst({
      where: {
        slug,
        status: "published",
        publishedAt: { lte: new Date() },
        deletedAt: null,
        variants: { some: { isActive: true } },
        category: { is: { isActive: true } },
      },
      include: publicProductRelations,
    });

    if (!product) {
      throw new NotFoundException({
        code: "PRODUCT_NOT_FOUND",
        message: "محصول موردنظر پیدا نشد",
      });
    }

    const cheapestVariant = product.variants[0];
    return {
      data: {
        ...this.toProductSummary(product),
        description: product.description,
        material: product.material,
        careInstructions: product.careInstructions,
        sizeGuide: product.sizeGuide,
        images: product.images.map((image) => ({
          id: image.id.toString(),
          path: image.imagePath,
          alt: image.altText,
          isPrimary: image.isPrimary,
        })),
        variants: product.variants.map((variant) => ({
          id: variant.id.toString(),
          sku: variant.sku,
          color: { name: variant.colorName, hex: variant.colorHex },
          size: variant.sizeLabel,
          priceToman: toSafeNumber(variant.priceToman),
          compareAtPriceToman: variant.compareAtPriceToman === null
            ? null
            : toSafeNumber(variant.compareAtPriceToman),
          availableQuantity: Math.max(variant.stockQuantity - variant.reservedQuantity, 0),
        })),
        minimumPriceToman: cheapestVariant ? toSafeNumber(cheapestVariant.priceToman) : null,
      },
    };
  }

  private toProductSummary(product: PublicProduct) {
    const cheapestVariant = product.variants[0];
    return {
      id: product.id.toString(),
      name: product.name,
      slug: product.slug,
      shortDescription: product.shortDescription,
      category: product.category
        ? { id: product.category.id.toString(), name: product.category.name, slug: product.category.slug }
        : null,
      image: product.images[0]
        ? { path: product.images[0].imagePath, alt: product.images[0].altText }
        : null,
      priceToman: cheapestVariant ? toSafeNumber(cheapestVariant.priceToman) : null,
      compareAtPriceToman: cheapestVariant?.compareAtPriceToman == null
        ? null
        : toSafeNumber(cheapestVariant.compareAtPriceToman),
      colors: Array.from(
        new Map(product.variants.map((variant) => [
          variant.colorName,
          { name: variant.colorName, value: variant.colorHex ?? "#d8c7af" },
        ])).values(),
      ),
      sizes: Array.from(new Set(product.variants.map((variant) => variant.sizeLabel))),
      variants: product.variants.map((variant) => ({
        id: variant.id.toString(),
        color: { name: variant.colorName, value: variant.colorHex ?? "#d8c7af" },
        size: variant.sizeLabel,
        priceToman: toSafeNumber(variant.priceToman),
        compareAtPriceToman: variant.compareAtPriceToman === null
          ? null
          : toSafeNumber(variant.compareAtPriceToman),
        availableQuantity: Math.max(variant.stockQuantity - variant.reservedQuantity, 0),
      })),
      available: product.variants.some((variant) => variant.stockQuantity > variant.reservedQuantity),
    };
  }
}

function normalizePersian(input: string): string {
  const persianDigits = "۰۱۲۳۴۵۶۷۸۹";
  return input
    .normalize("NFKC")
    .replace(/[يى]/g, "ی")
    .replace(/ك/g, "ک")
    .replace(/[\u200c\u200e\u200f]/g, " ")
    .replace(/[۰-۹]/g, (digit) => String(persianDigits.indexOf(digit)))
    .trim()
    .replace(/\s+/g, " ");
}

function toSafeNumber(value: bigint): number {
  const number = Number(value);
  if (!Number.isSafeInteger(number)) {
    throw new Error("Catalog price exceeds JavaScript's safe integer range.");
  }
  return number;
}
