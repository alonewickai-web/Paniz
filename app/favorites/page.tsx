"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { Heart } from "lucide-react";
import { StorefrontShell } from "../components/storefront-shell";
import { StoreProductCard } from "../components/store-product-card";
import { apiBaseUrl, type ProductListPayload, type StoreProduct } from "../lib/catalog";
import { useStorefront } from "../lib/storefront-state";

export default function FavoritesPage() {
  const { favorites, setFavorites, ready } = useStorefront();
  const [catalog, setCatalog] = useState<StoreProduct[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const controller = new AbortController();
    fetch(`${apiBaseUrl()}/products?page=1&pageSize=48`, { signal: controller.signal, cache: "no-store" })
      .then((response) => response.ok ? response.json() as Promise<ProductListPayload> : Promise.reject())
      .then((payload) => setCatalog(payload.data ?? []))
      .catch(() => undefined)
      .finally(() => { if (!controller.signal.aborted) setLoading(false); });
    return () => controller.abort();
  }, []);

  const products = catalog.filter((product) => favorites.includes(Number(product.id)));

  return (
    <StorefrontShell>
      <main className="store-page"><div className="page-shell">
        <nav className="store-breadcrumb" aria-label="مسیر صفحه"><Link href="/">خانه</Link><span>/</span><span>علاقه‌مندی‌ها</span></nav>
        <div className="store-page-heading"><div><span className="section-kicker">انتخاب‌های ذخیره‌شده</span><h1>علاقه‌مندی‌های من</h1><p>محصولات محبوبت روی همین دستگاه نگهداری می‌شوند.</p></div>{products.length > 0 && <button className="store-clear-favorites" onClick={() => setFavorites([])}>پاک‌کردن همه</button>}</div>
        {!ready || loading ? <div className="store-message">در حال بارگذاری علاقه‌مندی‌ها…</div> : products.length ? <div className="product-grid store-product-grid">{products.map((product) => <StoreProductCard key={product.id} product={product} />)}</div> : <div className="store-empty-page"><span><Heart size={30} /></span><h2>هنوز چیزی ذخیره نکردی</h2><p>روی قلب هر محصول بزن تا بعداً راحت پیدایش کنی.</p><Link className="button-primary" href="/products">گشتن در محصولات</Link></div>}
      </div></main>
    </StorefrontShell>
  );
}
