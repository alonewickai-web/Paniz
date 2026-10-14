import Link from "next/link";
import { Sparkles } from "lucide-react";
import { StorefrontShell } from "../components/storefront-shell";
import { StoreAboutInfo } from "./store-about-info";

export const metadata = { title: "دربارهٔ فروشگاه پانیذ", description: "آشنایی با فروشگاه پوشاک زنانهٔ پانیذ." };

export default function AboutPage() {
  return <StorefrontShell><main className="store-page"><article className="page-shell store-info-page"><nav className="store-breadcrumb"><Link href="/">خانه</Link><span>/</span><span>دربارهٔ ما</span></nav><span className="section-kicker"><Sparkles size={15} /> قصهٔ پانیذ</span><h1>برای روزهایی که می‌خوای خودت باشی</h1><p className="store-info-lead">پانیذ فروشگاه آنلاین پوشاک زنانه است؛ جایی برای انتخاب لباس‌های روزمره، راحتی و استایل‌هایی که با حال و سلیقهٔ خودت جور هستند.</p><StoreAboutInfo /><Link className="button-primary" href="/products">دیدن محصولات</Link></article></main></StorefrontShell>;
}
