"use client";

import Link from "next/link";
import { useEffect, useMemo, useRef, useState } from "react";
import { Bell, Check, ChevronLeft, ChevronRight, Heart, Minus, Plus, Share2, ShieldCheck, ShoppingBag, Truck } from "lucide-react";
import { StoreProductCard } from "./store-product-card";
import { StoreImage } from "./store-image";
import { apiBaseUrl, formatToman, type StoreProduct, type StoreProductDetail } from "../lib/catalog";
import { useStorefront } from "../lib/storefront-state";
import { PageFlipImage, type FlipImage } from "./page-flip-image";
import { CustomerApiError, customerApi } from "../lib/customer-api";
import { requestStorePush } from "../lib/customer-push";
import { trackGa4 } from "../lib/ga4";

export function ProductDetailView({ product }: { product: StoreProductDetail }) {
  const { cart, setCart, favorites, setFavorites } = useStorefront();
  const productId = Number(product.id);
  const availableVariants = product.variants.filter((variant) => variant.availableQuantity > 0);
  const initial = availableVariants[0] ?? product.variants[0];
  const initialColor = initial?.color.name ?? product.colors[0]?.name ?? "";
  const allImages = useMemo(() => product.images.length
    ? product.images
    : product.image ? [{ id: "primary", path: product.image.path, alt: product.image.alt, colorName: null, isPrimary: true }] : [], [product.image, product.images]);
  const initialColorImage = allImages.findIndex((image) => image.colorName && normalizeColorName(image.colorName) === normalizeColorName(initialColor));
  const firstGeneralImage = allImages.findIndex((image) => !image.colorName?.trim());
  const [color, setColor] = useState(initialColor);
  const [size, setSize] = useState(initial?.size ?? "");
  const [quantity, setQuantity] = useState(1);
  const [imageIndex, setImageIndex] = useState(initialColorImage >= 0 ? initialColorImage : firstGeneralImage);
  const [galleryDirection, setGalleryDirection] = useState<"next" | "previous">("next");
  const [galleryOutgoing, setGalleryOutgoing] = useState<FlipImage | null>(null);
  const [galleryHovered, setGalleryHovered] = useState(false);
  const [galleryFocused, setGalleryFocused] = useState(false);
  const [notice, setNotice] = useState("");
  const [isSharing, setIsSharing] = useState(false);
  const [subscribingStock, setSubscribingStock] = useState(false);
  const [stockSubscribed, setStockSubscribed] = useState(false);
  const [related, setRelated] = useState<StoreProduct[]>([]);
  const [relatedLoaded, setRelatedLoaded] = useState(false);
  const pointerStart = useRef<{ x: number; y: number } | null>(null);
  const galleryIndexRef = useRef(initialColorImage >= 0 ? initialColorImage : firstGeneralImage);
  const currentImages = useMemo(() => {
    const colorImages = allImages.filter((image) => image.colorName && normalizeColorName(image.colorName) === normalizeColorName(color));
    const generalImages = allImages.filter((image) => !image.colorName?.trim());
    if (colorImages.length) return [...colorImages, ...generalImages];
    if (generalImages.length) return generalImages;
    return allImages.some((image) => image.colorName?.trim()) ? [] : allImages;
  }, [allImages, color]);

  useEffect(() => {
    const initialImage = allImages.findIndex((image) => image.colorName && normalizeColorName(image.colorName) === normalizeColorName(initialColor));
    const generalImage = allImages.findIndex((image) => !image.colorName?.trim());
    const nextIndex = initialImage >= 0 ? initialImage : generalImage;
    setColor(initialColor);
    setSize(initial?.size ?? "");
    setImageIndex(nextIndex);
    galleryIndexRef.current = nextIndex;
    setGalleryOutgoing(null);
    setGalleryDirection("next");
    pointerStart.current = null;
  }, [allImages, initial?.size, initialColor, product.id]);

  useEffect(() => {
    if (currentImages.length < 2 || galleryHovered || galleryFocused) return;
    const timer = window.setInterval(() => {
      if (document.visibilityState !== "visible" || window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
      const currentImage = allImages[galleryIndexRef.current];
      if (!currentImage) return;
      const activePosition = currentImages.findIndex((image) => image.id === currentImage.id);
      if (activePosition < 0) return;
      const nextImage = currentImages[(activePosition + 1) % currentImages.length];
      if (!nextImage) return;
      const nextIndex = allImages.findIndex((image) => image.id === nextImage.id);
      setGalleryOutgoing({ src: currentImage.path, alt: currentImage.alt || product.name });
      setGalleryDirection("next");
      galleryIndexRef.current = nextIndex;
      setImageIndex(nextIndex);
    }, 5000);
    return () => window.clearInterval(timer);
  }, [allImages, currentImages, galleryFocused, galleryHovered, product.name]);

  useEffect(() => {
    if (!galleryOutgoing) return;
    const timer = window.setTimeout(() => setGalleryOutgoing(null), 820);
    return () => window.clearTimeout(timer);
  }, [galleryOutgoing]);

  useEffect(() => {
    galleryIndexRef.current = imageIndex;
  }, [imageIndex]);

  const variant = product.variants.find((item) => item.color.name === color && item.size === size);
  const stock = variant?.availableQuantity ?? 0;
  const maxOrderQuantity = Math.min(10, stock);
  useEffect(() => {
    const firstAvailable = product.variants.find((item) => item.availableQuantity > 0) ?? product.variants[0];
    if (!firstAvailable) return;
    trackGa4("view_item", {
      currency: "IRR",
      value: Math.round(firstAvailable.priceToman * 10),
      items: [{
        item_id: firstAvailable.sku || product.slug,
        item_name: product.name,
        item_category: product.category?.name,
        item_variant: `${firstAvailable.color.name} / ${firstAvailable.size}`,
        price: Math.round(firstAvailable.priceToman * 10),
      }],
    });
  }, [product]);
  const selectedGalleryImage = allImages[imageIndex];
  const imageHasDifferentColor = Boolean(selectedGalleryImage?.colorName?.trim()
    && normalizeColorName(selectedGalleryImage.colorName) !== normalizeColorName(color)
    && product.colors.some((item) => normalizeColorName(item.name) === normalizeColorName(selectedGalleryImage.colorName!)));
  const mainImage = selectedGalleryImage && !imageHasDifferentColor ? selectedGalleryImage : undefined;
  const favorite = favorites.includes(productId);
  const discount = variant?.compareAtPriceToman && variant.priceToman
    ? Math.round((1 - variant.priceToman / variant.compareAtPriceToman) * 100)
    : 0;
  const sizeGuideRows = useMemo(() => readSizeGuide(product.sizeGuide), [product.sizeGuide]);

  function showGalleryImage(nextIndex: number, direction: "next" | "previous") {
    const nextImage = allImages[nextIndex];
    if (!nextImage) return;
    if (mainImage) setGalleryOutgoing({ src: mainImage.path, alt: mainImage.alt || product.name });
    setGalleryDirection(direction);
    galleryIndexRef.current = nextIndex;
    setImageIndex(nextIndex);
    if (nextImage.colorName?.trim()) {
      const matchingColor = product.colors.find((item) => normalizeColorName(item.name) === normalizeColorName(nextImage.colorName!));
      if (matchingColor && normalizeColorName(matchingColor.name) !== normalizeColorName(color)) {
        setColor(matchingColor.name);
        const firstSize = product.variants.find((entry) => entry.color.name === matchingColor.name && entry.availableQuantity > 0)?.size
          ?? product.variants.find((entry) => entry.color.name === matchingColor.name)?.size ?? "";
        setSize(firstSize);
        setQuantity(1);
        setStockSubscribed(false);
      }
    }
  }

  function moveGallery(step: number) {
    if (allImages.length < 2) return;
    const currentIndex = galleryIndexRef.current;
    const nextIndex = currentIndex < 0
      ? (step > 0 ? 0 : allImages.length - 1)
      : (currentIndex + step + allImages.length) % allImages.length;
    showGalleryImage(nextIndex, step > 0 ? "next" : "previous");
  }

  function selectGalleryImage(nextIndex: number) {
    if (nextIndex === imageIndex) return;
    showGalleryImage(nextIndex, nextIndex > imageIndex ? "next" : "previous");
  }

  function selectColor(nextColor: string) {
    if (color === nextColor) return;
    const nextColorIndex = allImages.findIndex((image) => image.colorName && normalizeColorName(image.colorName) === normalizeColorName(nextColor));
    const generalIndex = allImages.findIndex((image) => !image.colorName?.trim());
    const nextIndex = nextColorIndex >= 0 ? nextColorIndex : generalIndex;
    if (mainImage) setGalleryOutgoing({ src: mainImage.path, alt: mainImage.alt || product.name });
    setGalleryDirection("next");
    galleryIndexRef.current = nextIndex;
    setImageIndex(nextIndex);
    setColor(nextColor);
    const firstSize = product.variants.find((entry) => entry.color.name === nextColor && entry.availableQuantity > 0)?.size
      ?? product.variants.find((entry) => entry.color.name === nextColor)?.size ?? "";
    setSize(firstSize);
    setQuantity(1);
    setStockSubscribed(false);
  }

  function finishGallerySwipe(x: number, y: number) {
    const start = pointerStart.current;
    pointerStart.current = null;
    if (!start) return;
    const dx = x - start.x;
    const dy = y - start.y;
    if (Math.abs(dx) < 45 || Math.abs(dx) < Math.abs(dy) * 1.2) return;
    moveGallery(dx < 0 ? 1 : -1);
  }

  async function addToCart() {
    if (!variant || maxOrderQuantity < quantity) {
      setNotice("این ترکیب رنگ و سایز به تعداد انتخاب‌شده موجود نیست.");
      return;
    }
    if (!Number.isSafeInteger(productId)) {
      setNotice("شناسهٔ این محصول برای افزودن به سبد معتبر نیست.");
      return;
    }
    const key = variant.id;
    const current = cart.find((line) => line.key === key);
    if (current && current.quantity + quantity > maxOrderQuantity) {
      setNotice("حداکثر تعداد قابل سفارش از این تنوع ۱۰ عدد یا موجودی انبار است.");
      return;
    }
    setCart((items) => {
      const existingLine = items.find((line) => line.key === key);
      if (existingLine) {
        if (existingLine.quantity + quantity > maxOrderQuantity) return items;
        return items.map((line) => line.key === key ? { ...line, quantity: line.quantity + quantity } : line);
      }
      return [...items, {
          key,
          productId,
          productSlug: product.slug,
          variantId: variant.id,
          size: variant.size,
          color: variant.color.name,
          quantity,
          unitPrice: variant.priceToman,
        }];
    });
    trackGa4("add_to_cart", {
      currency: "IRR",
      value: Math.round(variant.priceToman * quantity * 10),
      items: [{
        item_id: variant.sku || product.slug,
        item_name: product.name,
        item_category: product.category?.name,
        item_variant: `${variant.color.name} / ${variant.size}`,
        price: Math.round(variant.priceToman * 10),
        quantity,
      }],
    });
    setNotice("به سبد خرید اضافه شد.");
  }

  async function notifyWhenAvailable() {
    if (!variant || subscribingStock) return;
    setSubscribingStock(true);
    try {
      await requestStorePush();
      await customerApi(`/customer/back-in-stock/${variant.id}`, { method: "POST" });
      setStockSubscribed(true);
      setNotice("ثبت شد؛ وقتی این رنگ و سایز موجود شود بهت خبر می‌دهیم.");
    } catch (reason) {
      if (reason instanceof CustomerApiError && reason.status === 401) {
        window.location.assign(`/account?next=${encodeURIComponent(window.location.pathname)}`);
        return;
      }
      setNotice(reason instanceof Error ? reason.message : "ثبت درخواست اعلان انجام نشد.");
    } finally { setSubscribingStock(false); }
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
            <div
              className="store-main-image"
              data-gallery-direction={galleryDirection}
              role="group"
              onMouseEnter={() => setGalleryHovered(true)}
              onMouseLeave={() => setGalleryHovered(false)}
              onFocusCapture={() => setGalleryFocused(true)}
              onBlurCapture={(event) => { if (!event.currentTarget.contains(event.relatedTarget as Node | null)) setGalleryFocused(false); }}
              onPointerDown={(event) => {
                if (!event.isPrimary || event.button !== 0 || (event.target instanceof Element && event.target.closest("button"))) return;
                pointerStart.current = { x: event.clientX, y: event.clientY };
                event.currentTarget.setPointerCapture(event.pointerId);
              }}
              onPointerUp={(event) => finishGallerySwipe(event.clientX, event.clientY)}
              onPointerCancel={() => { pointerStart.current = null; }}
              onDragStart={(event) => event.preventDefault()}
              aria-label={mainImage ? `تصویر ${imageIndex + 1} از ${allImages.length} برای ${product.name}` : `تصویر ${product.name}`}
            >
              {mainImage ? <PageFlipImage src={mainImage.path} alt={mainImage.alt || product.name} outgoing={galleryOutgoing} direction={galleryDirection} priority sizes="(max-width: 760px) 100vw, 54vw" /> : <div className="store-no-image">{product.images.some((image) => image.colorName?.trim()) ? `برای رنگ ${color} عکسی ثبت نشده` : "تصویر محصول"}</div>}
              {discount > 0 && <span className="store-detail-sale">{new Intl.NumberFormat("fa-IR").format(discount)}٪ تخفیف</span>}
              {allImages.length > 1 && <>
                <span className="store-image-count">{new Intl.NumberFormat("fa-IR").format(Math.max(0, imageIndex + 1))} / {new Intl.NumberFormat("fa-IR").format(allImages.length)}</span>
                <button className="store-gallery-arrow store-gallery-previous" type="button" onClick={() => moveGallery(-1)} aria-label="تصویر قبلی"><ChevronLeft size={22} /></button>
                <button className="store-gallery-arrow store-gallery-next" type="button" onClick={() => moveGallery(1)} aria-label="تصویر بعدی"><ChevronRight size={22} /></button>
              </>}
            </div>
            {allImages.length > 1 && <div className="store-gallery-thumbnails" role="group" aria-label="انتخاب تصویر محصول">
              {allImages.map((image, index) => <button key={image.id} type="button" className={`store-gallery-thumbnail ${index === imageIndex ? "active" : ""}`} onClick={() => selectGalleryImage(index)} aria-label={`نمایش تصویر ${new Intl.NumberFormat("fa-IR").format(index + 1)}${image.colorName ? `، رنگ ${image.colorName}` : ""}`} aria-pressed={index === imageIndex}>
                <StoreImage src={image.path} alt="" fill sizes="68px" />
                <span>{new Intl.NumberFormat("fa-IR").format(index + 1)}</span>
              </button>)}
            </div>}
          </section>

          <section className="store-product-info">
            <span className="section-kicker">{product.category?.name || "پوشاک زنانه"}</span>
            <h1>{product.name}</h1>
            <p className="store-product-lead">{product.shortDescription || "انتخابی راحت و دوست‌داشتنی از کالکشن پانیذ."}</p>
            <div className="store-product-price-color-row">
              <div className="store-detail-price">
                <span>قیمت</span>
                <strong>{variant ? formatToman(variant.priceToman) : product.priceToman === null ? "قیمت نامشخص" : formatToman(product.priceToman)} <small>تومان</small></strong>
                {variant?.compareAtPriceToman && <del>{formatToman(variant.compareAtPriceToman)} تومان</del>}
              </div>
              <fieldset className="store-choice-group store-inline-color-group"><legend>رنگ <span>{color}</span></legend><div className="store-color-choices">{product.colors.map((item) => {
                const colorAvailable = product.variants.some((entry) => entry.color.name === item.name && entry.availableQuantity > 0);
                return <button key={item.name} type="button" className={`${color === item.name ? "active" : ""} ${!colorAvailable ? "unavailable" : ""}`} onClick={() => selectColor(item.name)} aria-label={`${item.name}${colorAvailable ? "" : "، ناموجود"}`} aria-pressed={color === item.name}><i style={{ background: item.value }} />{item.name}</button>;
              })}</div></fieldset>
            </div>
            <div className="store-stock-line" role="status">{stock > 0 ? <><span className="store-stock-dot" /> {stock <= 3 ? `فقط ${new Intl.NumberFormat("fa-IR").format(stock)} عدد باقی مانده` : "موجود و آمادهٔ خرید"}</> : <><span className="store-stock-dot unavailable" /> این ترکیب موجود نیست</>}</div>

            <fieldset className="store-choice-group"><legend>سایز <span>{size || "انتخاب کن"}</span></legend><div className="store-size-choices">{product.sizes.map((item) => {
              const itemAvailable = product.variants.some((entry) => entry.color.name === color && entry.size === item && entry.availableQuantity > 0);
              return <button key={item} type="button" className={`${size === item ? "active" : ""} ${!itemAvailable ? "unavailable" : ""}`} onClick={() => { setSize(item); setQuantity(1); setStockSubscribed(false); }} aria-label={`سایز ${item}${itemAvailable ? "" : "، ناموجود"}`} aria-pressed={size === item}>{item}</button>;
            })}</div>{sizeGuideRows.length > 0 && <div className="store-size-guide"><strong>راهنمای سایز</strong><div className="store-table-scroll"><table><thead><tr>{Object.keys(sizeGuideRows[0]).map((key) => <th key={key}>{key}</th>)}</tr></thead><tbody>{sizeGuideRows.map((row, index) => <tr key={index}>{Object.values(row).map((value, cell) => <td key={cell}>{String(value)}</td>)}</tr>)}</tbody></table></div></div>}</fieldset>

            <div className="store-buy-controls"><div className="store-quantity" aria-label="تعداد"><button type="button" onClick={() => setQuantity((value) => Math.max(1, value - 1))} disabled={quantity <= 1} aria-label="کم‌کردن تعداد"><Minus size={16} /></button><span>{new Intl.NumberFormat("fa-IR").format(quantity)}</span><button type="button" onClick={() => setQuantity((value) => Math.min(Math.max(1, maxOrderQuantity), value + 1))} disabled={!maxOrderQuantity || quantity >= maxOrderQuantity} aria-label="زیادکردن تعداد"><Plus size={16} /></button></div><button className="button-primary store-add-button" type="button" onClick={addToCart} disabled={!variant || !stock}><ShoppingBag size={19} /> افزودن به سبد خرید</button></div>
            {variant && stock === 0 && <button className={`store-back-in-stock-button ${stockSubscribed ? "is-subscribed" : ""}`} type="button" onClick={() => void notifyWhenAvailable()} disabled={subscribingStock || stockSubscribed}><Bell className={subscribingStock || stockSubscribed ? "" : "stock-notify-bell"} size={18} />{stockSubscribed ? "برای موجودشدن این انتخاب خبرت می‌کنیم" : subscribingStock ? "در حال ثبت درخواست…" : "موجود شد خبرم کن"}</button>}
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

function normalizeColorName(value: string) {
  return value.normalize("NFKC").replace(/[يى]/g, "ی").replace(/ك/g, "ک").trim().replace(/\s+/g, " ");
}
