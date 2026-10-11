"use client";

import Link from "next/link";
import {
  ArrowDownLeft,
  ArrowLeft,
  ArrowRight,
  Check,
  ChevronDown,
  Heart,
  House,
  Menu,
  Minus,
  Plus,
  Search,
  ShoppingBag,
  SlidersHorizontal,
  Sparkles,
  Star,
  UserRound,
  X,
} from "lucide-react";
import { useEffect, useMemo, useRef, useState, type CSSProperties } from "react";
import { useStorefront } from "./lib/storefront-state";
import { StoreImage } from "./components/store-image";
import { ProductSearchAutocomplete } from "./components/product-search-autocomplete";

type Product = {
  id: number;
  slug?: string;
  categorySlug?: string;
  name: string;
  category: string;
  price: number;
  previousPrice?: number;
  rating: number;
  reviews: number;
  image: string;
  imageAlt: string;
  badge?: string;
  colors: { name: string; value: string }[];
  sizes: string[];
  available?: boolean;
  variants?: ProductVariantOption[];
};

type ProductVariantOption = {
  id: string;
  color: { name: string; value: string };
  size: string;
  priceToman: number;
  compareAtPriceToman: number | null;
  availableQuantity: number;
};

type CategoryItem = {
  name: string;
  image: string;
  tone: string;
  slug?: string;
};

type ApiProduct = {
  id: string;
  name: string;
  slug: string;
  shortDescription: string | null;
  category: { id: string; name: string; slug: string } | null;
  image: { path: string; alt: string | null } | null;
  priceToman: number | null;
  compareAtPriceToman: number | null;
  colors: { name: string; value: string }[];
  sizes: string[];
  variants: ProductVariantOption[];
  available: boolean;
};

type ApiCategory = {
  name: string;
  slug: string;
  imagePath: string | null;
  children?: ApiCategory[];
};

type StorefrontConfig = {
  theme: string;
  sections: { sectionKey: string; title: string | null; isActive: boolean; sortOrder: number }[];
  banners: { id: string; title: string; description: string | null; imagePath: string; targetUrl: string | null }[];
};

const products: Product[] = [
  {
    id: 1,
    name: "ست راحتی لوتوس",
    category: "لباس راحتی",
    price: 1490000,
    previousPrice: 1890000,
    rating: 4.9,
    reviews: 42,
    image: "/images/paniz-sage.webp",
    imageAlt: "ست زنانه سبز روشن برای استایل روزمره",
    badge: "۲۰٪ تخفیف",
    colors: [
      { name: "سبز نعنایی", value: "#a9b99f" },
      { name: "صورتی", value: "#d88d9a" },
      { name: "کرم", value: "#d6c2ac" },
    ],
    sizes: ["S", "M", "L", "XL"],
  },
  {
    id: 2,
    name: "مانتو کتان آوین",
    category: "مانتو",
    price: 2390000,
    rating: 4.8,
    reviews: 28,
    image: "/images/paniz-linen.webp",
    imageAlt: "استایل زنانه شهری با مانتوی آزاد",
    colors: [
      { name: "شیری", value: "#dfd3c1" },
      { name: "آجری", value: "#b96f60" },
      { name: "ذغالی", value: "#444448" },
    ],
    sizes: ["36", "38", "40", "42"],
  },
  {
    id: 3,
    name: "پیراهن نخی مینا",
    category: "پیراهن",
    price: 1280000,
    previousPrice: 1590000,
    rating: 5,
    reviews: 35,
    image: "/images/paniz-peach.webp",
    imageAlt: "پیراهن زنانه با رنگ ملایم و پارچه سبک",
    badge: "پرفروش",
    colors: [
      { name: "گلبهی", value: "#d59a9c" },
      { name: "یاسی", value: "#a9a2ca" },
      { name: "سبز زیتونی", value: "#78866e" },
    ],
    sizes: ["S", "M", "L"],
  },
  {
    id: 4,
    name: "ست ورزشی نوا",
    category: "ست ورزشی",
    price: 1790000,
    rating: 4.7,
    reviews: 19,
    image: "/images/paniz-lilac.webp",
    imageAlt: "پوشاک زنانه راحت برای حرکت و ورزش",
    colors: [
      { name: "صورتی چرک", value: "#ba7c86" },
      { name: "مشکی", value: "#29292d" },
      { name: "یاسی", value: "#aaa5cc" },
    ],
    sizes: ["S", "M", "L", "XL"],
  },
  {
    id: 5,
    name: "بلوز نخی روژان",
    category: "تیشرت و بلوز",
    price: 790000,
    rating: 4.8,
    reviews: 16,
    image: "/images/paniz-peach.webp",
    imageAlt: "بلوز زنانه برای استایل مینیمال روزانه",
    colors: [
      { name: "سفید", value: "#f0ebe3" },
      { name: "صورتی", value: "#d88f9e" },
      { name: "آبی روشن", value: "#91a9bb" },
    ],
    sizes: ["S", "M", "L"],
  },
  {
    id: 6,
    name: "ست راحتی مهتاب",
    category: "لباس راحتی",
    price: 1690000,
    previousPrice: 1990000,
    rating: 4.9,
    reviews: 31,
    image: "/images/paniz-sage.webp",
    imageAlt: "لباس زنانه راحت در رنگ روشن",
    badge: "تازه رسیده",
    colors: [
      { name: "هلویی", value: "#d9997d" },
      { name: "کرم", value: "#d8c7af" },
      { name: "قهوه‌ای", value: "#80695f" },
    ],
    sizes: ["S", "M", "L", "XL"],
  },
  {
    id: 7,
    name: "مانتو لینن ترانه",
    category: "مانتو",
    price: 2690000,
    rating: 4.6,
    reviews: 12,
    image: "/images/paniz-linen.webp",
    imageAlt: "استایل خیابانی زنانه در روز آفتابی",
    colors: [
      { name: "کرم", value: "#d6c4aa" },
      { name: "آبی", value: "#859ab1" },
      { name: "مشکی", value: "#333236" },
    ],
    sizes: ["36", "38", "40", "42"],
  },
  {
    id: 8,
    name: "تیشرت روزمره نیکا",
    category: "تیشرت و بلوز",
    price: 690000,
    previousPrice: 850000,
    rating: 4.8,
    reviews: 23,
    image: "/images/paniz-lilac.webp",
    imageAlt: "استایل ساده زنانه با رنگ‌های آرام",
    badge: "۱۹٪ تخفیف",
    colors: [
      { name: "یاسی", value: "#a69ec5" },
      { name: "شیری", value: "#e7dfd2" },
      { name: "سبز", value: "#91a184" },
    ],
    sizes: ["S", "M", "L", "XL"],
  },
];

