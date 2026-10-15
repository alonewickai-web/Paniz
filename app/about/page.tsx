import Link from "next/link";
import { Sparkles } from "lucide-react";
import { StorefrontShell } from "../components/storefront-shell";
import { StoreAboutInfo } from "./store-about-info";

export const metadata = { title: "دربارهٔ فروشگاه پانیذ", description: "آشنایی با فروشگاه پوشاک زنانهٔ پانیذ." };

export default function AboutPage() {
  return <StorefrontShell><main className="store-page"><article className="page-shell store-info-page"><nav className="store-breadcrumb"><Link href="/">خانه</Link><span>/</span><span>دربارهٔ ما</span></nav><span className="section-kicker"><Sparkles size={15} /> معرفی فروشگاه</span><StoreAboutInfo /><Link className="button-primary" href="/products">دیدن محصولات</Link></article></main></StorefrontShell>;
}
