import { Controller, Get, Param, Query } from "@nestjs/common";
import {
  ApiNotFoundResponse,
  ApiOkResponse,
  ApiOperation,
  ApiQuery,
  ApiTags,
} from "@nestjs/swagger";
import { CatalogService } from "./catalog.service";
import { ListProductsQuery } from "./dto/list-products.query";
import { ProductSuggestionsQuery } from "./dto/product-suggestions.query";

@ApiTags("کاتالوگ")
@Controller()
export class CatalogController {
  constructor(private readonly catalogService: CatalogService) {}

  @Get("storefront/config")
  @ApiOperation({ summary: "دریافت بنرها، رنگ‌بندی و چیدمان عمومی ویترین" })
  storefrontConfig() {
    return this.catalogService.storefrontConfig();
  }

  @Get("categories")
  @ApiOperation({ summary: "دریافت دسته‌بندی‌های فعال" })
  @ApiOkResponse({ description: "فهرست دسته‌بندی‌های فعال فروشگاه" })
  categories() {
    return this.catalogService.listCategories();
  }

  @Get("products")
  @ApiOperation({ summary: "جست‌وجو و فهرست محصولات منتشرشده" })
  @ApiQuery({ name: "page", required: false, type: Number, example: 1 })
  @ApiQuery({ name: "pageSize", required: false, type: Number, example: 12 })
  @ApiQuery({ name: "category", required: false, type: String })
  @ApiQuery({ name: "q", required: false, type: String })
  @ApiQuery({ name: "minPrice", required: false, type: Number })
  @ApiQuery({ name: "maxPrice", required: false, type: Number })
  @ApiQuery({ name: "size", required: false, type: String })
  @ApiQuery({ name: "color", required: false, type: String })
  @ApiQuery({ name: "inStock", required: false, type: Boolean })
  @ApiQuery({ name: "onSale", required: false, type: Boolean })
  @ApiQuery({ name: "sort", required: false, enum: ["newest", "price-asc", "price-desc"] })
  @ApiOkResponse({ description: "محصولات صفحه‌بندی‌شده همراه با قیمت از تنوع فعال" })
  products(@Query() query: ListProductsQuery) {
    return this.catalogService.listProducts(query);
  }

  @Get("products/suggestions")
  @ApiOperation({ summary: "پیشنهاد نزدیک‌ترین محصولات برای جست‌وجوی زنده" })
  @ApiQuery({ name: "q", required: true, type: String })
  @ApiOkResponse({ description: "حداکثر پنج پیشنهاد محصول بر اساس شباهت عبارت جست‌وجو" })
  productSuggestions(@Query() query: ProductSuggestionsQuery) {
    return this.catalogService.suggestProducts(query.q);
  }

  @Get("products/:slug")
  @ApiOperation({ summary: "دریافت جزئیات محصول منتشرشده با slug" })
  @ApiOkResponse({ description: "جزئیات محصول، تصاویر و تنوع‌های فعال" })
  @ApiNotFoundResponse({ description: "محصول منتشرشده‌ای با این شناسه پیدا نشد" })
  product(@Param("slug") slug: string) {
    return this.catalogService.getProduct(slug);
  }
}
