export type StoreProduct = {
  id: string;
  name: string;
  slug: string;
  shortDescription: string | null;
  seoTitle?: string | null;
  seoDescription?: string | null;
  seoCanonicalUrl?: string | null;
  updatedAt?: string;
  category: { id: string; name: string; slug: string } | null;
  image: { path: string; alt: string | null } | null;
  priceToman: number | null;
  compareAtPriceToman: number | null;
  colors: { name: string; value: string }[];
  sizes: string[];
  variants: StoreVariant[];
  available: boolean;
};

export type StoreVariant = {
  id: string;
  sku?: string;
  color: { name: string; value?: string; hex?: string | null };
  size: string;
  priceToman: number;
  compareAtPriceToman: number | null;
  availableQuantity: number;
};

export type StoreProductDetail = StoreProduct & {
  description: string | null;
  material: string | null;
  careInstructions: string | null;
  sizeGuide: unknown;
  images: { id: string; path: string; alt: string | null; colorName: string | null; isPrimary: boolean }[];
};

export type StoreCategory = {
  id: string;
  name: string;
  slug: string;
  imagePath: string | null;
  children?: StoreCategory[];
};

export type ProductListPayload = {
  data: StoreProduct[];
  meta: { page: number; pageSize: number; total: number; totalPages: number };
};

export type ProductSuggestionsPayload = {
  data: StoreProduct[];
};

export function apiBaseUrl() {
  return (process.env.NEXT_PUBLIC_API_BASE_URL || "http://127.0.0.1:4000/api/v1").replace(/\/$/, "");
}

export function formatToman(value: number) {
  return `${new Intl.NumberFormat("fa-IR").format(value)} تومان`;
}

export function productImage(product: StoreProduct) {
  return product.image?.path || "/images/paniz-linen.webp";
}

export function colorHex(color: StoreVariant["color"]) {
  return color.value || color.hex || "#d8c7af";
}
