"use client";

import Link from "next/link";
import { useMemo, useState } from "react";
import { Check, Heart, Minus, Plus, Share2, ShieldCheck, ShoppingBag, Truck } from "lucide-react";
import { StoreProductCard } from "./store-product-card";
import { apiBaseUrl, formatToman, type StoreProduct, type StoreProductDetail } from "../lib/catalog";
import { useStorefront } from "../lib/storefront-state";
import { StoreImage } from "./store-image";

export function ProductDetailView({ product }: { product: StoreProductDetail }) {
  const { cart, setCart, favorites, setFavorites } = useStorefront();
  const productId = Number(product.id);
  const availableVariants = product.variants.filter((variant) => variant.availableQuantity > 0);
  const initial = availableVariants[0] ?? product.variants[0];
  const [color, setColor] = useState(initial?.color.name ?? product.colors[0]?.name ?? "");
  const [size, setSize] = useState(initial?.size ?? "");
  const [quantity, setQuantity] = useState(1);
  const [imageIndex, setImageIndex] = useState(0);
  const [notice, setNotice] = useState("");
  const [isSharing, setIsSharing] = useState(false);
  const [related, setRelated] = useState<StoreProduct[]>([]);
  const [relatedLoaded, setRelatedLoaded] = useState(false);

  const variant = product.variants.find((item) => item.color.name === color && item.size === size);
  const stock = variant?.availableQuantity ?? 0;
  const currentImages = product.images.length ? product.images : product.image ? [{ id: "primary", path: product.image.path, alt: product.image.alt, isPrimary: true }] : [];
  const mainImage = currentImages[Math.min(imageIndex, Math.max(currentImages.length - 1, 0))];
  const favorite = favorites.includes(productId);
  const discount = variant?.compareAtPriceToman && variant.priceToman
    ? Math.round((1 - variant.priceToman / variant.compareAtPriceToman) * 100)
    : 0;
  const sizeGuideRows = useMemo(() => readSizeGuide(product.sizeGuide), [product.sizeGuide]);

  async function addToCart() {
    if (!variant || stock < quantity) {
      setNotice("این ترکیب رنگ و سایز به تعداد انتخاب‌شده موجود نیست.");
      return;
    }
    if (!Number.isSafeInteger(productId)) {
      setNotice("شناسهٔ این محصول برای افزودن به سبد معتبر نیست.");
      return;
    }
    const key = variant.id;
    const current = cart.find((line) => line.key === key);
    if (current && current.quantity + quantity > stock) {
      setNotice("تعداد درخواستی از موجودی این تنوع بیشتر است.");
      return;
    }
    setCart((items) => current
      ? items.map((line) => line.key === key ? { ...line, quantity: line.quantity + quantity } : line)
      : [...items, {
          key,
          productId,
          productSlug: product.slug,
          variantId: variant.id,
          size: variant.size,
          color: variant.color.name,
          quantity,
          unitPrice: variant.priceToman,
        }]);
    setNotice("به سبد خرید اضافه شد.");
  }

  async function shareProduct() {
    setIsSharing(true);
    try {
      if (navigator.share) await navigator.share({ title: product.name, url: window.location.href });
      else {
        await navigator.clipboard.writeText(window.location.href);
        setNotice("پیوند محصول کپی شد.");
      }
    } catch {
      setNotice("اشتراک‌گذاری انجام نشد.");
    } finally {
      setIsSharing(false);
    }
  }

  function toggleFavorite() {
    if (!Number.isSafeInteger(productId)) return;
    setFavorites((items) => favorite ? items.filter((id) => id !== productId) : [...items, productId]);
  }

  async function loadRelated() {
    if (relatedLoaded || !product.category?.slug) return;
    setRelatedLoaded(true);
    try {
      const query = new URLSearchParams({ category: product.category.slug, pageSize: "4" });
      const response = await fetch(`${apiBaseUrl()}/products?${query}`, { cache: "no-store" });
      if (!response.ok) return;
      const payload = await response.json() as { data?: StoreProduct[] };
      setRelated((payload.data ?? []).filter((item) => item.id !== product.id).slice(0, 4));
    } catch { /* related suggestions are optional */ }
  }

  const materials = [
    ["جنس پارچه", product.material],
    ["روش نگهداری", product.careInstructions],
  ].filter((row): row is [string, string] => Boolean(row[1]));

  return (
    <main className="store-page store-product-page">
      <div className="page-shell">
        <nav className="store-breadcrumb" aria-label="مسیر صفحه"><Link href="/">خانه</Link><span>/</span><Link href={`/products${product.category ? `?category=${product.category.slug}` : ""}`}>{product.category?.name ?? "محصولات"}</Link><span>/</span><span>{product.name}</span></nav>
        <div className="store-product-detail-grid">
          <section className="store-gallery" aria-label="تصاویر محصول">
            <div className="store-main-image">
              {mainImage ? <StoreImage src={mainImage.path} alt={mainImage.alt || product.name} fill priority sizes="(max-width: 760px) 100vw, 54vw" /> : <div className="store-no-image">تصویر محصول</div>}
              {discount > 0 && <span className="store-detail-sale">{new Intl.NumberFormat("fa-IR").format(discount)}٪ تخفیف</span>}
            </div>
            {currentImages.length > 1 && <div className="store-thumbnails">{currentImages.map((image, index) => <button key={image.id} className={index === imageIndex ? "active" : ""} onClick={() => setImageIndex(index)} aria-label={`تصویر ${index + 1}`}><StoreImage src={image.path} alt={image.alt || product.name} fill sizes="84px" /></button>)}</div>}
          </section>

          <section className="store-product-info">
            <span className="section-kicker">{product.category?.name || "پوشاک زنانه"}</span>
            <h1>{product.name}</h1>
            <p className="store-product-lead">{product.shortDescription || "انتخابی راحت و دوست‌داشتنی از کالکشن پانیز."}</p>
            <div className="store-detail-price">
              <strong>{variant ? formatToman(variant.priceToman) : product.priceToman === null ? "قیمت نامشخص" : formatToman(product.priceToman)}</strong>
              {variant?.compareAtPriceToman && <del>{formatToman(variant.compareAtPriceToman)}</del>}
            </div>
            <div className="store-stock-line" role="status">{stock > 0 ? <><span className="store-stock-dot" /> {stock <= 3 ? `فقط ${new Intl.NumberFormat("fa-IR").format(stock)} عدد باقی مانده` : "موجود و آمادهٔ خرید"}</> : <><span className="store-stock-dot unavailable" /> این ترکیب موجود نیست</>}</div>

            <fieldset className="store-choice-group"><legend>رنگ <span>{color}</span></legend><div className="store-color-choices">{product.colors.map((item) => {
              const colorAvailable = product.variants.some((entry) => entry.color.name === item.name && entry.availableQuantity > 0);
              return <button key={item.name} type="button" disabled={!colorAvailable} className={`${color === item.name ? "active" : ""} ${!colorAvailable ? "unavailable" : ""}`} onClick={() => { setColor(item.name); const firstSize = product.variants.find((entry) => entry.color.name === item.name && entry.availableQuantity > 0)?.size ?? ""; setSize(firstSize); setQuantity(1); }} aria-label={`${item.name}${colorAvailable ? "" : "، ناموجود"}`} aria-pressed={color === item.name}><i style={{ background: item.value }} />{item.name}</button>;
            })}</div></fieldset>

            <fieldset className="store-choice-group"><legend>سایز <span>{size || "انتخاب کن"}</span></legend><div className="store-size-choices">{product.sizes.map((item) => {
              const itemAvailable = product.variants.some((entry) => entry.color.name === color && entry.size === item && entry.availableQuantity > 0);
              return <button key={item} type="button" disabled={!itemAvailable} className={size === item ? "active" : ""} onClick={() => { setSize(item); setQuantity(1); }} aria-pressed={size === item}>{item}</button>;
            })}</div>{sizeGuideRows.length > 0 && <div className="store-size-guide"><strong>راهنمای سایز</strong><div className="store-table-scroll"><table><thead><tr>{Object.keys(sizeGuideRows[0]).map((key) => <th key={key}>{key}</th>)}</tr></thead><tbody>{sizeGuideRows.map((row, index) => <tr key={index}>{Object.values(row).map((value, cell) => <td key={cell}>{String(value)}</td>)}</tr>)}</tbody></table></div></div>}</fieldset>

            <div className="store-buy-controls"><div className="store-quantity" aria-label="تعداد"><button type="button" onClick={() => setQuantity((value) => Math.max(1, value - 1))} disabled={quantity <= 1} aria-label="کم‌کردن تعداد"><Minus size={16} /></button><span>{new Intl.NumberFormat("fa-IR").format(quantity)}</span><button type="button" onClick={() => setQuantity((value) => Math.min(Math.max(1, stock), value + 1))} disabled={!stock || quantity >= stock} aria-label="زیادکردن تعداد"><Plus size={16} /></button></div><button className="button-primary store-add-button" type="button" onClick={addToCart} disabled={!variant || !stock}><ShoppingBag size={19} /> افزودن به سبد خرید</button></div>
            <div className="store-product-actions"><button type="button" onClick={toggleFavorite} aria-pressed={favorite}><Heart size={17} fill={favorite ? "currentColor" : "none"} />{favorite ? "ذخیره شد" : "افزودن به علاقه‌مندی‌ها"}</button><button type="button" onClick={shareProduct} disabled={isSharing}><Share2 size={17} />اشتراک محصول</button></div>
            {notice && <p className="store-inline-notice" role="status"><Check size={16} />{notice}</p>}
            <div className="store-service-notes"><div><Truck size={18} /><span><strong>هزینه و زمان ارسال</strong><small>پس از واردکردن نشانی در تسویه‌حساب مشخص می‌شود.</small></span></div><div><ShieldCheck size={18} /><span><strong>انتخاب مطمئن</strong><small>موجودی رنگ و سایز پیش از ثبت سفارش دوباره بررسی می‌شود.</small></span></div></div>

            <div className="store-detail-accordions">
              <details open><summary>توضیحات محصول</summary><p>{product.description || product.shortDescription || "جزئیات بیشتر این محصول به‌زودی از فروشگاه دریافت می‌شود."}</p></details>
              {materials.map(([title, value]) => <details key={title}><summary>{title}</summary><p>{value}</p></details>)}
              <details onToggle={(event) => { if ((event.currentTarget as HTMLDetailsElement).open) void loadRelated(); }}><summary>محصولات مشابه</summary>{related.length ? <div className="product-grid store-related-grid">{related.map((item) => <StoreProductCard key={item.id} product={item} />)}</div> : <p>محصول مشابهی برای نمایش پیدا نشد.</p>}</details>
              <details><summary>نظرات خریداران</summary><p>ثبت نظر بعد از خرید و ورود با شمارهٔ تأییدشده فعال می‌شود.</p></details>
            </div>
          </section>
        </div>
      </div>
    </main>
  );
}

function readSizeGuide(value: unknown): Record<string, string | number>[] {
  if (Array.isArray(value)) return value.filter(isGuideRow);
  if (value && typeof value === "object" && "rows" in value && Array.isArray((value as { rows?: unknown }).rows)) {
    return (value as { rows: unknown[] }).rows.filter(isGuideRow);
  }
  return [];
}

function isGuideRow(value: unknown): value is Record<string, string | number> {
  return Boolean(value && typeof value === "object" && Object.values(value).every((item) => typeof item === "string" || typeof item === "number"));
}
