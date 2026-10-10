"use client";

import Link from "next/link";
import { Heart, Plus } from "lucide-react";
import { formatToman, productImage, type StoreProduct } from "../lib/catalog";
import { useStorefront } from "../lib/storefront-state";
import { StoreImage } from "./store-image";

export function StoreProductCard({ product }: { product: StoreProduct }) {
  const { favorites, setFavorites } = useStorefront();
  const productId = Number(product.id);
  const isFavorite = favorites.includes(productId);
  const sale = product.compareAtPriceToman && product.priceToman
    ? Math.max(1, Math.round((1 - product.priceToman / product.compareAtPriceToman) * 100))
    : 0;

  function toggleFavorite() {
    if (!Number.isSafeInteger(productId)) return;
    setFavorites((current) => isFavorite ? current.filter((id) => id !== productId) : [...current, productId]);
  }

  return (
    <article className="product-card store-product-card">
      <div className="product-image-area">
        <Link className="product-photo-button" href={`/products/${product.slug}`} aria-label={`مشاهدهٔ ${product.name}`}>
          <StoreImage src={productImage(product)} alt={product.image?.alt || product.name} fill sizes="(max-width: 580px) 45vw, (max-width: 950px) 30vw, 24vw" className="product-image" />
        </Link>
        {sale > 0 && <span className="product-badge sale">{new Intl.NumberFormat("fa-IR").format(sale)}٪ تخفیف</span>}
        {!product.available && <span className="product-badge fresh">ناموجود</span>}
        <button className={`favorite-button ${isFavorite ? "favorited" : ""}`} onClick={toggleFavorite} aria-label={isFavorite ? "حذف از علاقه‌مندی‌ها" : "افزودن به علاقه‌مندی‌ها"} aria-pressed={isFavorite}>
          <Heart size={18} fill={isFavorite ? "currentColor" : "none"} />
        </button>
        <Link className="quick-add" href={`/products/${product.slug}`} aria-disabled={!product.available}>
          <Plus size={16} />{product.available ? "انتخاب رنگ و سایز" : "جزئیات محصول"}
        </Link>
      </div>
      <div className="product-details">
        <span className="product-category">{product.category?.name || "پوشاک زنانه"}</span>
        <Link className="product-name" href={`/products/${product.slug}`}>{product.name}</Link>
        <div className="product-rating unrated">{product.available ? "آمادهٔ انتخاب" : "در حال حاضر ناموجود"}</div>
        <div className="product-price-row">
          <div className="price-stack">
            {product.compareAtPriceToman && <del>{formatToman(product.compareAtPriceToman)}</del>}
            <strong>{product.priceToman === null ? "قیمت نامشخص" : formatToman(product.priceToman)}</strong>
          </div>
          <div className="swatch-list" aria-label="رنگ‌های محصول">{product.colors.slice(0, 3).map((color) => <i key={color.name} style={{ backgroundColor: color.value }} title={color.name} />)}</div>
        </div>
      </div>
    </article>
  );
}
