"use client";

import Link from "next/link";
import { ShoppingBag } from "lucide-react";
import { createContext, useCallback, useContext, useEffect, useMemo, useState, type Dispatch, type SetStateAction } from "react";

export type CartLine = {
  key: string;
  productId: number;
  productSlug?: string;
  size: string;
  color: string;
  quantity: number;
  variantId?: string;
  unitPrice?: number;
};

type StorefrontState = {
  cart: CartLine[];
  setCart: Dispatch<SetStateAction<CartLine[]>>;
  favorites: number[];
  setFavorites: Dispatch<SetStateAction<number[]>>;
  notifyCartAdded: () => void;
  ready: boolean;
};

const StorefrontContext = createContext<StorefrontState | null>(null);

export function StorefrontProvider({ children }: Readonly<{ children: React.ReactNode }>) {
  const [cart, setCart] = useState<CartLine[]>([]);
  const [favorites, setFavorites] = useState<number[]>([]);
  const [ready, setReady] = useState(false);
  const [cartNoticeRevision, setCartNoticeRevision] = useState(0);
  const [cartNoticeVisible, setCartNoticeVisible] = useState(false);

  const notifyCartAdded = useCallback(() => {
    setCartNoticeRevision((revision) => revision + 1);
    setCartNoticeVisible(true);
  }, []);

  useEffect(() => {
    function restore() {
      try {
        const savedCart = window.localStorage.getItem("panizstyle-cart");
        const savedFavorites = window.localStorage.getItem("panizstyle-favorites");
        if (savedCart) setCart(sanitizeCart(JSON.parse(savedCart)));
        if (savedFavorites) setFavorites(sanitizeFavorites(JSON.parse(savedFavorites)));
      } catch {
        window.localStorage.removeItem("panizstyle-cart");
        window.localStorage.removeItem("panizstyle-favorites");
        setCart([]);
        setFavorites([]);
      }
      setReady(true);
    }

    function onStorage(event: StorageEvent) {
      if (event.key === "panizstyle-cart" || event.key === "panizstyle-favorites") restore();
    }

    restore();
    window.addEventListener("storage", onStorage);
    return () => window.removeEventListener("storage", onStorage);
  }, []);

  useEffect(() => {
    if (ready) window.localStorage.setItem("panizstyle-cart", JSON.stringify(cart));
  }, [cart, ready]);

  useEffect(() => {
    if (ready) window.localStorage.setItem("panizstyle-favorites", JSON.stringify(favorites));
  }, [favorites, ready]);

  useEffect(() => {
    if (!cartNoticeRevision) return;
    const timeout = window.setTimeout(() => setCartNoticeVisible(false), 10_000);
    return () => window.clearTimeout(timeout);
  }, [cartNoticeRevision]);

  const value = useMemo(() => ({ cart, setCart, favorites, setFavorites, notifyCartAdded, ready }), [cart, favorites, notifyCartAdded, ready]);
  return <StorefrontContext.Provider value={value}>
    {children}
    {cartNoticeVisible && <Link key={cartNoticeRevision} className="cart-added-notice" href="/cart" aria-live="polite" aria-label="رفتن به سبد خرید">
      <span className="cart-added-notice-watch" aria-hidden="true">
        <svg viewBox="0 0 40 42" focusable="false">
          <rect className="cart-added-watch-crown" x="16" y="1.5" width="8" height="4" rx="1.5" />
          <path className="cart-added-watch-neck" d="M17 5.5h6v3h-6z" />
          <circle className="cart-added-watch-face" cx="20" cy="23" r="15" />
          <circle className="cart-added-watch-track" cx="20" cy="23" r="15" />
          <circle className="cart-added-watch-progress" cx="20" cy="23" r="15" />
          <path className="cart-added-watch-hands" d="M20 14v9l6 4" />
        </svg>
      </span>
      <ShoppingBag size={18} aria-hidden="true" />
      <span>سبد خرید</span>
    </Link>}
  </StorefrontContext.Provider>;
}

export function useStorefront() {
  const value = useContext(StorefrontContext);
  if (!value) throw new Error("useStorefront must be used inside StorefrontProvider.");
  return value;
}

function sanitizeCart(value: unknown): CartLine[] {
  if (!Array.isArray(value)) return [];
  return value.filter((item): item is CartLine => {
    if (!item || typeof item !== "object") return false;
    const line = item as Partial<CartLine>;
    return typeof line.key === "string"
      && Number.isSafeInteger(line.productId)
      && typeof line.size === "string"
      && typeof line.color === "string"
      && Number.isInteger(line.quantity)
      && (line.quantity ?? 0) > 0;
  }).map((line) => ({ ...line, productSlug: line.productSlug ?? "" } as CartLine));
}

function sanitizeFavorites(value: unknown): number[] {
  if (!Array.isArray(value)) return [];
  return [...new Set(value.filter((id): id is number => Number.isSafeInteger(id)))];
}