const categories: CategoryItem[] = [
  { name: "همه محصولات", image: products[0].image, tone: "mint" },
  { name: "ست ورزشی", image: products[3].image, tone: "lilac" },
  { name: "لباس راحتی", image: products[5].image, tone: "peach" },
  { name: "مانتو", image: products[1].image, tone: "rose" },
  { name: "تیشرت و بلوز", image: products[4].image, tone: "blue" },
  { name: "پیراهن", image: products[2].image, tone: "sand" },
];

const samplePresentation: Record<string, Product> = {
  "lotus-loungewear-set": products[0],
  "avin-cotton-coat": products[1],
  "mina-cotton-dress": products[2],
  "nova-sports-set": products[3],
  "rojan-cotton-blouse": products[4],
  "mahtab-loungewear-set": products[5],
  "taraneh-linen-coat": products[6],
  "nika-everyday-tshirt": products[7],
};

const money = (value: number) => new Intl.NumberFormat("fa-IR").format(value);

function normalizeText(value: string) {
  return value
    .toLocaleLowerCase("fa-IR")
    .replace(/[يى]/g, "ی")
    .replace(/ك/g, "ک")
    .replace(/[\u064B-\u065F\u0670]/g, "")
    .replace(/[\s\u200c]+/g, " ")
    .trim();
}

