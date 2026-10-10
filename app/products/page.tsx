import { Suspense } from "react";
import { ProductsExplorer } from "../components/products-explorer";

export const metadata = {
  title: "همهٔ محصولات | PanizStyle",
  description: "جست‌وجو و خرید پوشاک زنانهٔ پانیز با فیلتر رنگ، سایز و قیمت.",
};

export default function ProductsPage() {
  return <Suspense fallback={<main className="store-page"><div className="page-shell store-skeleton-line" /></main>}><ProductsExplorer /></Suspense>;
}
