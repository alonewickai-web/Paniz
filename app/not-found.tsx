import Link from "next/link";
import { Search } from "lucide-react";
import { StorefrontShell } from "./components/storefront-shell";

export default function NotFoundPage() {
  return <StorefrontShell><main className="store-page"><section className="page-shell store-empty-page"><span><Search size={30} /></span><h1>این صفحه پیدا نشد</h1><p>ممکن است پیوند تغییر کرده باشد یا محصول دیگر منتشر نباشد.</p><Link className="button-primary" href="/products">رفتن به فروشگاه</Link></section></main></StorefrontShell>;
}
