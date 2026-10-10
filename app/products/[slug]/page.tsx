import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { StorefrontShell } from "../../components/storefront-shell";
import { ProductDetailView } from "../../components/product-detail-view";
import { apiBaseUrl, type StoreProductDetail } from "../../lib/catalog";
import { siteUrl } from "../../lib/site-url";

type RouteProps = { params: Promise<{ slug: string }> };

async function loadProduct(slug: string): Promise<StoreProductDetail | null> {
  try {
    const response = await fetch(`${apiBaseUrl()}/products/${encodeURIComponent(slug)}`, { cache: "no-store" });
    if (!response.ok) return null;
    const payload = await response.json() as { data?: StoreProductDetail };
    return payload.data ?? null;
  } catch {
    return null;
  }
}

export async function generateMetadata({ params }: RouteProps): Promise<Metadata> {
  const { slug } = await params;
  const product = await loadProduct(slug);
  if (!product) return { title: "محصول پیدا نشد | PanizStyle" };
  return {
    title: `${product.name} | PanizStyle`,
    description: product.shortDescription || product.description || `مشاهدهٔ رنگ‌ها، سایزها و قیمت ${product.name} در پانیز.`,
    alternates: { canonical: `/products/${encodeURIComponent(product.slug)}` },
    openGraph: {
      title: `${product.name} | PanizStyle`,
      url: siteUrl(`/products/${encodeURIComponent(product.slug)}`),
      images: product.image ? [product.image.path] : [],
    },
  };
}

export default async function ProductPage({ params }: RouteProps) {
  const { slug } = await params;
  const product = await loadProduct(slug);
  if (!product) notFound();

  return <StorefrontShell><ProductDetailView product={product} /></StorefrontShell>;
}
