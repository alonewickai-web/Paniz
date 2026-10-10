import type { MetadataRoute } from "next";
import { siteUrl } from "./lib/site-url";

export default function robots(): MetadataRoute.Robots {
  return {
    rules: {
      userAgent: "*",
      allow: "/",
      disallow: ["/account", "/cart", "/checkout", "/favorites"],
    },
    sitemap: siteUrl("/sitemap.xml"),
  };
}
