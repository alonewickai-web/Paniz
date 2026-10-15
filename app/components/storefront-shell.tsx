"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useState } from "react";
import { Heart, House, ShoppingBag, UserRound } from "lucide-react";
import { useStorefront } from "../lib/storefront-state";
import { apiBaseUrl, publicImageUrl, type StoreCategory } from "../lib/catalog";
import { ProductSearchAutocomplete } from "./product-search-autocomplete";
import { MarketingPushPrompt } from "./marketing-push-prompt";
import { PromotionalPopup } from "./promotional-popup";

export function StorefrontHeader() {
  const { cart, favorites } = useStorefront();
  const pathname = usePathname();
  const count = cart.reduce((total, line) => total + line.quantity, 0);
  const [categoryLinks, setCategoryLinks] = useState<{ name: string; slug: string }[]>([]);
  const [activeCategory, setActiveCategory] = useState("");
  const [hasDiscounts, setHasDiscounts] = useState(false);
  const [activeSale, setActiveSale] = useState(false);
  const logoSrc = useStoreLogo();

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

  useEffect(() => {
    const controller = new AbortController();
    void fetch(`${apiBaseUrl()}/products?onSale=true&page=1&pageSize=1`, {
      cache: "no-store",
      signal: controller.signal,
    })
      .then((response) => response.ok ? response.json() as Promise<{ data?: unknown[]; meta?: { total?: number } }> : null)
      .then((payload) => {
        if (!payload) return;
        setHasDiscounts((payload.meta?.total ?? payload.data?.length ?? 0) > 0);
      })
      .catch(() => undefined);
    return () => controller.abort();
  }, []);

  useEffect(() => {
    const updateCategory = () => {
      const params = new URLSearchParams(window.location.search);
      setActiveCategory(params.get("category") ?? "");
      setActiveSale(pathname === "/products" && params.get("onSale") === "true");
    };
    updateCategory();
    window.addEventListener("popstate", updateCategory);
    return () => window.removeEventListener("popstate", updateCategory);
  }, [pathname]);

  return (
    <>
      <EnamadSeal />
      <div className="announcement-bar">انتخاب‌های دوست‌داشتنی برای روزهای پیشِ رو</div>
      <header className="site-header">
        <div className="header-main page-shell">
          <Link className="brand" href="/" aria-label="صفحهٔ اصلی پانیذ">
            <img className="brand-image" src={logoSrc} alt="" /><span className="brand-word">پانیذ</span>
          </Link>
          <ProductSearchAutocomplete id="store-search" wrapperClassName="header-search-autocomplete" />
          <div className="header-actions">
            <Link className="header-icon" href="/favorites" aria-label={`علاقه‌مندی‌ها، ${favorites.length} محصول`}><Heart size={21} /></Link>
            <Link className="header-icon bag-icon" href="/cart" aria-label={`سبد خرید، ${count} کالا`}>
              <ShoppingBag size={21} />{count > 0 && <span className="count-badge">{new Intl.NumberFormat("fa-IR").format(count)}</span>}
            </Link>
            <Link className="account-button" href="/account"><UserRound size={18} /><span>پروفایل</span></Link>
          </div>
        </div>
        <nav className="desktop-nav page-shell" aria-label="ناوبری اصلی">
          <Link className={`nav-link${pathname === "/" ? " active" : ""}`} href="/">خانه</Link>
          <Link className={`nav-link${pathname.startsWith("/products") && !activeCategory && !activeSale ? " active" : ""}`} href="/products" onClick={() => { setActiveCategory(""); setActiveSale(false); }}>همهٔ محصولات</Link>
          {(categoryLinks.length ? categoryLinks : [
            { name: "لباس راحتی", slug: "loungewear" },
            { name: "ست ورزشی", slug: "sportswear" },
            { name: "مانتو", slug: "coats" },
            { name: "تیشرت و بلوز", slug: "tops" },
          ]).slice(0, 5).map((category) => <Link className={`nav-link${pathname.startsWith("/products") && activeCategory === category.slug ? " active" : ""}`} href={`/products?category=${encodeURIComponent(category.slug)}`} onClick={() => { setActiveCategory(category.slug); setActiveSale(false); }} key={category.slug}>{category.name}</Link>)}
          {hasDiscounts && <Link className={`nav-link nav-offer${activeSale ? " active" : ""}`} href="/products?onSale=true" onClick={() => { setActiveCategory(""); setActiveSale(true); }}>تخفیف‌ها</Link>}
          <Link className={`nav-link nav-help${pathname.startsWith("/help") ? " active" : ""}`} href="/help/faq">راهنمای خرید</Link>
        </nav>
      </header>
    </>
  );
}