export default function Home() {
  const { cart, setCart, favorites, setFavorites } = useStorefront();
  const [catalogProducts, setCatalogProducts] = useState<Product[]>(products);
  const [catalogCategories, setCatalogCategories] = useState<CategoryItem[]>(categories);
  const [catalogSource, setCatalogSource] = useState<"demo" | "api">("demo");
  const [storefrontConfig, setStorefrontConfig] = useState<StorefrontConfig>({ theme: "rose", sections: [], banners: [] });
  const [bannerIndex, setBannerIndex] = useState(0);
  const [query, setQuery] = useState("");
  const [activeCategory, setActiveCategory] = useState("همه محصولات");
  const [sortBy, setSortBy] = useState("newest");
  const [selectedProduct, setSelectedProduct] = useState<Product | null>(null);
  const [selectedSize, setSelectedSize] = useState("");
  const [selectedColor, setSelectedColor] = useState("");
  const [cartOpen, setCartOpen] = useState(false);
  const [favoritesOnly, setFavoritesOnly] = useState(false);
  const [toast, setToast] = useState("");
  const searchRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    const controller = new AbortController();
    const apiBase = (process.env.NEXT_PUBLIC_API_BASE_URL || "http://localhost:4000/api/v1").replace(/\/$/, "");

    async function loadCatalog() {
      try {
        const [productResponse, categoryResponse] = await Promise.all([
          fetch(`${apiBase}/products?page=1&pageSize=48`, { signal: controller.signal, cache: "no-store" }),
          fetch(`${apiBase}/categories`, { signal: controller.signal, cache: "no-store" }),
        ]);
        if (!productResponse.ok || !categoryResponse.ok) throw new Error("Catalog API is unavailable");

        const productPayload = (await productResponse.json()) as { data?: ApiProduct[] };
        const categoryPayload = (await categoryResponse.json()) as { data?: ApiCategory[] };
        if (!Array.isArray(productPayload.data) || !Array.isArray(categoryPayload.data)) {
          throw new Error("Catalog API returned an invalid response");
        }

        const mappedProducts = productPayload.data.map((item): Product => {
          const id = Number(item.id);
          if (!Number.isSafeInteger(id)) throw new Error("Product ID exceeds the browser safe integer range");
          const hint = samplePresentation[item.slug];
          const compareAt = item.compareAtPriceToman ?? undefined;
          const discount = compareAt && item.priceToman
            ? Math.round((1 - item.priceToman / compareAt) * 100)
            : 0;

          return {
            id,
            slug: item.slug,
            categorySlug: item.category?.slug,
            name: item.name,
            category: item.category?.name ?? "پوشاک زنانه",
            price: item.priceToman ?? 0,
            previousPrice: compareAt,
            rating: hint?.rating ?? 0,
            reviews: hint?.reviews ?? 0,
            image: item.image?.path || hint?.image || products[0].image,
            imageAlt: item.image?.alt || hint?.imageAlt || item.name,
            badge: hint?.badge ?? (discount > 0 ? `${discount}٪ تخفیف` : undefined),
            colors: item.colors.length ? item.colors : hint?.colors ?? [],
            sizes: item.sizes.length ? item.sizes : hint?.sizes ?? [],
            variants: item.variants,
            available: item.available,
          };
        });

        const childCategories = categoryPayload.data.flatMap((item) => [item, ...(item.children ?? [])]);
        const mappedCategories: CategoryItem[] = [
          { ...categories[0], image: mappedProducts[0]?.image ?? categories[0].image },
          ...childCategories.map((item, index) => {
            const categoryProduct = mappedProducts.find((product) => product.categorySlug === item.slug);
            const fallback = categories[index + 1] ?? categories[0];
            return {
              name: item.name,
              slug: item.slug,
              image: item.imagePath || categoryProduct?.image || fallback.image,
              tone: fallback.tone,
            };
          }),
        ];

        if (!controller.signal.aborted) {
          setCatalogProducts(mappedProducts);
          setCatalogCategories(mappedCategories);
          setCatalogSource("api");
        }

        try {
          const configResponse = await fetch(`${apiBase}/storefront/config`, { signal: controller.signal, cache: "no-store" });
          if (configResponse.ok) {
            const configPayload = (await configResponse.json()) as { data?: StorefrontConfig };
            if (configPayload.data && !controller.signal.aborted) setStorefrontConfig(configPayload.data);
          }
        } catch {
          // Keep the local homepage defaults if the public store configuration is unavailable.
        }
      } catch {
        // Keep the local sample catalog usable when the API or database is offline.
      }
    }

    void loadCatalog();
    return () => controller.abort();
  }, []);

  useEffect(() => {
    if (storefrontConfig.banners.length < 2) return;
    const timer = window.setInterval(() => setBannerIndex((index) => (index + 1) % storefrontConfig.banners.length), 5500);
    return () => window.clearInterval(timer);
  }, [storefrontConfig.banners.length]);

  useEffect(() => {
    if (!toast) return;
    const timer = window.setTimeout(() => setToast(""), 2600);
    return () => window.clearTimeout(timer);
  }, [toast]);

  useEffect(() => {
    function handleShortcuts(event: KeyboardEvent) {
      if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === "k") {
        event.preventDefault();
        searchRef.current?.focus();
      }
      if (event.key === "Escape") {
        setSelectedProduct(null);
        setCartOpen(false);
      }
    }
    window.addEventListener("keydown", handleShortcuts);
    return () => window.removeEventListener("keydown", handleShortcuts);
  }, []);

  useEffect(() => {
    if (!selectedProduct && !cartOpen) return;
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => { document.body.style.overflow = previousOverflow; };
  }, [cartOpen, selectedProduct]);

  const visibleProducts = useMemo(() => {
    const normalizedQuery = normalizeText(query);
    const filtered = catalogProducts.filter((product) => {
      const matchesCategory =
        activeCategory === "همه محصولات" || product.category === activeCategory;
      const matchesQuery =
        !normalizedQuery ||
        normalizeText(`${product.name} ${product.category}`).includes(normalizedQuery);
      const matchesFavorites = !favoritesOnly || favorites.includes(product.id);
      return matchesCategory && matchesQuery && matchesFavorites;
    });

    if (sortBy === "price-low") return filtered.sort((a, b) => a.price - b.price);
    if (sortBy === "price-high") return filtered.sort((a, b) => b.price - a.price);
    if (sortBy === "popular") return filtered.sort((a, b) => b.reviews - a.reviews);
    return filtered;
  }, [activeCategory, catalogProducts, favorites, favoritesOnly, query, sortBy]);

  const cartCount = cart.reduce((sum, line) => sum + line.quantity, 0);
  const activeBanner = storefrontConfig.banners.length
    ? storefrontConfig.banners[bannerIndex % storefrontConfig.banners.length]
    : null;
  const sectionIsActive = (key: string) => storefrontConfig.sections.find((section) => section.sectionKey === key)?.isActive ?? true;
  const sectionOrder = (key: string, fallback: number) => storefrontConfig.sections.find((section) => section.sectionKey === key)?.sortOrder ?? fallback;
  const cartTotal = cart.reduce((sum, line) => {
    const product = catalogProducts.find((item) => item.id === line.productId);
    return sum + (line.unitPrice ?? product?.price ?? 0) * line.quantity;
  }, 0);
  const selectedVariant = selectedProduct?.variants?.find(
    (variant) => variant.color.name === selectedColor && variant.size === selectedSize,
  );
  const selectedColorHasStock = !selectedProduct?.variants || selectedProduct.variants.some(
    (variant) => variant.color.name === selectedColor && variant.availableQuantity > 0,
  );
  const selectedVariantAvailable = !selectedProduct?.variants || Boolean(
    selectedColorHasStock && selectedVariant && selectedVariant.availableQuantity > 0,
  );
  const selectedPrice = selectedVariant?.priceToman ?? selectedProduct?.price ?? 0;
  const selectedCompareAtPrice = selectedVariant
    ? selectedVariant.compareAtPriceToman ?? undefined
    : selectedProduct?.previousPrice;

  function toggleFavorite(productId: number) {
    setFavorites((current) =>
      current.includes(productId)
        ? current.filter((id) => id !== productId)
        : [...current, productId],
    );
  }

  function openProduct(product: Product) {
    setSelectedProduct(product);
    setSelectedSize("");
    setSelectedColor(product.colors[0]?.name ?? "");
  }

  function addToCart(product: Product, size: string, color: string) {
    const variant = product.variants?.find((item) => item.color.name === color && item.size === size);
    if (product.available === false || (product.variants && (!variant || variant.availableQuantity < 1))) {
      setToast("این ترکیب رنگ و سایز موجود نیست");
      return;
    }

    const key = variant?.id ?? `${product.id}-${size}-${color}`;
    const existing = cart.find((line) => line.key === key);
    if (variant && existing && existing.quantity >= variant.availableQuantity) {
      setToast("موجودی این تنوع به پایان رسیده است");
      return;
    }

    setCart((current) => {
      if (current.some((line) => line.key === key)) {
        return current.map((line) =>
          line.key === key ? { ...line, quantity: line.quantity + 1 } : line,
        );
      }
      return [...current, {
        key,
        productId: product.id,
        productSlug: product.slug ?? "",
        size,
        color,
        quantity: 1,
        variantId: variant?.id,
        unitPrice: variant?.priceToman ?? product.price,
      }];
    });
    setSelectedProduct(null);
    setToast(`${product.name} به سبد خرید اضافه شد`);
  }

  function updateQuantity(key: string, change: number) {
    setCart((current) =>
      current
        .map((line) => {
          if (line.key !== key) return line;
          const product = catalogProducts.find((item) => item.id === line.productId);
          const variant = product?.variants?.find((item) => item.id === line.variantId);
          const requested = Math.max(0, line.quantity + change);
          const quantity = variant ? Math.min(requested, variant.availableQuantity) : requested;
          return { ...line, quantity };
        })
        .filter((line) => line.quantity > 0),
    );
  }

  function chooseCategory(category: string) {
    setActiveCategory(category);
    setFavoritesOnly(false);
    document.getElementById("products")?.scrollIntoView({ behavior: "smooth" });
  }

  function showFavorites() {
    setFavoritesOnly(true);
    setActiveCategory("همه محصولات");
    document.getElementById("products")?.scrollIntoView({ behavior: "smooth" });
  }

  return (
    <main>
      <div className="announcement-bar">
        <Sparkles size={15} aria-hidden="true" />
        <span>کالکشن‌های تازه و انتخاب‌های دوست‌داشتنی پانیذ</span>
        <ArrowLeft size={14} aria-hidden="true" />
      </div>

      <header className="site-header">
        <div className="header-main page-shell">
          <button className="icon-button mobile-menu" onClick={() => document.getElementById("categories")?.scrollIntoView({ behavior: "smooth" })} aria-label="رفتن به دسته‌بندی‌ها">
            <Menu size={23} />
          </button>
          <a className="brand" href="#top" aria-label="صفحه اصلی پانیذ">
            <span className="brand-mark">پ</span>
            <span className="brand-word">پانیذ</span>
          </a>

          <ProductSearchAutocomplete
            id="store-search"
            inputRef={searchRef}
            wrapperClassName="header-search-autocomplete"
            value={query}
            onChange={setQuery}
            shortcut="Ctrl K"
          />

          <div className="header-actions">
            <button
              className={`header-icon ${favoritesOnly ? "selected" : ""}`}
              onClick={showFavorites}
              aria-label={`علاقه‌مندی‌ها، ${favorites.length} محصول`}
              aria-pressed={favoritesOnly}
            >
              <Heart size={21} />
            </button>
            <button
              className="header-icon bag-icon"
              onClick={() => setCartOpen(true)}
              aria-label={`سبد خرید، ${cartCount} کالا`}
            >
              <ShoppingBag size={21} />
              {cartCount > 0 && <span className="count-badge">{money(cartCount)}</span>}
            </button>
            <Link className="account-button" href="/account">
              <UserRound size={18} />
              <span>پروفایل</span>
            </Link>
          </div>
        </div>

        <nav className="desktop-nav page-shell" aria-label="ناوبری اصلی">
          <a className="nav-link active" href="#top">خانه</a>
          <button className="nav-link" onClick={() => chooseCategory("همه محصولات")}>همه محصولات</button>
          {catalogCategories.filter((category) => category.name !== "همه محصولات").slice(0, 5).map((category) =>
            <button className="nav-link" key={category.slug ?? category.name} onClick={() => chooseCategory(category.name)}>{category.name}</button>,
          )}
          <button className="nav-link nav-offer" onClick={() => chooseCategory("همه محصولات")}>تخفیف‌های دوست‌داشتنی</button>
          <a className="nav-link nav-help" href="#footer">راهنمای خرید</a>
        </nav>
      </header>

      <div className="page-shell page-content" id="top">
        {sectionIsActive("hero") && <section className="hero" aria-labelledby="hero-title" style={{ order: sectionOrder("hero", 0) }}>
          <div className="hero-copy">
            <span className="eyebrow"><span className="eyebrow-dot" /> {activeBanner ? "پیشنهاد تازهٔ پانیذ" : "کالکشن تازهٔ پانیذ"}</span>
            <h1 id="hero-title">{activeBanner?.title ?? <>هر روز،<br />با <em>حالِ خوب</em> بپوش</>}</h1>
            <p>{activeBanner?.description || "لباس‌هایی برای روزهای پرجنب‌وجوش و لحظه‌های آرام تو. راحت، خوش‌دوخت و دوست‌داشتنی."}</p>
            <div className="hero-buttons">
              <button className="button-primary" onClick={() => {
                const target = activeBanner?.targetUrl;
                if (target?.startsWith("/")) window.location.assign(target);
                else if (target?.startsWith("https://")) window.open(target, "_blank", "noopener,noreferrer");
                else chooseCategory("همه محصولات");
              }}>
                دیدن محصولات <ArrowLeft size={18} />
              </button>
              <span className="hero-note"><span className="note-line" /> انتخاب‌هایی از جنس خودت</span>
            </div>
            <div className="hero-proof">
              <div className="avatar-stack" aria-hidden="true">
                <StoreImage src={catalogProducts[4]?.image ?? products[4].image} alt="" width={34} height={34} />
                <StoreImage src={catalogProducts[2]?.image ?? products[2].image} alt="" width={34} height={34} />
                <StoreImage src={catalogProducts[0]?.image ?? products[0].image} alt="" width={34} height={34} />
              </div>
              <div><strong>۴.۹ از ۵</strong><span>از دلِ تجربهٔ شما</span></div>
              <span className="hero-proof-stars" aria-label="۵ ستاره"><Star /><Star /><Star /><Star /><Star /></span>
            </div>
          </div>
          <div className="hero-visual">
            <div className="hero-image-wrap">
              <StoreImage
                src={activeBanner?.imagePath || "/images/paniz-sage.webp"}
                alt={activeBanner?.title || "استایل زنانهٔ تازه و راحت از کالکشن پانیذ"}
                fill
                priority
                sizes="(max-width: 760px) 92vw, 55vw"
                className="hero-image"
              />
            </div>
            <div className="hero-sticker"><span>حس خوب</span><strong>از همین‌جا<br />شروع می‌شه</strong><Sparkles size={18} /></div>
            <div className="hero-tag"><span className="tag-line" /><span>برای روزهای خودت</span></div>
            <div className="hero-orbit" aria-hidden="true" />
          </div>
          {storefrontConfig.banners.length > 1 && <div className="hero-pagination" aria-label="انتخاب بنر">
            {storefrontConfig.banners.map((banner, index) => <button key={banner.id} className={index === bannerIndex ? "current" : ""} aria-label={`بنر ${money(index + 1)}`} aria-pressed={index === bannerIndex} onClick={() => setBannerIndex(index)} />)}
          </div>}
        </section>}

        {sectionIsActive("categories") && <section className="categories-section" aria-labelledby="categories-title" id="categories" style={{ order: sectionOrder("categories", 1) }}>
          <div className="section-heading category-heading">
            <div><span className="section-kicker">از کمدت شروع کنیم</span><h2 id="categories-title">دسته‌بندی‌های محبوب</h2></div>
            <button className="text-link" onClick={() => chooseCategory("همه محصولات")}>مشاهده همه <ArrowLeft size={16} /></button>
          </div>
          <div className="category-list">
            {catalogCategories.map((category) => (
              <button
                className={`category-item ${category.tone} ${activeCategory === category.name ? "chosen" : ""}`}
                key={category.name}
                onClick={() => chooseCategory(category.name)}
                aria-pressed={activeCategory === category.name}
              >
                <span className="category-image-wrap">
                  <StoreImage src={category.image} alt="" fill sizes="100px" />
                  <span className="category-arrow"><ArrowDownLeft size={15} /></span>
                </span>
                <span>{category.name}</span>
              </button>
            ))}
          </div>
        </section>}

        {sectionIsActive("products") && <section className="products-section" id="products" aria-labelledby="products-title" style={{ order: sectionOrder("products", 2) }}>
          <div className="section-heading products-heading">
            <div>
              <span className="section-kicker">تازه از راه رسیده‌اند</span>
              <h2 id="products-title">انتخاب‌های این روزها <Sparkles className="heading-sparkle" aria-hidden="true" /></h2>
              <p>لباس‌هایی که دلت می‌خواد بیشتر بپوشی.</p>
            </div>
            <label className="sort-control">
              <SlidersHorizontal size={17} />
              <span className="sr-only">مرتب‌سازی محصولات</span>
              <select value={sortBy} onChange={(event) => setSortBy(event.target.value)}>
                <option value="newest">جدیدترین</option>
                <option value="popular">محبوب‌ترین</option>
                <option value="price-low">ارزان‌ترین</option>
                <option value="price-high">گران‌ترین</option>
              </select>
              <ChevronDown size={15} />
            </label>
          </div>

          <div className="filter-chips" aria-label="فیلتر دسته‌بندی">
            {catalogCategories.map((item) => item.name).map((category) => (
              <button
                key={category}
                className={`filter-chip ${activeCategory === category && !favoritesOnly ? "active" : ""}`}
                aria-pressed={activeCategory === category && !favoritesOnly}
                onClick={() => {
                  setActiveCategory(category);
                  setFavoritesOnly(false);
                }}
              >
                {category}
              </button>
            ))}
            {favoritesOnly && <button className="filter-chip active" onClick={() => setFavoritesOnly(false)}>علاقه‌مندی‌های من <X size={13} /></button>}
          </div>

          {catalogSource === "demo" && (
            <p className="catalog-source-note" role="status">
              در حال نمایش کاتالوگ نمونه؛ برای دیدن محصولات دیتابیس، MySQL و Backend را اجرا کنید.
            </p>
          )}

          {visibleProducts.length > 0 ? (
            <div className="product-grid">
              {visibleProducts.map((product) => (
                <article className="product-card" key={product.id}>
                  <div className="product-image-area">
                    <button className="product-photo-button" onClick={() => openProduct(product)} aria-label={`مشاهده ${product.name}`}>
                      <StoreImage
                        src={product.image}
                        alt={product.imageAlt}
                        fill
                        sizes="(max-width: 580px) 45vw, (max-width: 950px) 30vw, 24vw"
                        className="product-image"
                      />
                    </button>
                    {product.badge && <span className={`product-badge ${product.badge.includes("تخفیف") ? "sale" : "fresh"}`}>{product.badge}</span>}
                    <button
                      className={`favorite-button ${favorites.includes(product.id) ? "favorited" : ""}`}
                      onClick={() => toggleFavorite(product.id)}
                      aria-label={favorites.includes(product.id) ? "حذف از علاقه‌مندی‌ها" : "افزودن به علاقه‌مندی‌ها"}
                      aria-pressed={favorites.includes(product.id)}
                    >
                      <Heart size={18} fill={favorites.includes(product.id) ? "currentColor" : "none"} />
                    </button>
                    <button className="quick-add" disabled={product.available === false} onClick={() => openProduct(product)}><Plus size={16} /> {product.available === false ? "ناموجود" : "انتخاب سایز"}</button>
                  </div>
                  <div className="product-details">
                    <span className="product-category">{product.category}</span>
                    <button className="product-name" onClick={() => openProduct(product)}>{product.name}</button>
                    {product.reviews > 0 ? (
                      <div className="product-rating"><Star size={13} fill="currentColor" /><span>{product.rating}</span><span className="rating-count">({money(product.reviews)} نظر)</span></div>
                    ) : (
                      <div className="product-rating unrated">هنوز نظری ثبت نشده</div>
                    )}
                    <div className="product-price-row">
                      <div className="price-stack">
                        {product.previousPrice && <del>{money(product.previousPrice)} <small>تومان</small></del>}
                        <strong>{money(product.price)} <small>تومان</small></strong>
                      </div>
                      <div className="swatch-list" aria-label="رنگ‌های محصول">
                        {product.colors.slice(0, 3).map((color) => <i key={color.name} style={{ backgroundColor: color.value }} title={color.name} />)}
                      </div>
                    </div>
                  </div>
                </article>
              ))}
            </div>
          ) : (
            <div className="empty-state"><Search size={28} /><strong>چیزی پیدا نکردیم</strong><span>یه عبارت دیگه رو امتحان کن یا فیلترها رو بردار.</span><button onClick={() => { setQuery(""); setActiveCategory("همه محصولات"); setFavoritesOnly(false); }}>نمایش همه محصولات</button></div>
          )}

          <div className="load-more-wrap"><span>{money(visibleProducts.length)} محصول از {money(catalogProducts.length)}</span><Link className="outline-button" href="/products">دیدن همه محصولات <ArrowLeft size={17} /></Link></div>
        </section>}

        {sectionIsActive("story") && <section className="story-banner" aria-label="پیشنهاد پانیذ" style={{ order: sectionOrder("story", 3) }}>
          <div className="story-art"><span className="story-orb" /><StoreImage src={catalogProducts[2]?.image ?? products[2].image} alt="" fill sizes="35vw" /></div>
          <div className="story-copy"><span className="section-kicker">یک انتخاب کوچک، یک حس تازه</span><h2>برای خودت<br />یه چیز <em>قشنگ</em> بردار</h2><p>با انتخاب‌های دوست‌داشتنی پانیذ، حال خوب رو به روزمرگی‌هات اضافه کن.</p><button className="button-primary" onClick={() => chooseCategory("همه محصولات")}>انتخاب من <ArrowLeft size={18} /></button></div>
          <div className="story-stamp"><span>با عشق</span><Heart size={19} fill="currentColor" /></div>
        </section>}

        {sectionIsActive("benefits") && <section className="benefits-strip" aria-label="خدمات پانیذ" style={{ order: sectionOrder("benefits", 4) }}>
          <div className="benefit"><span className="benefit-icon mint-icon"><ShoppingBag size={20} /></span><div><strong>خرید آسوده</strong><span>قیمت و موجودی از فروشگاه بررسی می‌شود</span></div></div>
          <span className="benefit-separator" />
          <div className="benefit"><span className="benefit-icon peach-icon"><ArrowRight size={20} /></span><div><strong>روش‌های ارسال</strong><span>هزینه پس از واردکردن نشانی مشخص می‌شود</span></div></div>
          <span className="benefit-separator" />
          <div className="benefit"><span className="benefit-icon lilac-icon"><Check size={20} /></span><div><strong>شرایط تعویض</strong><span>پیش از نهایی‌شدن سفارش اعلام می‌شود</span></div></div>
          <span className="benefit-separator" />
          <div className="benefit"><span className="benefit-icon rose-icon"><Heart size={20} /></span><div><strong>پیگیری سفارش</strong><span>وضعیت خریدت را آنلاین ببین</span></div></div>
        </section>}
      </div>

      <footer className="site-footer" id="footer">
        <div className="footer-inner page-shell">
          <div className="footer-brand"><a className="brand" href="#top"><span className="brand-mark">پ</span><span className="brand-word">پانیذ</span></a><p>پانیذ؛ برای روزهایی که می‌خوای خودت باشی.</p></div>
          <div><strong>راهنمای خرید</strong><Link href="/help/shipping">روش‌های ارسال</Link><Link href="/policies/returns">شرایط تعویض</Link><Link href="/help/faq">سؤالات پرتکرار</Link></div>
          <div><strong>همراه پانیذ</strong><Link href="/about">دربارهٔ ما</Link><Link href="/contact">تماس با ما</Link><Link href="/policies/privacy">حریم خصوصی</Link></div>
          <div className="newsletter"><strong>خبرهای خوب رو از دست نده</strong><span>خبرنامه بعد از اتصال سرویس اطلاع‌رسانی فعال می‌شود.</span></div>
        </div>
        <div className="footer-bottom page-shell"><span>© پانیذ، برای تو و روزهای خوبت</span><span>ساخته‌شده با <Heart size={13} fill="currentColor" /> در ایران</span></div>
      </footer>

      <nav className="mobile-bottom-nav" aria-label="ناوبری پایین">
        <Link href="/" className="bottom-nav-item active"><House size={20} /><span>خانه</span></Link>
        <Link href="/products" className="bottom-nav-item"><Menu size={20} /><span>دسته‌ها</span></Link>
        <Link href="/favorites" className="bottom-nav-item"><Heart size={20} /><span>علاقه‌مندی</span></Link>
        <Link href="/cart" className="bottom-nav-item bottom-cart"><ShoppingBag size={20} /><span>سبد خرید</span>{cartCount > 0 && <i>{money(cartCount)}</i>}</Link>
        <Link href="/account" className="bottom-nav-item"><UserRound size={20} /><span>پروفایل</span></Link>
      </nav>

      {selectedProduct && (
        <div className="modal-backdrop" role="presentation" onMouseDown={(event) => { if (event.target === event.currentTarget) setSelectedProduct(null); }}>
          <section className="product-modal" role="dialog" aria-modal="true" aria-labelledby="modal-title">
            <button className="modal-close icon-button" onClick={() => setSelectedProduct(null)} aria-label="بستن"><X size={21} /></button>
            <div className="modal-image"><StoreImage src={selectedProduct.image} alt={selectedProduct.imageAlt} fill sizes="(max-width: 680px) 90vw, 420px" /></div>
            <div className="modal-content">
              <span className="section-kicker">{selectedProduct.category}</span>
              <h2 id="modal-title">{selectedProduct.name}</h2>
              {selectedProduct.reviews > 0 ? (
                <div className="modal-rating"><Star size={15} fill="currentColor" /> {selectedProduct.rating} <span>({money(selectedProduct.reviews)} نظر خریداران)</span></div>
              ) : (
                <div className="modal-rating unrated">هنوز نظری برای این محصول ثبت نشده</div>
              )}
              <p className="modal-description">پارچه‌ای لطیف با دوختی تمیز؛ انتخابی راحت برای روزهایی که می‌خوای با خیال آسوده، خودت باشی.</p>
              <div className="option-group"><div className="option-title"><strong>رنگ</strong><span>{selectedColor}</span></div><div className="color-options">{selectedProduct.colors.map((color) => {
                const colorAvailable = !selectedProduct.variants || selectedProduct.variants.some((variant) => variant.color.name === color.name && variant.availableQuantity > 0);
                return <button key={color.name} disabled={!colorAvailable} className={`color-option ${selectedColor === color.name ? "chosen" : ""}`} style={{ "--swatch": color.value } as CSSProperties} onClick={() => { setSelectedColor(color.name); setSelectedSize(""); }} aria-label={`${color.name}${colorAvailable ? "" : "، ناموجود"}`} aria-pressed={selectedColor === color.name} title={colorAvailable ? color.name : `${color.name}، ناموجود`}><span /></button>;
              })}</div></div>
              <div className="option-group"><div className="option-title"><strong>سایز</strong><button className="size-guide" onClick={() => setToast("راهنمای سایز این محصول به‌زودی اضافه می‌شود")}>راهنمای سایز</button></div><div className="size-options">{selectedProduct.sizes.map((size) => {
                const optionAvailable = !selectedProduct.variants || selectedProduct.variants.some((variant) => variant.color.name === selectedColor && variant.size === size && variant.availableQuantity > 0);
                return <button key={size} className={selectedSize === size ? "chosen" : ""} disabled={!optionAvailable} onClick={() => setSelectedSize(size)} aria-label={`${size}${optionAvailable ? "" : "، ناموجود"}`} aria-pressed={selectedSize === size} title={optionAvailable ? size : `${size}، ناموجود`}>{size}</button>;
              })}</div></div>
              <div className="modal-buy-row"><div><span>قیمت</span><strong>{money(selectedPrice)} <small>تومان</small></strong>{selectedCompareAtPrice && <del>{money(selectedCompareAtPrice)} تومان</del>}</div><button className="button-primary" disabled={selectedProduct.available === false || !selectedSize || !selectedVariantAvailable} onClick={() => addToCart(selectedProduct, selectedSize, selectedColor)}><ShoppingBag size={18} /> {selectedProduct.available === false ? "ناموجود" : !selectedColorHasStock ? "این رنگ ناموجود است" : !selectedSize ? "اول سایزت رو انتخاب کن" : selectedVariantAvailable ? "افزودن به سبد خرید" : "این تنوع ناموجود است"}</button></div>
              {selectedProduct.slug && <Link className="product-details-link" href={`/products/${selectedProduct.slug}`} onClick={() => setSelectedProduct(null)}>دیدن مشخصات و راهنمای کامل <ArrowLeft size={15} /></Link>}
            </div>
          </section>
        </div>
      )}

      {cartOpen && (
        <div className="drawer-backdrop" role="presentation" onMouseDown={(event) => { if (event.target === event.currentTarget) setCartOpen(false); }}>
          <aside className="cart-drawer" aria-label="سبد خرید" role="dialog" aria-modal="true">
            <div className="drawer-header"><div><span className="section-kicker">انتخاب‌های قشنگت</span><h2>سبد خرید <small>({money(cartCount)})</small></h2></div><button className="icon-button" onClick={() => setCartOpen(false)} aria-label="بستن سبد خرید"><X size={21} /></button></div>
            {cart.length ? <>
              <div className="cart-lines">{cart.map((line) => {
                const product = catalogProducts.find((item) => item.id === line.productId);
                if (!product) return null;
                return <div className="cart-line" key={line.key}><div className="cart-line-image"><StoreImage src={product.image} alt={product.imageAlt} fill sizes="90px" /></div><div className="cart-line-info"><strong>{product.name}</strong><span>{line.color} · سایز {line.size}</span><b>{money(line.unitPrice ?? product.price)} <small>تومان</small></b><div className="quantity-control"><button onClick={() => updateQuantity(line.key, -1)} aria-label="کم‌کردن تعداد"><Minus size={13} /></button><span>{money(line.quantity)}</span><button onClick={() => updateQuantity(line.key, 1)} aria-label="زیادکردن تعداد"><Plus size={13} /></button></div></div><button className="remove-line" onClick={() => updateQuantity(line.key, -line.quantity)} aria-label="حذف محصول"><X size={16} /></button></div>;
              })}</div>
              <div className="cart-summary"><div><span>جمع سفارش</span><strong>{money(cartTotal)} <small>تومان</small></strong></div><div className="shipping-note"><Check size={16} /> هزینهٔ ارسال بعد از دریافت نشانی محاسبه می‌شود</div><Link className="button-primary checkout-button" href="/checkout">ادامهٔ خرید <ArrowLeft size={17} /></Link><Link className="continue-shopping" href="/cart">مشاهدهٔ سبد کامل</Link></div>
            </> : <div className="cart-empty"><span><ShoppingBag size={30} /></span><strong>سبدت هنوز خالیه</strong><p>یه گشتی بزن، شاید چیزی دلت رو برد.</p><button className="button-primary" onClick={() => setCartOpen(false)}>دیدن محصولات <ArrowLeft size={17} /></button></div>}
          </aside>
        </div>
      )}

      {toast && <div className="toast-message" role="status"><Check size={18} /> {toast}<button onClick={() => setToast("")} aria-label="بستن پیام"><X size={15} /></button></div>}
    </main>
  );
}
