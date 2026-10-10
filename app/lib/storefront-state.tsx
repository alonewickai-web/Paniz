"use client";

import { createContext, useContext, useEffect, useMemo, useState, type Dispatch, type SetStateAction } from "react";

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
  ready: boolean;
};

const StorefrontContext = createContext<StorefrontState | null>(null);

export function StorefrontProvider({ children }: Readonly<{ children: React.ReactNode }>) {
  const [cart, setCart] = useState<CartLine[]>([]);
  const [favorites, setFavorites] = useState<number[]>([]);
  const [ready, setReady] = useState(false);

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

  const value = useMemo(() => ({ cart, setCart, favorites, setFavorites, ready }), [cart, favorites, ready]);
  return <StorefrontContext.Provider value={value}>{children}</StorefrontContext.Provider>;
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
