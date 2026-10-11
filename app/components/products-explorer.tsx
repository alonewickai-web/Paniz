"use client";

import Link from "next/link";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { useEffect, useMemo, useState } from "react";
import { Search, SlidersHorizontal, X } from "lucide-react";
import { StorefrontShell } from "./storefront-shell";
import { StoreProductCard } from "./store-product-card";
import { apiBaseUrl, productImage, type ProductListPayload, type StoreCategory, type StoreProduct } from "../lib/catalog";
import { StoreImage } from "./store-image";

type Filters = {
  q: string;
  category: string;
  minPrice: string;
  maxPrice: string;
  size: string;
  color: string;
  inStock: boolean;
  onSale: boolean;
  sort: string;
  page: number;
};

function readFilters(params: URLSearchParams): Filters {
  return {
    q: params.get("q") ?? "",
    category: params.get("category") ?? "",
    minPrice: params.get("minPrice") ?? "",
    maxPrice: params.get("maxPrice") ?? "",
    size: params.get("size") ?? "",
    color: params.get("color") ?? "",
    inStock: params.get("inStock") === "true",
    onSale: params.get("onSale") === "true",
    sort: params.get("sort") ?? "newest",
    page: Math.max(1, Number(params.get("page") ?? 1) || 1),
  };
}

function serializeFilters(filters: Filters) {
  const params = new URLSearchParams();
  for (const key of ["q", "category", "minPrice", "maxPrice", "size", "color"] as const) {
    if (filters[key].trim()) params.set(key, filters[key].trim());
  }
  if (filters.inStock) params.set("inStock", "true");
  if (filters.onSale) params.set("onSale", "true");
  if (filters.sort !== "newest") params.set("sort", filters.sort);
  if (filters.page > 1) params.set("page", String(filters.page));
  return params.toString();
}

