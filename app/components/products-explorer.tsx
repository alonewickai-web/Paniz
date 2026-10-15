"use client";

import Link from "next/link";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { useEffect, useMemo, useState } from "react";
import { ChevronDown, ChevronUp, Search, SlidersHorizontal, X } from "lucide-react";
import { StorefrontShell } from "./storefront-shell";
import { StoreProductCard } from "./store-product-card";
import { StoreDropdown } from "./store-dropdown";
import { apiBaseUrl, type ProductListPayload, type StoreCategory, type StoreProduct } from "../lib/catalog";
import { ProductSearchAutocomplete } from "./product-search-autocomplete";

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

function normalizePrice(value: string) {
  return value
    .replace(/[۰-۹٠-٩]/g, (digit) => {
      const code = digit.charCodeAt(0);
      return String(code - (code >= 0x06f0 ? 0x06f0 : 0x0660));
    })
    .replace(/\D/g, "");
}

function formatPrice(value: string) {
  return value.replace(/\B(?=(\d{3})+(?!\d))/g, ",");
}

function readFilters(params: URLSearchParams): Filters {
  return {
    q: params.get("q") ?? "",
    category: params.get("category") ?? "",
    minPrice: normalizePrice(params.get("minPrice") ?? ""),
    maxPrice: normalizePrice(params.get("maxPrice") ?? ""),
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
        query.set("pageSize", "20");
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

  function change<K extends keyof Filters>(key: K, value: Filters[K]) {
    setFilters((current) => ({ ...current, [key]: value, ...(key === "page" ? {} : { page: 1 }) }));
  }

  function changePrice(key: "minPrice" | "maxPrice", input: HTMLInputElement) {
    const digits = normalizePrice(input.value);
    const selectionStart = input.selectionStart ?? input.value.length;
    const digitsBeforeCursor = normalizePrice(input.value.slice(0, selectionStart)).length;
    change(key, digits);

    window.requestAnimationFrame(() => {
      let cursor = 0;
      let digitsSeen = 0;
      const formatted = formatPrice(digits);
      while (cursor < formatted.length && digitsSeen < digitsBeforeCursor) {
        if (/\d/.test(formatted[cursor])) digitsSeen += 1;
        cursor += 1;
      }
      input.setSelectionRange(cursor, cursor);
    });
  }

  function stepPrice(key: "minPrice" | "maxPrice", delta: 100_000 | -100_000) {
    const current = filters[key];
    if (!current && delta < 0) return;
    const next = Math.max(0, Math.min(Number.MAX_SAFE_INTEGER, Number(current || "0") + delta));
    change(key, String(Math.trunc(next)));
  }

  function clearFilters() {
    setFilters({ q: "", category: "", minPrice: "", maxPrice: "", size: "", color: "", inStock: false, onSale: false, sort: "newest", page: 1 });
  }

  const hasFilters = Boolean(filters.q || filters.category || filters.minPrice || filters.maxPrice || filters.size || filters.color || filters.inStock || filters.onSale);
  const categoryOptions = categories.flatMap((category) => [category, ...(category.children ?? [])]);
  const categoryFilterOptions = [{ value: "", label: "همهٔ دسته‌ها" }, ...categoryOptions.map((category) => ({ value: category.slug, label: category.name }))];
  const sortOptions = [
    { value: "newest", label: "جدیدترین" },
    { value: "price-asc", label: "ارزان‌ترین" },
    { value: "price-desc", label: "گران‌ترین" },
  ];

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
              <div className="store-field">
                <span>دسته‌بندی</span>
                <StoreDropdown id="store-category" label="دسته‌بندی" value={filters.category} options={categoryFilterOptions} onChange={(value) => change("category", value)} />
              </div>
              <fieldset className="store-filter-group"><legend>بازهٔ قیمت <small>(تومان)</small></legend><div className="store-price-fields"><label><span className="sr-only">حداقل قیمت</span><div className="store-price-input"><input inputMode="numeric" type="text" placeholder="از" value={formatPrice(filters.minPrice)} onChange={(event) => changePrice("minPrice", event.currentTarget)} /><span className="store-price-stepper"><button type="button" aria-label="افزایش حداقل قیمت، ۱۰۰ هزار تومان" onClick={() => stepPrice("minPrice", 100_000)}><ChevronUp size={13} /></button><button type="button" aria-label="کاهش حداقل قیمت، ۱۰۰ هزار تومان" onClick={() => stepPrice("minPrice", -100_000)}><ChevronDown size={13} /></button></span></div></label><label><span className="sr-only">حداکثر قیمت</span><div className="store-price-input"><input inputMode="numeric" type="text" placeholder="تا" value={formatPrice(filters.maxPrice)} onChange={(event) => changePrice("maxPrice", event.currentTarget)} /><span className="store-price-stepper"><button type="button" aria-label="افزایش حداکثر قیمت، ۱۰۰ هزار تومان" onClick={() => stepPrice("maxPrice", 100_000)}><ChevronUp size={13} /></button><button type="button" aria-label="کاهش حداکثر قیمت، ۱۰۰ هزار تومان" onClick={() => stepPrice("maxPrice", -100_000)}><ChevronDown size={13} /></button></span></div></label></div></fieldset>
              <label className="store-field"><span>سایز</span><input value={filters.size} placeholder="مثلاً M یا ۳۸" onChange={(event) => change("size", event.target.value)} /></label>
              <label className="store-field"><span>رنگ</span><input value={filters.color} placeholder="مثلاً یاسی" onChange={(event) => change("color", event.target.value)} /></label>
              <label className="store-check"><input type="checkbox" checked={filters.inStock} onChange={(event) => change("inStock", event.target.checked)} /><span>فقط کالاهای موجود</span></label>
              <label className="store-check"><input type="checkbox" checked={filters.onSale} onChange={(event) => change("onSale", event.target.checked)} /><span>فقط تخفیف‌دارها</span></label>
            </aside>

            <section className="store-catalog-results" aria-label="فهرست محصولات">
              <div className="store-results-toolbar">
                <span>{loading ? "در حال به‌روزرسانی…" : `${new Intl.NumberFormat("fa-IR").format(total)} انتخاب برای تو`}</span>
                <StoreDropdown id="catalog-sort" label="مرتب‌سازی" value={filters.sort} options={sortOptions} onChange={(value) => change("sort", value)} compact leadingIcon={<SlidersHorizontal size={16} aria-hidden="true" />} />
              </div>
              <ProductSearchAutocomplete
                id="catalog-search"
                variant="catalog"
                wrapperClassName="store-search-wrap"
                value={filters.q}
                onChange={(value) => change("q", value)}
                placeholder="نام، دسته یا کد محصول"
                clearable
              />

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
