import type { Metadata } from "next";
import { notFound, permanentRedirect } from "next/navigation";
import { StorefrontShell } from "../../components/storefront-shell";
import { ProductDetailView } from "../../components/product-detail-view";
import { apiBaseUrl, type StoreProductDetail } from "../../lib/catalog";
import { siteUrl } from "../../lib/site-url";

type RouteProps = { params: Promise<{ slug: string }> };

function absoluteProductImage(path: string) {
  return path.startsWith("/uploads/") ? new URL(path, apiBaseUrl()).toString() : siteUrl(path);
}

type ProductRouteData = StoreProductDetail | { redirectTo: string; statusCode: 301 };

async function loadProduct(slug: string): Promise<ProductRouteData | null> {
  try {
    const response = await fetch(`${apiBaseUrl()}/products/${encodeURIComponent(slug)}`, { cache: "no-store" });
    if (!response.ok) return null;
    const payload = await response.json() as { data?: ProductRouteData };
    return payload.data ?? null;
  } catch {
    return null;
  }
}

export async function generateMetadata({ params }: RouteProps): Promise<Metadata> {
  const { slug } = await params;
  const product = await loadProduct(slug);
  if (!product) return { title: "محصول پیدا نشد | پانیذ" };
  if ("redirectTo" in product) permanentRedirect(product.redirectTo);
  const title = product.seoTitle?.trim() || `${product.name} | پانیذ`;
  const description = product.seoDescription?.trim() || product.shortDescription || product.description || `مشاهدهٔ رنگ‌ها، سایزها و قیمت ${product.name} در پانیذ.`;
  const canonical = product.seoCanonicalUrl?.trim() || `/products/${encodeURIComponent(product.slug)}`;
  return {
    title,
    description,
    alternates: { canonical },
    openGraph: {
      title,
      description,
      url: canonical.startsWith("https://") ? canonical : siteUrl(canonical),
      type: "website",
      siteName: "فروشگاه پانیذ",
      locale: "fa_IR",
      images: product.image ? [{ url: absoluteProductImage(product.image.path), alt: product.image.alt || product.name }] : [],
    },
    twitter: {
      card: "summary_large_image",
      title,
      description,
      images: product.image ? [absoluteProductImage(product.image.path)] : [],
    },
  };
}

export default async function ProductPage({ params }: RouteProps) {
  const { slug } = await params;
  const product = await loadProduct(slug);
  if (!product) notFound();
  if ("redirectTo" in product) permanentRedirect(product.redirectTo);

  const productUrl = product.seoCanonicalUrl?.trim() || siteUrl(`/products/${encodeURIComponent(product.slug)}`);
  const productJsonLd = {
    "@context": "https://schema.org",
    "@type": "Product",
    name: product.name,
    description: product.seoDescription || product.shortDescription || product.description || undefined,
    image: product.images.map((image) => absoluteProductImage(image.path)),
    sku: product.variants.length === 1 ? product.variants[0].sku : undefined,
    category: product.category?.name,
    brand: { "@type": "Brand", name: "PANIZ" },
    url: productUrl.startsWith("https://") ? productUrl : siteUrl(productUrl),
    offers: product.variants.map((variant) => ({
      "@type": "Offer",
      priceCurrency: "IRR",
      price: String(Math.round(variant.priceToman * 10)),
      availability: variant.availableQuantity > 0 ? "https://schema.org/InStock" : "https://schema.org/OutOfStock",
      itemCondition: "https://schema.org/NewCondition",
      url: productUrl.startsWith("https://") ? productUrl : siteUrl(productUrl),
      sku: variant.sku || undefined,
    })),
  };
  const breadcrumbJsonLd = {
    "@context": "https://schema.org",
    "@type": "BreadcrumbList",
    itemListElement: [
      { "@type": "ListItem", position: 1, name: "خانه", item: siteUrl("/") },
      { "@type": "ListItem", position: 2, name: "محصولات", item: siteUrl("/products") },
      ...(product.category ? [{ "@type": "ListItem", position: 3, name: product.category.name, item: siteUrl(`/products?category=${encodeURIComponent(product.category.slug)}`) }] : []),
      { "@type": "ListItem", position: product.category ? 4 : 3, name: product.name, item: productUrl.startsWith("https://") ? productUrl : siteUrl(productUrl) },
    ],
  };
  const safeJsonLd = (value: unknown) => JSON.stringify(value).replace(/</g, "\\u003c");

  return <StorefrontShell>
    <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: safeJsonLd(productJsonLd) }} />
    <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: safeJsonLd(breadcrumbJsonLd) }} />
    <ProductDetailView product={product} />
  </StorefrontShell>;
}
