"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useState } from "react";
import { Heart, House, Menu, Search, ShoppingBag, UserRound } from "lucide-react";
import { useStorefront } from "../lib/storefront-state";
import { apiBaseUrl, type StoreCategory } from "../lib/catalog";

export function StorefrontHeader() {
  const { cart, favorites } = useStorefront();
  const count = cart.reduce((total, line) => total + line.quantity, 0);
  const [categoryLinks, setCategoryLinks] = useState<{ name: string; slug: string }[]>([]);

  useEffect(() => {
    const controller = new AbortController();
    void fetch(`${apiBaseUrl()}/categories`, { cache: "no-store", signal: controller.signal })
      .then((response) => response.ok ? response.json() as Promise<{ data?: StoreCategory[] }> : null)
      .then((payload) => {
        if (!payload || !Array.isArray(payload.data)) return;
        const links = payload.data.flatMap((category) => [category, ...(category.children ?? [])]);
        setCategoryLinks(links.map(({ name, slug }) => ({ name, slug })));
      })
      .catch(() => undefined);
    return () => controller.abort();
  }, []);

  return (
    <>
      <div className="announcement-bar">انتخاب‌های دوست‌داشتنی برای روزهای پیشِ رو</div>
      <header className="site-header">
        <div className="header-main page-shell">
          <Link className="brand" href="/" aria-label="صفحهٔ اصلی پانیز">
            <span className="brand-mark">P</span><span className="brand-word">PANIZ<span>STYLE</span></span>
          </Link>
          <form className="search-box" action="/products" method="get">
            <Search size={19} aria-hidden="true" />
            <label className="sr-only" htmlFor="store-search">جست‌وجوی محصولات</label>
            <input id="store-search" name="q" type="search" placeholder="دنبال چی می‌گردی؟" />
          </form>
          <div className="header-actions">
            <Link className="header-icon" href="/favorites" aria-label={`علاقه‌مندی‌ها، ${favorites.length} محصول`}><Heart size={21} /></Link>
            <Link className="header-icon bag-icon" href="/cart" aria-label={`سبد خرید، ${count} کالا`}>
              <ShoppingBag size={21} />{count > 0 && <span className="count-badge">{new Intl.NumberFormat("fa-IR").format(count)}</span>}
            </Link>
            <Link className="account-button" href="/account"><UserRound size={18} /><span>پروفایل</span></Link>
          </div>
        </div>
        <nav className="desktop-nav page-shell" aria-label="ناوبری اصلی">
          <Link className="nav-link" href="/">خانه</Link>
          <Link className="nav-link" href="/products">همهٔ محصولات</Link>
          {(categoryLinks.length ? categoryLinks : [
            { name: "لباس راحتی", slug: "loungewear" },
            { name: "ست ورزشی", slug: "sportswear" },
            { name: "مانتو", slug: "coats" },
            { name: "تیشرت و بلوز", slug: "tops" },
          ]).slice(0, 5).map((category) => <Link className="nav-link" href={`/products?category=${encodeURIComponent(category.slug)}`} key={category.slug}>{category.name}</Link>)}
          <Link className="nav-link nav-help" href="/help/faq">راهنمای خرید</Link>
        </nav>
      </header>
    </>
  );
}

export function StorefrontFooter() {
  return (
    <footer className="site-footer store-footer">
      <div className="footer-inner page-shell">
        <div className="footer-brand"><Link className="brand" href="/"><span className="brand-mark">P</span><span className="brand-word">PANIZ<span>STYLE</span></span></Link><p>پانیز؛ برای روزهایی که می‌خوای خودت باشی.</p></div>
        <div><strong>راهنمای خرید</strong><Link href="/help/shipping">روش‌های ارسال</Link><Link href="/policies/returns">تعویض و مرجوعی</Link><Link href="/help/faq">پرسش‌های پرتکرار</Link></div>
        <div><strong>همراه پانیز</strong><Link href="/about">دربارهٔ ما</Link><Link href="/contact">تماس با ما</Link><Link href="/policies/privacy">حریم خصوصی</Link></div>
      </div>
      <div className="footer-bottom page-shell"><span>© پانیز استایل</span><span>پوشاک زنانه، با انتخاب تو</span></div>
    </footer>
  );
}

export function StorefrontBottomNav() {
  const pathname = usePathname();
  return (
    <nav className="mobile-bottom-nav" aria-label="ناوبری پایین">
      <Link href="/" className={`bottom-nav-item ${pathname === "/" ? "active" : ""}`}><House size={20} /><span>خانه</span></Link>
      <Link href="/products" className={`bottom-nav-item ${pathname.startsWith("/products") ? "active" : ""}`}><Menu size={20} /><span>دسته‌ها</span></Link>
      <Link href="/favorites" className={`bottom-nav-item ${pathname === "/favorites" ? "active" : ""}`}><Heart size={20} /><span>علاقه‌مندی</span></Link>
      <Link href="/cart" className={`bottom-nav-item bottom-cart ${pathname === "/cart" || pathname === "/checkout" ? "active" : ""}`}><ShoppingBag size={20} /><span>سبد خرید</span></Link>
      <Link href="/account" className={`bottom-nav-item ${pathname.startsWith("/account") ? "active" : ""}`}><UserRound size={20} /><span>پروفایل</span></Link>
    </nav>
  );
}

export function StorefrontShell({ children }: Readonly<{ children: React.ReactNode }>) {
  return <><StorefrontHeader />{children}<StorefrontFooter /><StorefrontBottomNav /></>;
}
