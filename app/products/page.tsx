import type { Metadata } from "next";
import { Suspense } from "react";
import { ProductsExplorer } from "../components/products-explorer";
import { apiBaseUrl } from "../lib/catalog";

type Category = { name: string; slug: string; children?: Category[] };
type RouteProps = { searchParams: Promise<Record<string, string | string[] | undefined>> };

async function allCategories(): Promise<Category[]> {
  try {
    const response = await fetch(`${apiBaseUrl()}/categories`, { cache: "no-store", signal: AbortSignal.timeout(5000) });
    if (!response.ok) return [];
    const payload = await response.json() as { data?: Category[] };
    return payload.data ?? [];
  } catch {
    return [];
  }
}

export async function generateMetadata({ searchParams }: RouteProps): Promise<Metadata> {
  const params = await searchParams;
  const categoryValue = params.category;
  const categorySlug = typeof categoryValue === "string" ? categoryValue : "";
  const otherFilters = Object.keys(params).some((key) => key !== "category");

  if (categorySlug) {
    const categories = await allCategories();
    const category = [...categories, ...categories.flatMap((item) => item.children ?? [])]
      .find((item) => item.slug === categorySlug);
    if (category && !otherFilters) {
      const categoryLabel = category.name.includes("زنانه") ? category.name : `${category.name} زنانه`;
      const title = `${categoryLabel} | فروشگاه پانیذ`;
      const description = `خرید ${categoryLabel} از فروشگاه پانیذ؛ مشاهدهٔ مدل‌ها، رنگ‌ها، سایزها و قیمت‌های موجود.`;
      const canonical = `/products?category=${encodeURIComponent(category.slug)}`;
      return {
        title,
        description,
        alternates: { canonical },
        openGraph: { title, description, url: canonical, siteName: "فروشگاه پانیذ", locale: "fa_IR", type: "website" },
        twitter: { card: "summary", title, description },
      };
    }
  }

  if (otherFilters || categorySlug) {
    return {
      title: "همهٔ محصولات | پانیذ",
      robots: { index: false, follow: true },
    };
  }

  return {
    title: "همهٔ محصولات | پانیذ",
    description: "جست‌وجو و خرید پوشاک زنانهٔ پانیذ با فیلتر رنگ، سایز و قیمت.",
    alternates: { canonical: "/products" },
    openGraph: { url: "/products", title: "همهٔ محصولات | پانیذ", siteName: "فروشگاه پانیذ", locale: "fa_IR", type: "website" },
    twitter: { card: "summary", title: "همهٔ محصولات | پانیذ" },
  };
}

export default function ProductsPage() {
  return <Suspense fallback={<main className="store-page"><div className="page-shell store-skeleton-line" /></main>}><ProductsExplorer /></Suspense>;
}
