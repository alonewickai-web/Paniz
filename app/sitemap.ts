import type { MetadataRoute } from "next";
import { apiBaseUrl, type ProductListPayload } from "./lib/catalog";
import { siteUrl } from "./lib/site-url";

export const revalidate = 3600;

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
        next: { revalidate },
        signal: AbortSignal.timeout(8000),
      });
      if (!response.ok) break;

      const payload = (await response.json()) as ProductListPayload;
      for (const product of payload.data ?? []) {
        entries.push({
          url: siteUrl(`/products/${encodeURIComponent(product.slug)}`),
          changeFrequency: "weekly",
          priority: 0.8,
        });
      }

      if (page >= (payload.meta?.totalPages ?? 0) || payload.data.length < pageSize) break;
    }
  } catch {
    // Keep the public storefront URLs in the sitemap while the catalog API is unavailable.
  }

  return entries;
}
