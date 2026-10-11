import { BadRequestException, Injectable, NotFoundException } from "@nestjs/common";
import { Prisma } from "@prisma/client";
import { PrismaService } from "../database/prisma.service";
import { ListProductsQuery } from "./dto/list-products.query";
import { StoreManagementService } from "../admin/store-management.service";
import { productColorKey, resolveProductColorHex, resolveProductColorName } from "./product-color";

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

  async suggestProducts(input: string | undefined) {
    const query = normalizeSuggestionText(input ?? "");
    if (Array.from(query).length < 2) return { data: [] };

    const candidates = await this.prisma.product.findMany({
      where: {
        status: "published",
        publishedAt: { lte: new Date() },
        deletedAt: null,
        variants: { some: { isActive: true } },
        category: { is: { isActive: true } },
      },
      select: {
        id: true,
        name: true,
        shortDescription: true,
        category: { select: { name: true } },
        variants: {
          where: { isActive: true },
          select: { sku: true, colorName: true },
        },
      },
      orderBy: [{ publishedAt: "desc" }, { id: "desc" }],
    });

    const ranked = candidates
      .map((product) => ({ id: product.id, score: productSuggestionScore(query, product) }))
      .filter((product) => product.score >= 0.48)
      .sort((left, right) => right.score - left.score)
      .slice(0, 5);

    if (!ranked.length) return { data: [] };

    const products = await this.prisma.product.findMany({
      where: {
        id: { in: ranked.map((product) => product.id) },
        status: "published",
        publishedAt: { lte: new Date() },
        deletedAt: null,
        variants: { some: { isActive: true } },
        category: { is: { isActive: true } },
      },
      include: publicProductRelations,
    });
    const byId = new Map(products.map((product) => [product.id.toString(), product]));

    return {
      data: ranked.flatMap(({ id }) => {
        const product = byId.get(id.toString());
        return product ? [this.toProductSummary(product)] : [];
      }),
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
          color: { name: resolveProductColorName(variant.colorName), hex: resolveProductColorHex(variant.colorName, variant.colorHex) },
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
          productColorKey(variant.colorName),
          { name: resolveProductColorName(variant.colorName), value: resolveProductColorHex(variant.colorName, variant.colorHex) },
        ])).values(),
      ),
      sizes: Array.from(new Set(product.variants.map((variant) => variant.sizeLabel))),
      variants: product.variants.map((variant) => ({
        id: variant.id.toString(),
        color: { name: resolveProductColorName(variant.colorName), value: resolveProductColorHex(variant.colorName, variant.colorHex) },
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

type SuggestionCandidate = {
  name: string;
  shortDescription: string | null;
  category: { name: string } | null;
  variants: { sku: string | null; colorName: string }[];
};

function normalizeSuggestionText(input: string): string {
  return normalizePersian(input)
    .toLocaleLowerCase("fa-IR")
    .replace(/[آأإ]/g, "ا")
    .replace(/[\u064B-\u065F\u0670\u0640]/g, "")
    .replace(/[^\p{L}\p{N}\s]/gu, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function productSuggestionScore(query: string, product: SuggestionCandidate): number {
  const colorText = product.variants.map((variant) => variant.colorName).join(" ");
  const skuText = product.variants.map((variant) => variant.sku ?? "").join(" ");
  return Math.max(
    matchSuggestionText(query, product.name),
    matchSuggestionText(query, product.category?.name ?? "") * 0.84,
    matchSuggestionText(query, colorText) * 0.94,
    matchSuggestionText(query, skuText) * 0.92,
    matchSuggestionText(query, product.shortDescription ?? "") * 0.58,
  );
}

function matchSuggestionText(query: string, input: string): number {
  const candidate = normalizeSuggestionText(input);
  if (!candidate) return 0;
  if (candidate.includes(query)) return 1;

  const compactQuery = query.replace(/\s/g, "");
  const compactCandidate = candidate.replace(/\s/g, "");
  if (compactQuery.length >= 2 && compactCandidate.includes(compactQuery)) return 0.96;

  const queryWords = query.split(" ").filter(Boolean);
  const candidateWords = candidate.split(" ").filter(Boolean);
  if (!queryWords.length || !candidateWords.length) return 0;
  const wordScores = queryWords.map((queryWord) => {
    let best = 0;
    for (const candidateWord of candidateWords) best = Math.max(best, matchSuggestionWord(queryWord, candidateWord));
    return best;
  });
  const matches = wordScores.filter((score) => score > 0).length;
  const average = wordScores.reduce((sum, score) => sum + score, 0) / wordScores.length;
  const coverage = matches / wordScores.length;
  return average * 0.72 + coverage * 0.28;
}

function matchSuggestionWord(query: string, candidate: string): number {
  if (query === candidate) return 1;
  if (query.length >= 3 && (candidate.startsWith(query) || query.startsWith(candidate))) return 0.9;
  if (Math.min(query.length, candidate.length) < 3) return 0;

  const left = Array.from(query);
  const right = Array.from(candidate);
  const longest = Math.max(left.length, right.length);
  const allowedDistance = longest <= 6 ? 1 : 2;
  if (Math.abs(left.length - right.length) > allowedDistance) return 0;

  let previous = Array.from({ length: right.length + 1 }, (_, index) => index);
  for (let leftIndex = 1; leftIndex <= left.length; leftIndex += 1) {
    const current = [leftIndex];
    for (let rightIndex = 1; rightIndex <= right.length; rightIndex += 1) {
      current[rightIndex] = Math.min(
        current[rightIndex - 1] + 1,
        previous[rightIndex] + 1,
        previous[rightIndex - 1] + (left[leftIndex - 1] === right[rightIndex - 1] ? 0 : 1),
      );
    }
    previous = current;
  }
  const distance = previous[right.length];
  return distance <= allowedDistance ? 1 - distance / longest : 0;
}

function toSafeNumber(value: bigint): number {
  const number = Number(value);
  if (!Number.isSafeInteger(number)) {
    throw new Error("Catalog price exceeds JavaScript's safe integer range.");
  }
  return number;
}
