import Link from "next/link";
import { Heart, Sparkles } from "lucide-react";
import { StorefrontShell } from "../components/storefront-shell";

export const metadata = { title: "دربارهٔ فروشگاه پانیذ", description: "آشنایی با فروشگاه پوشاک زنانهٔ پانیذ." };

export default function AboutPage() {
  return <StorefrontShell><main className="store-page"><article className="page-shell store-info-page"><nav className="store-breadcrumb"><Link href="/">خانه</Link><span>/</span><span>دربارهٔ ما</span></nav><span className="section-kicker"><Sparkles size={15} /> قصهٔ پانیذ</span><h1>برای روزهایی که می‌خوای خودت باشی</h1><p className="store-info-lead">پانیذ فروشگاه آنلاین پوشاک زنانه است؛ جایی برای انتخاب لباس‌های روزمره، راحتی و استایل‌هایی که با حال و سلیقهٔ خودت جور هستند.</p><div className="store-info-callout"><Heart size={20} /><p>این فروشگاه در حال آماده‌سازی است. اطلاعات هر محصول، موجودی رنگ و سایز و قیمت از کاتالوگ آنلاین نمایش داده می‌شود.</p></div><Link className="button-primary" href="/products">دیدن محصولات</Link></article></main></StorefrontShell>;
}
