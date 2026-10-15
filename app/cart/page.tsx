"use client";

import Link from "next/link";
import { useEffect, useMemo, useState } from "react";
import { ArrowLeft, Minus, Plus, ShoppingBag, Trash2 } from "lucide-react";
import { StorefrontShell } from "../components/storefront-shell";
import { apiBaseUrl, formatToman, type StoreProductDetail } from "../lib/catalog";
import { useStorefront } from "../lib/storefront-state";
import { StoreImage } from "../components/store-image";

type Quote = { items: { variantId: string; productName: string; unitPriceToman: number; lineTotalToman: number; quantity: number }[]; subtotalToman: number; shippingToman: number | null; shippingLabel: string | null; totalToman: number | null };

export default function CartPage() {
  const { cart, setCart, ready } = useStorefront();
  const [catalog, setCatalog] = useState<Record<string, StoreProductDetail>>({});
  const [quote, setQuote] = useState<Quote | null>(null);
  const [quoteError, setQuoteError] = useState("");
  const [loading, setLoading] = useState(false);
  const cartPayload = useMemo(() => JSON.stringify(cart.map((line) => ({ variantId: line.variantId, quantity: line.quantity }))), [cart]);
  const productSlugsKey = useMemo(() => JSON.stringify([...new Set(cart.map((line) => line.productSlug).filter((slug): slug is string => Boolean(slug)))]), [cart]);
  const quoteByVariant = useMemo(() => new Map((quote?.items ?? []).map((item) => [item.variantId, item])), [quote]);

  useEffect(() => {
    if (!ready || !productSlugsKey || productSlugsKey === "[]") return;
    const controller = new AbortController();
    const slugs = JSON.parse(productSlugsKey) as string[];
    void Promise.all(slugs.map(async (slug) => {
      try {
        const response = await fetch(`${apiBaseUrl()}/products/${encodeURIComponent(slug)}`, { signal: controller.signal, cache: "no-store" });
        if (!response.ok) return null;
        const payload = await response.json() as { data?: StoreProductDetail };
        return payload.data ?? null;
      } catch { return null; }
    })).then((items) => {
      if (controller.signal.aborted) return;
      const fetched = Object.fromEntries(items.filter((item): item is StoreProductDetail => Boolean(item)).map((item) => [item.slug, item]));
      setCatalog((current) => ({ ...current, ...fetched }));
    });
    return () => controller.abort();
  }, [productSlugsKey, ready]);

  useEffect(() => {
    if (!ready || !cart.length) { setQuote(null); setQuoteError(""); setLoading(false); return; }
    const controller = new AbortController();
    const items = cart.map((line) => ({ variantId: line.variantId, quantity: line.quantity }));
    if (items.some((item) => !item.variantId)) {
      setQuoteError("یکی از انتخاب‌های سبد قدیمی است؛ آن را حذف و دوباره انتخاب کن.");
      setLoading(false);
      return () => controller.abort();
    }
    setLoading(true);
    setQuoteError("");
    const debounceId = window.setTimeout(() => {
      fetch(`${apiBaseUrl()}/checkout/quote`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ items }),
        signal: controller.signal,
        cache: "no-store",
      }).then(async (response) => {
        const payload = await response.json();
        if (!response.ok) throw new Error(readError(payload));
        setQuote(payload.data as Quote);
      }).catch((error: unknown) => {
        if (!controller.signal.aborted) {
          setQuoteError(error instanceof Error ? error.message : "بررسی سبد خرید انجام نشد.");
          setQuote(null);
        }
      }).finally(() => { if (!controller.signal.aborted) setLoading(false); });
    }, 120);
    return () => { window.clearTimeout(debounceId); controller.abort(); };
  }, [cartPayload, ready]);

  function changeQuantity(key: string, amount: number) {
    setCart((items) => items.map((line) => {
      if (line.key !== key) return line;
      const product = catalog[line.productSlug ?? ""];
      const variant = product?.variants.find((item) => item.id === line.variantId);
      const availableQuantity = variant?.availableQuantity;
      if (amount > 0) {
        const maxQuantity = availableQuantity === undefined ? 0 : Math.min(10, availableQuantity);
        if (availableQuantity === undefined || line.quantity >= maxQuantity) {
          return line;
        }
        return {
          ...line,
          quantity: Math.min(line.quantity + amount, maxQuantity),
        };
      }
      return {
        ...line,
        quantity: Math.max(1, line.quantity + amount),
      };
    }));
  }

  function removeLine(key: string) {
    setCart((items) => items.filter((line) => line.key !== key));
  }

  const subtotal = cart.reduce((sum, line) => sum + (quoteByVariant.get(line.variantId ?? "")?.unitPriceToman ?? line.unitPrice ?? 0) * line.quantity, 0);

  return (
    <StorefrontShell>
      <main className="store-page">
        <div className="page-shell">
          <nav className="store-breadcrumb" aria-label="مسیر صفحه"><Link href="/">خانه</Link><span>/</span><span>سبد خرید</span></nav>
          <div className="store-page-heading"><div><span className="section-kicker">انتخاب‌های قشنگت</span><h1>سبد خرید</h1><p>رنگ، سایز و تعداد انتخاب‌هایت را بررسی کن.</p></div><span className="store-result-count">{new Intl.NumberFormat("fa-IR").format(cart.reduce((sum, line) => sum + line.quantity, 0))} کالا</span></div>
          {!ready ? <div className="store-message">در حال آماده‌کردن سبد خرید…</div> : !cart.length ? <div className="store-empty-page"><span><ShoppingBag size={32} /></span><h2>سبدت هنوز خالیه</h2><p>از بین لباس‌های پانیذ یک انتخاب دوست‌داشتنی پیدا کن.</p><Link className="button-primary" href="/products">دیدن محصولات <ArrowLeft size={17} /></Link></div> : (
            <div className="store-cart-layout">
              <section className="store-cart-lines" aria-label="اقلام سبد خرید">
                {cart.map((line) => {
                  const product = catalog[line.productSlug ?? ""];
                  const quoted = quoteByVariant.get(line.variantId ?? "");
                  const variant = product?.variants.find((item) => item.id === line.variantId);
                  const colorImage = product?.images.find((image) => image.colorName && normalizeColorName(image.colorName) === normalizeColorName(line.color));
                  const fallbackImage = product?.images.find((image) => !image.colorName?.trim()) ?? product?.image;
                  const cartImage = colorImage ?? fallbackImage;
                  return <article className="store-cart-line" key={line.key}>
                    <Link className="store-cart-image" href={product ? `/products/${product.slug}` : "/products"}>
                      {cartImage ? <StoreImage src={cartImage.path} alt={cartImage.alt || `${product?.name ?? "محصول"}، رنگ ${line.color}`} fill sizes="120px" /> : <span>تصویر</span>}
                    </Link>
                    <div className="store-cart-line-info">
                      <Link href={product ? `/products/${product.slug}` : "/products"}><strong>{product?.name || quoted?.productName || "محصول انتخاب‌شده"}</strong></Link>
                      <span>{line.color} · سایز {line.size}{variant?.availableQuantity !== undefined && variant.availableQuantity < 4 ? ` · موجودی ${new Intl.NumberFormat("fa-IR").format(variant.availableQuantity)}` : ""}</span>
                      <b>{formatToman(quoted?.unitPriceToman ?? line.unitPrice ?? 0)}</b>
                      <div className="store-quantity"><button type="button" onClick={() => changeQuantity(line.key, -1)} disabled={line.quantity <= 1} aria-label="کم‌کردن تعداد"><Minus size={15} /></button><span>{new Intl.NumberFormat("fa-IR").format(line.quantity)}</span><button type="button" onClick={() => changeQuantity(line.key, 1)} disabled={!variant || line.quantity >= Math.min(10, variant.availableQuantity)} aria-label="زیادکردن تعداد"><Plus size={15} /></button></div>
                    </div>
                    <strong className="store-cart-line-total">{formatToman((quoted?.unitPriceToman ?? line.unitPrice ?? 0) * line.quantity)}</strong>
                    <button className="store-remove-line" type="button" onClick={() => removeLine(line.key)} aria-label="حذف از سبد"><Trash2 size={18} /></button>
                  </article>;
                })}
                {quoteError && <p className="store-inline-error" role="alert">{quoteError}</p>}
              </section>

              <aside className="store-order-summary">
                <h2>خلاصهٔ سفارش</h2>
                <div><span>جمع کالاها</span><strong>{formatToman(subtotal)}</strong></div>
                <div><span>{quote?.shippingLabel || "هزینهٔ ارسال"}</span><strong>{quote ? quote.shippingToman === null ? "تنظیم نشده" : quote.shippingToman === 0 ? "رایگان" : formatToman(quote.shippingToman) : loading ? "در حال محاسبه…" : "—"}</strong></div>
                <p>هزینهٔ ارسال بر اساس تنظیمات فروشگاه در همین سبد محاسبه و در تسویه‌حساب دوباره بررسی می‌شود.</p>
                <Link className="button-primary" href="/checkout" aria-disabled={Boolean(quoteError || loading || !quote)} onClick={(event) => { if (quoteError || loading || !quote) event.preventDefault(); }}>ادامه به تسویه‌حساب <ArrowLeft size={17} /></Link>
                {loading && <small className="store-loading-note">در حال بررسی قیمت و موجودی…</small>}
                <Link className="store-back-link" href="/products">ادامهٔ خرید</Link>
              </aside>
            </div>
          )}
        </div>
      </main>
    </StorefrontShell>
  );
}

function normalizeColorName(value: string) {
  return value.normalize("NFKC").replace(/[يى]/g, "ی").replace(/ك/g, "ک").trim().replace(/\s+/g, " ");
}

function readError(payload: unknown): string {
  if (payload && typeof payload === "object") {
    const value = payload as { message?: string | string[]; error?: { message?: string } };
    if (typeof value.message === "string") return value.message;
    if (Array.isArray(value.message)) return value.message.join("، ");
    if (value.error?.message) return value.error.message;
  }
  return "قیمت یا موجودی یکی از کالاها تغییر کرده؛ سبد را بررسی کن.";
}
