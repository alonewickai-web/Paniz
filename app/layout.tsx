import type { Metadata, Viewport } from "next";
import "@fontsource/vazirmatn/400.css";
import "@fontsource/vazirmatn/500.css";
import "@fontsource/vazirmatn/600.css";
import "@fontsource/vazirmatn/700.css";
import "leaflet/dist/leaflet.css";
import "./globals.css";
import "./storefront.css";
import { StorefrontProvider } from "./lib/storefront-state";
import { siteUrl } from "./lib/site-url";
import { SiteVisitTracker } from "./components/site-visit-tracker";
import { StoreThemeSync } from "./components/store-theme-sync";
import { GoogleAnalyticsTag } from "./components/google-analytics-tag";
import { PwaRegistration } from "./components/pwa-registration";

export const metadata: Metadata = {
  metadataBase: new URL(siteUrl()),
  title: "فروشگاه پانیذ",
  applicationName: "فروشگاه پانیذ",
  appleWebApp: { capable: true, title: "پانیذ", statusBarStyle: "default" },
  description:
    "فروشگاه پانیذ برای خرید آنلاین لباس زنانه، پوشاک زنانه و ست زنانه؛ مدل‌های متنوع پوشاک پانیذ را ببین و استایل دلخواهت را انتخاب کن.",
  keywords: ["فروشگاه پانیذ", "پوشاک پانیذ", "پانیذ", "فروشگاه لباس", "لباس زنانه", "پوشاک زنانه", "ست زنانه"],
  robots: {
    index: true,
    follow: true,
    googleBot: { index: true, follow: true, "max-image-preview": "large" },
  },
  openGraph: {
    title: "فروشگاه پانیذ",
    description: "خرید آنلاین لباس زنانه، پوشاک زنانه و ست زنانه از فروشگاه پانیذ.",
    locale: "fa_IR",
    type: "website",
    siteName: "فروشگاه پانیذ",
    url: "/",
  },
  twitter: {
    card: "summary_large_image",
    title: "فروشگاه پانیذ",
    description: "خرید آنلاین لباس زنانه، پوشاک زنانه و ست زنانه از فروشگاه پانیذ.",
  },
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  themeColor: "#fff9f6",
};

const websiteStructuredData = {
  "@context": "https://schema.org",
  "@type": "WebSite",
  name: "فروشگاه پانیذ",
  alternateName: "پانیذ",
  url: siteUrl("/"),
};

async function getStoreTheme(): Promise<string> {
  const apiBase = (process.env.NEXT_PUBLIC_API_BASE_URL || "http://127.0.0.1:4000/api/v1").replace(/\/$/, "");
  try {
    const response = await fetch(`${apiBase}/storefront/config`, { cache: "no-store", signal: AbortSignal.timeout(1800) });
    if (!response.ok) return "rose";
    const payload = (await response.json()) as { data?: { theme?: string } };
    return ["rose", "mint", "peach", "lilac", "coral", "dark", "berry", "ocean", "sunset", "forest", "royal", "citrus", "lagoon", "mocha", "orchid", "slate"].includes(payload.data?.theme ?? "")
      ? payload.data!.theme!
      : "rose";
  } catch {
    return "rose";
  }
}

export default async function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  const theme = await getStoreTheme();
  return (
    <html lang="fa" dir="rtl" data-theme={theme}>
      <body>
        <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(websiteStructuredData) }} />
        <GoogleAnalyticsTag />
        <PwaRegistration />
        <StorefrontProvider><StoreThemeSync /><SiteVisitTracker />{children}</StorefrontProvider>
      </body>
    </html>
  );
}