export function ProductsExplorer() {
  const searchParams = useSearchParams();
  const router = useRouter();
  const pathname = usePathname();
  const [filters, setFilters] = useState<Filters>(() => readFilters(new URLSearchParams(searchParams.toString())));
  const [products, setProducts] = useState<StoreProduct[]>([]);
  const [categories, setCategories] = useState<StoreCategory[]>([]);
  const [total, setTotal] = useState(0);
  const [totalPages, setTotalPages] = useState(1);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [reloadKey, setReloadKey] = useState(0);
  const [suggestions, setSuggestions] = useState<StoreProduct[]>([]);
  const [searchFocused, setSearchFocused] = useState(false);
  const queryString = useMemo(() => serializeFilters(filters), [filters]);

  useEffect(() => {
    setFilters(readFilters(new URLSearchParams(searchParams.toString())));
  }, [searchParams]);

  useEffect(() => {
    router.replace(queryString ? `${pathname}?${queryString}` : pathname, { scroll: false });
  }, [pathname, queryString, router]);

  useEffect(() => {
    const controller = new AbortController();
    const timer = window.setTimeout(async () => {
      setLoading(true);
      setError("");
      try {
        const query = new URLSearchParams(queryString);
        query.set("pageSize", "12");
        const response = await fetch(`${apiBaseUrl()}/products?${query}`, { signal: controller.signal, cache: "no-store" });
        if (!response.ok) throw new Error("فهرست محصولات در دسترس نیست.");
        const payload = await response.json() as ProductListPayload;
        setProducts(payload.data);
        setTotal(payload.meta.total);
        setTotalPages(Math.max(1, payload.meta.totalPages));
      } catch (reason) {
        if (!controller.signal.aborted) setError(reason instanceof Error ? reason.message : "خطا در دریافت محصولات.");
      } finally {
        if (!controller.signal.aborted) setLoading(false);
      }
    }, 160);
    return () => { controller.abort(); window.clearTimeout(timer); };
  }, [queryString, reloadKey]);

  useEffect(() => {
    const controller = new AbortController();
    fetch(`${apiBaseUrl()}/categories`, { signal: controller.signal, cache: "no-store" })
      .then((response) => response.ok ? response.json() : Promise.reject())
      .then((payload: { data?: StoreCategory[] }) => setCategories(payload.data ?? []))
      .catch(() => undefined);
    return () => controller.abort();
  }, []);

  useEffect(() => {
    const term = filters.q.trim();
    if (!searchFocused || term.length < 2) {
      setSuggestions([]);
      return;
    }
    const controller = new AbortController();
    const timer = window.setTimeout(() => {
      const query = new URLSearchParams({ q: term, page: "1", pageSize: "5" });
      fetch(`${apiBaseUrl()}/products?${query}`, { signal: controller.signal, cache: "no-store" })
        .then((response) => response.ok ? response.json() : Promise.reject())
        .then((payload: ProductListPayload) => setSuggestions(payload.data ?? []))
        .catch(() => setSuggestions([]));
    }, 220);
    return () => { controller.abort(); window.clearTimeout(timer); };
  }, [filters.q, searchFocused]);

  function change<K extends keyof Filters>(key: K, value: Filters[K]) {
    setFilters((current) => ({ ...current, [key]: value, ...(key === "page" ? {} : { page: 1 }) }));
  }

  function clearFilters() {
    setFilters({ q: "", category: "", minPrice: "", maxPrice: "", size: "", color: "", inStock: false, onSale: false, sort: "newest", page: 1 });
  }

  const hasFilters = Boolean(filters.q || filters.category || filters.minPrice || filters.maxPrice || filters.size || filters.color || filters.inStock || filters.onSale);
  const categoryOptions = categories.flatMap((category) => [category, ...(category.children ?? [])]);

  return (
    <StorefrontShell>
      <main className="store-page">
        <div className="page-shell">
          <nav className="store-breadcrumb" aria-label="مسیر صفحه"><Link href="/">خانه</Link><span>/</span><span>محصولات</span></nav>
          <div className="store-page-heading">
            <div><span className="section-kicker">کالکشن پانیذ</span><h1>لباسِ حال خوبت رو پیدا کن</h1><p>مدل، رنگ و سایزی رو که دوست داری انتخاب کن.</p></div>
            <span className="store-result-count">{new Intl.NumberFormat("fa-IR").format(total)} محصول</span>
          </div>

          <div className="store-catalog-layout">
            <aside className="store-filter-panel" aria-label="فیلتر محصولات">
              <div className="store-filter-title"><strong><SlidersHorizontal size={17} /> فیلترها</strong>{hasFilters && <button onClick={clearFilters}>پاک‌کردن</button>}</div>
              <label className="store-field"><span>دسته‌بندی</span><select value={filters.category} onChange={(event) => change("category", event.target.value)}><option value="">همهٔ دسته‌ها</option>{categoryOptions.map((category) => <option key={category.slug} value={category.slug}>{category.name}</option>)}</select></label>
              <fieldset className="store-filter-group"><legend>بازهٔ قیمت <small>(تومان)</small></legend><div className="store-price-fields"><label><span className="sr-only">حداقل قیمت</span><input inputMode="numeric" type="number" min="0" placeholder="از" value={filters.minPrice} onChange={(event) => change("minPrice", event.target.value)} /></label><label><span className="sr-only">حداکثر قیمت</span><input inputMode="numeric" type="number" min="0" placeholder="تا" value={filters.maxPrice} onChange={(event) => change("maxPrice", event.target.value)} /></label></div></fieldset>
              <label className="store-field"><span>سایز</span><input value={filters.size} placeholder="مثلاً M یا ۳۸" onChange={(event) => change("size", event.target.value)} /></label>
              <label className="store-field"><span>رنگ</span><input value={filters.color} placeholder="مثلاً یاسی" onChange={(event) => change("color", event.target.value)} /></label>
              <label className="store-check"><input type="checkbox" checked={filters.inStock} onChange={(event) => change("inStock", event.target.checked)} /><span>فقط کالاهای موجود</span></label>
              <label className="store-check"><input type="checkbox" checked={filters.onSale} onChange={(event) => change("onSale", event.target.checked)} /><span>فقط تخفیف‌دارها</span></label>
            </aside>

            <section className="store-catalog-results" aria-label="فهرست محصولات">
              <div className="store-results-toolbar">
                <span>{loading ? "در حال به‌روزرسانی…" : `${new Intl.NumberFormat("fa-IR").format(total)} انتخاب برای تو`}</span>
                <label className="sort-control"><SlidersHorizontal size={16} /><span className="sr-only">مرتب‌سازی</span><select value={filters.sort} onChange={(event) => change("sort", event.target.value)}><option value="newest">جدیدترین</option><option value="price-asc">ارزان‌ترین</option><option value="price-desc">گران‌ترین</option></select></label>
              </div>
              <div className="store-search-wrap">
                <label className="store-search-field"><Search size={18} /><span className="sr-only">جست‌وجو در محصولات</span><input value={filters.q} onFocus={() => setSearchFocused(true)} onBlur={() => window.setTimeout(() => setSearchFocused(false), 140)} onChange={(event) => change("q", event.target.value)} placeholder="نام، دسته یا کد محصول" /><button type="button" onClick={() => change("q", "")} aria-label="پاک‌کردن جست‌وجو"><X size={16} /></button></label>
                {searchFocused && suggestions.length > 0 && <div className="store-suggestions" role="listbox" aria-label="پیشنهادهای جست‌وجو">{suggestions.map((product) => <Link role="option" key={product.id} href={`/products/${product.slug}`} onMouseDown={(event) => event.preventDefault()}><span className="store-suggestion-image"><StoreImage src={productImage(product)} alt="" fill sizes="48px" /></span><span><strong>{product.name}</strong><small>{product.priceToman === null ? "قیمت نامشخص" : `${new Intl.NumberFormat("fa-IR").format(product.priceToman)} تومان`}</small></span></Link>)}</div>}
              </div>

              {hasFilters && <div className="store-active-filters"><span>فیلترهای فعال:</span>{filters.category && <button onClick={() => change("category", "")}>{categoryOptions.find((item) => item.slug === filters.category)?.name ?? filters.category}<X size={13} /></button>}{filters.size && <button onClick={() => change("size", "")}>سایز {filters.size}<X size={13} /></button>}{filters.color && <button onClick={() => change("color", "")}>{filters.color}<X size={13} /></button>}{filters.inStock && <button onClick={() => change("inStock", false)}>موجود <X size={13} /></button>}{filters.onSale && <button onClick={() => change("onSale", false)}>تخفیف‌دار <X size={13} /></button>}</div>}

              {error ? <div className="store-message store-error" role="alert"><strong>فعلاً نتوانستیم محصولات را بگیریم.</strong><span>{error}</span><button className="outline-button" onClick={() => setReloadKey((current) => current + 1)}>تلاش دوباره</button></div>
                : loading ? <div className="product-grid store-product-grid" aria-busy="true" aria-label="بارگذاری محصولات">{Array.from({ length: 6 }, (_, index) => <div className="store-product-skeleton" key={index}><div /><span /><span /></div>)}</div>
                : products.length ? <div className="product-grid store-product-grid">{products.map((product) => <StoreProductCard key={product.id} product={product} />)}</div>
                : <div className="empty-state store-empty"><Search size={28} /><strong>چیزی پیدا نکردیم</strong><span>عبارت جست‌وجو یا فیلترها را تغییر بده.</span><button onClick={clearFilters}>نمایش همهٔ محصولات</button></div>}

              {!loading && !error && totalPages > 1 && <nav className="store-pagination" aria-label="صفحه‌بندی">{Array.from({ length: totalPages }, (_, index) => index + 1).map((page) => <button key={page} aria-current={page === filters.page ? "page" : undefined} className={page === filters.page ? "active" : ""} onClick={() => change("page", page)}>{new Intl.NumberFormat("fa-IR").format(page)}</button>)}</nav>}
            </section>
          </div>
        </div>
      </main>
    </StorefrontShell>
  );
}
