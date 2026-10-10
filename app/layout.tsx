import type { Metadata, Viewport } from "next";
import "@fontsource/vazirmatn/400.css";
import "@fontsource/vazirmatn/500.css";
import "@fontsource/vazirmatn/600.css";
import "@fontsource/vazirmatn/700.css";
import "./globals.css";
import "./storefront.css";
import { StorefrontProvider } from "./lib/storefront-state";
import { siteUrl } from "./lib/site-url";

export const metadata: Metadata = {
  metadataBase: new URL(siteUrl()),
  title: "PanizStyle | پوشاکی برای حال خوب تو",
  description:
    "جدیدترین لباس‌های زنانه، ست‌های راحتی و پوشاک روزمره را با تجربه‌ای ساده و دوست‌داشتنی در پانیز پیدا کن.",
  robots: {
    index: true,
    follow: true,
    googleBot: { index: true, follow: true, "max-image-preview": "large" },
  },
  openGraph: {
    title: "PanizStyle | پوشاکی برای حال خوب تو",
    description: "استایل تازه‌ات را از پانیز پیدا کن.",
    locale: "fa_IR",
    type: "website",
    siteName: "PanizStyle",
  },
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  themeColor: "#fff9f6",
};

async function getStoreTheme(): Promise<string> {
  const apiBase = (process.env.NEXT_PUBLIC_API_BASE_URL || "http://127.0.0.1:4000/api/v1").replace(/\/$/, "");
  try {
    const response = await fetch(`${apiBase}/storefront/config`, { cache: "no-store", signal: AbortSignal.timeout(1800) });
    if (!response.ok) return "rose";
    const payload = (await response.json()) as { data?: { theme?: string } };
    return ["rose", "mint", "peach", "lilac", "coral", "dark"].includes(payload.data?.theme ?? "")
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
      <body><StorefrontProvider>{children}</StorefrontProvider></body>
    </html>
  );
}
