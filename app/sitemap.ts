import type { MetadataRoute } from "next";
import { apiBaseUrl, type ProductListPayload } from "./lib/catalog";
import { siteUrl } from "./lib/site-url";

export const dynamic = "force-dynamic";

type Category = { name: string; slug: string; children?: Category[] };

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const entries: MetadataRoute.Sitemap = [
    { url: siteUrl("/"), changeFrequency: "daily", priority: 1 },
    { url: siteUrl("/products"), changeFrequency: "daily", priority: 0.9 },
  ];

  try {
    const pageSize = 48;
    const maxPages = 200;
    for (let page = 1; page <= maxPages; page += 1) {
      const response = await fetch(`${apiBaseUrl()}/products?page=${page}&pageSize=${pageSize}`, {
        cache: "no-store",
        signal: AbortSignal.timeout(8000),
      });
      if (!response.ok) break;

      const payload = (await response.json()) as ProductListPayload;
      for (const product of payload.data ?? []) {
        const canonicalUrl = product.seoCanonicalUrl?.trim() || siteUrl(`/products/${encodeURIComponent(product.slug)}`);
        if (new URL(canonicalUrl, siteUrl()).origin !== new URL(siteUrl()).origin) continue;
        entries.push({
          url: canonicalUrl,
          lastModified: product.updatedAt ? new Date(product.updatedAt) : undefined,
          changeFrequency: "weekly",
          priority: 0.8,
        });
      }

      if (page >= (payload.meta?.totalPages ?? 0) || payload.data.length < pageSize) break;
    }
  } catch {
    // Keep the public storefront URLs in the sitemap while the catalog API is unavailable.
  }

  try {
    const response = await fetch(`${apiBaseUrl()}/categories`, {
      cache: "no-store",
      signal: AbortSignal.timeout(8000),
    });
    if (response.ok) {
      const payload = await response.json() as { data?: Category[] };
      for (const category of payload.data ?? []) {
        entries.push({ url: siteUrl(`/products?category=${encodeURIComponent(category.slug)}`), changeFrequency: "weekly", priority: 0.7 });
        for (const child of category.children ?? []) {
          entries.push({ url: siteUrl(`/products?category=${encodeURIComponent(child.slug)}`), changeFrequency: "weekly", priority: 0.65 });
        }
      }
    }
  } catch {
    // Categories are optional in the sitemap while the catalog API is unavailable.
  }

  const unique = new Map<string, MetadataRoute.Sitemap[number]>();
  for (const entry of entries) if (!unique.has(entry.url)) unique.set(entry.url, entry);
  return [...unique.values()];
}
