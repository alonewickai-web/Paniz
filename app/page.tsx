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
import { PageFlipImage, type FlipImage } from "./components/page-flip-image";
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
  images?: { id: string; path: string; alt: string | null }[];
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
  images: { id: string; path: string; alt: string | null }[];
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
  banners: {
    id: string;
    altText: string;
    imagePath: string;
    backgroundColor: string | null;
  }[];
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
  const [catalogProducts, setCatalogProducts] = useState<Product[]>(() =>
    process.env.NODE_ENV === "production" ? [] : products,
  );
  const [catalogCategories, setCatalogCategories] = useState<CategoryItem[]>(() =>
    process.env.NODE_ENV === "production" ? [categories[0]] : categories,
  );
  const [catalogSource, setCatalogSource] = useState<"loading" | "demo" | "api" | "error">(() =>
    process.env.NODE_ENV === "production" ? "loading" : "demo",
  );
  const [catalogReloadKey, setCatalogReloadKey] = useState(0);
  const [storefrontConfig, setStorefrontConfig] = useState<StorefrontConfig>({ theme: "rose", sections: [], banners: [] });
  const [bannerIndex, setBannerIndex] = useState(0);
  const [outgoingBanner, setOutgoingBanner] = useState<StorefrontConfig["banners"][number] | null>(null);
  const [failedBannerImageKey, setFailedBannerImageKey] = useState<string | null>(null);
  const [bannerHovered, setBannerHovered] = useState(false);
  const [bannerFocused, setBannerFocused] = useState(false);
  const [query, setQuery] = useState("");
  const [activeCategory, setActiveCategory] = useState("همه محصولات");
  const [sortBy, setSortBy] = useState("newest");
  const [selectedProduct, setSelectedProduct] = useState<Product | null>(null);
  const [selectedImageIndex, setSelectedImageIndex] = useState(0);
  const [galleryDirection, setGalleryDirection] = useState<"next" | "previous">("next");
  const [quickGalleryOutgoing, setQuickGalleryOutgoing] = useState<FlipImage | null>(null);
  const [quickGalleryHovered, setQuickGalleryHovered] = useState(false);
  const [quickGalleryFocused, setQuickGalleryFocused] = useState(false);
  const [selectedSize, setSelectedSize] = useState("");
  const [selectedColor, setSelectedColor] = useState("");
  const [cartOpen, setCartOpen] = useState(false);
  const [favoritesOnly, setFavoritesOnly] = useState(false);
  const [toast, setToast] = useState("");
  const searchRef = useRef<HTMLInputElement>(null);
  const galleryTouchStart = useRef<{ x: number; y: number } | null>(null);
  const bannerPointerStart = useRef<number | null>(null);
  const bannerIndexRef = useRef(0);
  const galleryIndexRef = useRef(0);

  useEffect(() => {
    const controller = new AbortController();
    const apiBase = (process.env.NEXT_PUBLIC_API_BASE_URL || "http://localhost:4000/api/v1").replace(/\/$/, "");

    async function loadCatalog() {
      if (process.env.NODE_ENV === "production") setCatalogSource("loading");
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
            images: item.images,
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
        if (controller.signal.aborted) return;
        if (process.env.NODE_ENV === "production") {
          setCatalogProducts([]);
          setCatalogCategories([categories[0]]);
          setCatalogSource("error");
        } else {
          setCatalogProducts(products);
          setCatalogCategories(categories);
          setCatalogSource("demo");
        }
      }
    }

    void loadCatalog();
    return () => controller.abort();
  }, [catalogReloadKey]);

  useEffect(() => {
    if (storefrontConfig.banners.length < 2 || bannerHovered || bannerFocused) return;
    const timer = window.setInterval(() => {
      if (document.visibilityState !== "visible" || window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
      const currentIndex = bannerIndexRef.current % storefrontConfig.banners.length;
      const nextIndex = (currentIndex + 1) % storefrontConfig.banners.length;
      setOutgoingBanner(storefrontConfig.banners[currentIndex]);
      bannerIndexRef.current = nextIndex;
      setBannerIndex(nextIndex);
    }, 5500);
    return () => window.clearInterval(timer);
  }, [bannerFocused, bannerHovered, storefrontConfig.banners]);

  useEffect(() => {
    if (!outgoingBanner) return;
    const timer = window.setTimeout(() => setOutgoingBanner(null), 820);
    return () => window.clearTimeout(timer);
  }, [outgoingBanner]);

  useEffect(() => {
    galleryIndexRef.current = selectedImageIndex;
  }, [selectedImageIndex]);

  useEffect(() => {
    if (!selectedProduct || (selectedProduct.images?.length ?? 0) < 2 || quickGalleryHovered || quickGalleryFocused) return;
    const timer = window.setInterval(() => {
      if (document.visibilityState !== "visible" || window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
      const images = selectedProduct.images ?? [];
      const currentIndex = galleryIndexRef.current % images.length;
      const currentImage = images[currentIndex];
      if (!currentImage) return;
      const nextIndex = (currentIndex + 1) % images.length;
      setQuickGalleryOutgoing({ src: currentImage.path, alt: currentImage.alt || selectedProduct.name });
      setGalleryDirection("next");
      galleryIndexRef.current = nextIndex;
      setSelectedImageIndex(nextIndex);
    }, 5000);
    return () => window.clearInterval(timer);
  }, [quickGalleryFocused, quickGalleryHovered, selectedProduct]);

  useEffect(() => {
    if (!quickGalleryOutgoing) return;
    const timer = window.setTimeout(() => setQuickGalleryOutgoing(null), 820);
    return () => window.clearTimeout(timer);
  }, [quickGalleryOutgoing]);

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
  const bannerImageKey = activeBanner ? `${activeBanner.id}:${activeBanner.imagePath}` : "default-banner";
  const bannerAltText = activeBanner?.altText?.trim() || "فروشگاه پوشاک زنانه پانیذ";
  const bannerImagePath = activeBanner?.imagePath || "/images/paniz-sage.webp";
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
    setSelectedImageIndex(0);
    galleryIndexRef.current = 0;
    setQuickGalleryOutgoing(null);
    setQuickGalleryHovered(false);
    setQuickGalleryFocused(false);
    setGalleryDirection("next");
    galleryTouchStart.current = null;
    setSelectedSize("");
    setSelectedColor(product.colors[0]?.name ?? "");
  }

  function moveSelectedGallery(step: number) {
    const images = selectedProduct?.images ?? [];
    const imageCount = images.length;
    if (imageCount < 2) return;
    const currentIndex = galleryIndexRef.current % imageCount;
    const currentImage = images[currentIndex];
    const nextIndex = (currentIndex + step + imageCount) % imageCount;
    if (currentImage) setQuickGalleryOutgoing({ src: currentImage.path, alt: currentImage.alt || selectedProduct?.name || "تصویر محصول" });
    setGalleryDirection(step > 0 ? "next" : "previous");
    galleryIndexRef.current = nextIndex;
    setSelectedImageIndex(nextIndex);
  }

  function finishSelectedGallerySwipe(x: number, y: number) {
    const start = galleryTouchStart.current;
    galleryTouchStart.current = null;
    if (!start) return;
    const dx = x - start.x;
    const dy = y - start.y;
    if (Math.abs(dx) < 45 || Math.abs(dx) < Math.abs(dy) * 1.2) return;
    moveSelectedGallery(dx < 0 ? 1 : -1);
  }

  function showBanner(index: number) {
    const banners = storefrontConfig.banners;
    if (banners.length < 2) return;
    const currentIndex = bannerIndexRef.current % banners.length;
    const nextIndex = (index + banners.length) % banners.length;
    if (nextIndex === currentIndex) return;
    setOutgoingBanner(banners[currentIndex]);
    bannerIndexRef.current = nextIndex;
    setBannerIndex(nextIndex);
  }

  function finishBannerSwipe(clientX: number) {
    const start = bannerPointerStart.current;
    bannerPointerStart.current = null;
    if (start === null || Math.abs(clientX - start) < 44) return;
    showBanner(bannerIndexRef.current + (clientX < start ? 1 : -1));
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
            <img className="brand-image" src="/paniz-logo.jpg" alt="" />
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
        {sectionIsActive("hero") && <section className="hero" aria-roledescription="کاروسل بنر" aria-labelledby="hero-title"
          onMouseEnter={() => setBannerHovered(true)}
          onMouseLeave={() => setBannerHovered(false)}
          onFocusCapture={() => setBannerFocused(true)}
          onBlurCapture={(event) => { if (!event.currentTarget.contains(event.relatedTarget as Node | null)) setBannerFocused(false); }}
          style={{
            order: sectionOrder("hero", 0),
            backgroundColor: activeBanner?.backgroundColor || "#FCE4DB",
          }}>
          <h1 id="hero-title" className="sr-only">فروشگاه پانیذ</h1>
          <div className="hero-visual" role="group" aria-label={storefrontConfig.banners.length > 1 ? `بنر ${new Intl.NumberFormat("fa-IR").format((bannerIndex % storefrontConfig.banners.length) + 1)} از ${new Intl.NumberFormat("fa-IR").format(storefrontConfig.banners.length)}` : "بنر فروشگاه"} onPointerDown={(event) => { bannerPointerStart.current = event.clientX; event.currentTarget.setPointerCapture(event.pointerId); }} onPointerUp={(event) => finishBannerSwipe(event.clientX)} onPointerCancel={() => { bannerPointerStart.current = null; }}>
            <div className="hero-image-wrap" style={{ backgroundColor: activeBanner?.backgroundColor || "#FCE4DB" }}>
              {failedBannerImageKey === bannerImageKey
                ? <div className="hero-banner-fallback" role="img" aria-label={bannerAltText}>{bannerAltText}</div>
                : <PageFlipImage
                    src={bannerImagePath}
                    alt={bannerAltText}
                    outgoing={outgoingBanner ? { src: outgoingBanner.imagePath, alt: outgoingBanner.altText || "" } : null}
                    direction="next"
                    priority
                    sizes="(max-width: 760px) 100vw, 1200px"
                    className="hero-image"
                    onError={() => setFailedBannerImageKey(bannerImageKey)}
                  />}
            </div>
            {storefrontConfig.banners.length > 1 && <div className="hero-pagination" aria-label="صفحه‌های بنر">
              <span aria-live="polite">{new Intl.NumberFormat("fa-IR").format((bannerIndex % storefrontConfig.banners.length) + 1)} / {new Intl.NumberFormat("fa-IR").format(storefrontConfig.banners.length)}</span>
              <div>{storefrontConfig.banners.map((banner, index) => <button key={banner.id} type="button" aria-label={`رفتن به بنر ${new Intl.NumberFormat("fa-IR").format(index + 1)}`} aria-current={index === bannerIndex % storefrontConfig.banners.length ? "true" : undefined} className={index === bannerIndex % storefrontConfig.banners.length ? "is-active" : ""} onClick={() => showBanner(index)} />)}</div>
            </div>}
          </div>
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

          {catalogSource === "loading" ? (
            <div className="empty-state" role="status" aria-busy="true">
              <strong>در حال دریافت محصولات…</strong>
              <span>کمی صبر کن، فهرست فروشگاه را می‌گیریم.</span>
            </div>
          ) : catalogSource === "error" ? (
            <div className="empty-state" role="alert">
              <strong>محصولات بارگذاری نشدند</strong>
              <span>اتصال فروشگاه را بررسی کن و دوباره تلاش کن.</span>
              <button onClick={() => setCatalogReloadKey((key) => key + 1)}>تلاش دوباره</button>
            </div>
          ) : visibleProducts.length > 0 ? (
            <div className="product-grid">
              {visibleProducts.map((product) => {
                const productUrl = product.slug ? `/products/${encodeURIComponent(product.slug)}` : null;
                return <article className="product-card" key={product.id}>
                  <div className="product-image-area">
                    {productUrl ? <Link className="product-photo-button" href={productUrl} aria-label={`مشاهده ${product.name}`}>
                      <StoreImage
                        src={product.image}
                        alt={product.imageAlt}
                        fill
                        sizes="(max-width: 580px) 45vw, (max-width: 950px) 30vw, 24vw"
                        className="product-image"
                      />
                    </Link> : <button className="product-photo-button" onClick={() => openProduct(product)} aria-label={`مشاهده ${product.name}`}>
                      <StoreImage src={product.image} alt={product.imageAlt} fill sizes="(max-width: 580px) 45vw, (max-width: 950px) 30vw, 24vw" className="product-image" />
                    </button>}
                    {product.badge && <span className={`product-badge ${product.badge.includes("تخفیف") ? "sale" : "fresh"}`}>{product.badge}</span>}
                    <button
                      className={`favorite-button ${favorites.includes(product.id) ? "favorited" : ""}`}
                      onClick={() => toggleFavorite(product.id)}
                      aria-label={favorites.includes(product.id) ? "حذف از علاقه‌مندی‌ها" : "افزودن به علاقه‌مندی‌ها"}
                      aria-pressed={favorites.includes(product.id)}
                    >
                      <Heart size={18} fill={favorites.includes(product.id) ? "currentColor" : "none"} />
                    </button>
                    {productUrl ? <Link className="quick-add" href={productUrl}><Plus size={16} /> {product.available === false ? "جزئیات محصول" : "انتخاب رنگ و سایز"}</Link> : <button className="quick-add" disabled={product.available === false} onClick={() => openProduct(product)}><Plus size={16} /> {product.available === false ? "ناموجود" : "انتخاب سایز"}</button>}
                  </div>
                  <div className="product-details">
                    <span className="product-category">{product.category}</span>
                    {productUrl ? <Link className="product-name" href={productUrl}>{product.name}</Link> : <button className="product-name" onClick={() => openProduct(product)}>{product.name}</button>}
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
                </article>;
              })}
            </div>
          ) : catalogSource === "api" && catalogProducts.length === 0 ? (
            <div className="empty-state">
              <strong>هنوز محصولی ثبت نشده</strong>
              <span>محصولات بعد از ثبت در فروشگاه اینجا نمایش داده می‌شوند.</span>
            </div>
          ) : (
            <div className="empty-state"><Search size={28} /><strong>چیزی پیدا نکردیم</strong><span>یه عبارت دیگه رو امتحان کن یا فیلترها رو بردار.</span><button onClick={() => { setQuery(""); setActiveCategory("همه محصولات"); setFavoritesOnly(false); }}>نمایش همه محصولات</button></div>
          )}

          <div className="load-more-wrap"><span>{catalogSource === "loading" ? "در حال دریافت فهرست محصولات…" : catalogSource === "error" ? "فهرست محصولات در دسترس نیست" : `${money(visibleProducts.length)} محصول از ${money(catalogProducts.length)}`}</span><Link className="outline-button" href="/products">دیدن همه محصولات <ArrowLeft size={17} /></Link></div>
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
          <div className="footer-brand"><a className="brand" href="#top"><img className="brand-image" src="/paniz-logo.jpg" alt="" /><span className="brand-word">پانیذ</span></a><p>پانیذ؛ برای روزهایی که می‌خوای خودت باشی.</p></div>
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
            {(() => {
              const galleryImages = selectedProduct.images?.length
                ? selectedProduct.images
                : [{ id: `${selectedProduct.id}-primary`, path: selectedProduct.image, alt: selectedProduct.imageAlt }];
              const currentImage = galleryImages[Math.min(selectedImageIndex, galleryImages.length - 1)];
              return <div
                className="modal-image quick-gallery"
                data-gallery-direction={galleryDirection}
                role="group"
                aria-label={`تصاویر ${selectedProduct.name}`}
                onMouseEnter={() => setQuickGalleryHovered(true)}
                onMouseLeave={() => setQuickGalleryHovered(false)}
                onFocusCapture={() => setQuickGalleryFocused(true)}
                onBlurCapture={(event) => { if (!event.currentTarget.contains(event.relatedTarget as Node | null)) setQuickGalleryFocused(false); }}
                onTouchStart={(event) => { const touch = event.changedTouches[0]; if (touch) galleryTouchStart.current = { x: touch.clientX, y: touch.clientY }; }}
                onTouchEnd={(event) => { const touch = event.changedTouches[0]; if (touch) finishSelectedGallerySwipe(touch.clientX, touch.clientY); }}
                onTouchCancel={() => { galleryTouchStart.current = null; }}
              >
                <PageFlipImage key={selectedProduct.id} className="quick-gallery-current" src={currentImage.path} alt={currentImage.alt || selectedProduct.name} outgoing={quickGalleryOutgoing} direction={galleryDirection} priority sizes="(max-width: 680px) 90vw, 420px" />
                {galleryImages.length > 1 && <>
                  <span className="quick-gallery-count">{new Intl.NumberFormat("fa-IR").format(selectedImageIndex + 1)} / {new Intl.NumberFormat("fa-IR").format(galleryImages.length)}</span>
                </>}
              </div>;
            })()}
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