export function StorefrontFooter() {
  const logoSrc = useStoreLogo();
  return (
    <footer className="site-footer store-footer">
      <div className="footer-inner page-shell">
        <div className="footer-brand"><Link className="brand" href="/"><img className="brand-image" src={logoSrc} alt="" /><span className="brand-word">پانیذ</span></Link><p>پانیذ؛ برای روزهایی که می‌خوای خودت باشی.</p></div>
        <div><strong>راهنمای خرید</strong><Link href="/help/shipping">روش‌های ارسال</Link><Link href="/policies/returns">تعویض و مرجوعی</Link><Link href="/help/faq">پرسش‌های پرتکرار</Link></div>
        <div><strong>همراه پانیذ</strong><Link href="/about">دربارهٔ ما</Link><Link href="/contact">تماس با ما</Link><Link href="/policies/privacy">حریم خصوصی</Link></div>
      </div>
      <div className="footer-bottom page-shell"><span>© پانیذ</span><span>پوشاک زنانه، با انتخاب تو</span></div>
    </footer>
  );
}

export function EnamadSeal() {
  return <div className="enamad-seal" dangerouslySetInnerHTML={{ __html: `<a referrerpolicy='origin' target='_blank' href='https://trustseal.enamad.ir/?id=8191295&Code=H613Jqd6T1ufboLySUezjs7YqoET1EPq'><img referrerpolicy='origin' src='https://trustseal.enamad.ir/logo.aspx?id=8191295&Code=H613Jqd6T1ufboLySUezjs7YqoET1EPq' alt='' style='cursor:pointer' code='H613Jqd6T1ufboLySUezjs7YqoET1EPq'></a>` }} />;
}

function useStoreLogo() {
  const [logo, setLogo] = useState("/paniz-logo.jpg");
  useEffect(() => {
    const controller = new AbortController();
    void fetch(`${apiBaseUrl()}/storefront/config`, { cache: "no-store", signal: controller.signal })
      .then((response) => response.ok ? response.json() as Promise<{ data?: { logoPath?: string | null } }> : null)
      .then((payload) => {
        if (!controller.signal.aborted && payload?.data?.logoPath) setLogo(publicImageUrl(payload.data.logoPath));
      })
      .catch(() => undefined);
    return () => controller.abort();
  }, []);
  return logo;
}

export function StorefrontBottomNav() {
  const pathname = usePathname();
  return (
    <nav className="mobile-bottom-nav" aria-label="ناوبری پایین">
      <Link href="/" className={`bottom-nav-item ${pathname === "/" ? "active" : ""}`}><House size={20} /><span>خانه</span></Link>
      <Link href="/favorites" className={`bottom-nav-item ${pathname === "/favorites" ? "active" : ""}`}><Heart size={20} /><span>علاقه‌مندی</span></Link>
      <Link href="/cart" className={`bottom-nav-item bottom-cart ${pathname === "/cart" || pathname === "/checkout" ? "active" : ""}`}><ShoppingBag size={20} /><span>سبد خرید</span></Link>
      <Link href="/account" className={`bottom-nav-item ${pathname.startsWith("/account") ? "active" : ""}`}><UserRound size={20} /><span>پروفایل</span></Link>
    </nav>
  );
}

export function StorefrontShell({ children }: Readonly<{ children: React.ReactNode }>) {
  return <><StorefrontHeader />{children}<StorefrontFooter /><StorefrontBottomNav /><MarketingPushPrompt /><PromotionalPopup /></>;
}
