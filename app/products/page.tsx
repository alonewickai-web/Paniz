import { Suspense } from "react";
import { ProductsExplorer } from "../components/products-explorer";

export const metadata = {
  title: "همهٔ محصولات | پانیذ",
  description: "جست‌وجو و خرید پوشاک زنانهٔ پانیذ با فیلتر رنگ، سایز و قیمت.",
  alternates: { canonical: "/products" },
  openGraph: { url: "/products", title: "همهٔ محصولات | پانیذ" },
};

export default function ProductsPage() {
  return <Suspense fallback={<main className="store-page"><div className="page-shell store-skeleton-line" /></main>}><ProductsExplorer /></Suspense>;
}
