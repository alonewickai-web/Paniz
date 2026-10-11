"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useId, useRef, useState, type Ref } from "react";
import { Search, X } from "lucide-react";
import { apiBaseUrl, formatToman, productImage, type ProductSuggestionsPayload, type StoreProduct } from "../lib/catalog";
import { StoreImage } from "./store-image";

type SearchStatus = "idle" | "loading" | "ready" | "empty" | "error";

type Props = {
  id: string;
  value?: string;
  onChange?: (value: string) => void;
  inputRef?: Ref<HTMLInputElement>;
  wrapperClassName?: string;
  variant?: "header" | "catalog";
  placeholder?: string;
  shortcut?: string;
  clearable?: boolean;
};

export function ProductSearchAutocomplete({
  id, value, onChange, inputRef, wrapperClassName = "", variant = "header",
  placeholder = "دنبال چی می‌گردی؟", shortcut, clearable = false,
}: Props) {
  const router = useRouter();
  const listboxId = useId();
  const [localValue, setLocalValue] = useState("");
  const [suggestions, setSuggestions] = useState<StoreProduct[]>([]);
  const [status, setStatus] = useState<SearchStatus>("idle");
  const [focused, setFocused] = useState(false);
  const [dismissed, setDismissed] = useState(false);
  const [activeIndex, setActiveIndex] = useState(-1);
  const closeTimer = useRef<number | undefined>(undefined);
  const query = value ?? localValue;
  const isOpen = focused && !dismissed && query.trim().length >= 2 && status !== "idle";

  useEffect(() => {
    const term = query.trim();
    setSuggestions([]);
    setStatus("idle");
    setActiveIndex(-1);
    if (term.length < 2) return;

    const controller = new AbortController();
    const timer = window.setTimeout(() => {
      setStatus("loading");
      const params = new URLSearchParams({ q: term });
      fetch(apiBaseUrl() + "/products/suggestions?" + params.toString(), {
        signal: controller.signal, cache: "no-store",
      })
        .then((response) => response.ok ? response.json() as Promise<ProductSuggestionsPayload> : Promise.reject())
        .then((payload) => {
          if (controller.signal.aborted) return;
          const items = Array.isArray(payload.data) ? payload.data : [];
          setSuggestions(items);
          setStatus(items.length ? "ready" : "empty");
        })
        .catch(() => {
          if (!controller.signal.aborted) setStatus("error");
        });
    }, 250);
    return () => { controller.abort(); window.clearTimeout(timer); };
  }, [query]);

  useEffect(() => () => {
    if (closeTimer.current !== undefined) window.clearTimeout(closeTimer.current);
  }, []);

  function updateQuery(nextValue: string) {
    if (value === undefined) setLocalValue(nextValue);
    onChange?.(nextValue);
    setDismissed(false);
    setActiveIndex(-1);
  }

  function submitSearch(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const term = query.trim();
    if (term) router.push("/products?q=" + encodeURIComponent(term));
  }

  function handleKeyDown(event: React.KeyboardEvent<HTMLInputElement>) {
    if (event.key === "Escape") {
      setDismissed(true);
      setActiveIndex(-1);
      return;
    }
    if (!suggestions.length) return;
    if (event.key === "ArrowDown") {
      event.preventDefault();
      setActiveIndex((current) => current < 0 ? 0 : (current + 1) % suggestions.length);
    } else if (event.key === "ArrowUp") {
      event.preventDefault();
      setActiveIndex((current) => current < 0 ? suggestions.length - 1 : (current - 1 + suggestions.length) % suggestions.length);
    } else if (event.key === "Enter" && activeIndex >= 0) {
      event.preventDefault();
      const product = suggestions[activeIndex];
      if (product) router.push("/products/" + encodeURIComponent(product.slug));
    }
  }

  const formClass = variant === "catalog" ? "store-search-field" : "search-box";
  return (
    <div className={"store-autocomplete " + wrapperClassName}>
      <form className={formClass} action="/products" method="get" role="search" onSubmit={submitSearch}>
        <Search size={variant === "catalog" ? 18 : 19} aria-hidden="true" />
        <label className="sr-only" htmlFor={id}>جست‌وجوی محصولات</label>
        <input
          ref={inputRef} id={id} name="q" type="search" role="combobox"
          aria-autocomplete="list" aria-expanded={isOpen}
          aria-controls={isOpen && status === "ready" ? listboxId : undefined}
          aria-activedescendant={isOpen && activeIndex >= 0 ? listboxId + "-option-" + activeIndex : undefined}
          autoComplete="off" placeholder={placeholder} value={query}
          onFocus={() => {
            if (closeTimer.current !== undefined) window.clearTimeout(closeTimer.current);
            setDismissed(false);
            setFocused(true);
          }}
          onBlur={() => {
            closeTimer.current = window.setTimeout(() => {
              setFocused(false);
              setActiveIndex(-1);
            }, 140);
          }}
          onChange={(event) => updateQuery(event.target.value)}
          onKeyDown={handleKeyDown}
        />
        {clearable && query && <button type="button" onClick={() => updateQuery("")} aria-label="پاک‌کردن جست‌وجو"><X size={16} /></button>}
        {shortcut && <kbd>{shortcut}</kbd>}
      </form>
      {isOpen && <div className="store-suggestions" aria-busy={status === "loading"}>
        {status === "loading" && <div className="store-suggestion-state" role="status">در حال پیدا کردن نزدیک‌ترین محصولات…</div>}
        {status === "empty" && <div className="store-suggestion-state" role="status">محصول نزدیک به این عبارت پیدا نشد.</div>}
        {status === "error" && <div className="store-suggestion-state" role="status">پیشنهادهای جست‌وجو فعلاً در دسترس نیست.</div>}
        {status === "ready" && <div id={listboxId} className="store-suggestion-options" role="listbox" aria-label="پیشنهادهای نزدیک محصولات">{suggestions.map((product, index) => <Link
          role="option" aria-selected={index === activeIndex}
          id={listboxId + "-option-" + index} key={product.id}
          href={"/products/" + encodeURIComponent(product.slug)}
          onMouseDown={(event) => event.preventDefault()}
          onClick={() => setFocused(false)}
          onMouseEnter={() => setActiveIndex(index)}
        >
          <span className="store-suggestion-image"><StoreImage src={productImage(product)} alt="" fill sizes="48px" /></span>
          <span className="store-suggestion-info">
            <strong>{product.name}</strong>
            <small>{product.category?.name ? product.category.name + " · " : ""}{product.priceToman === null ? "قیمت نامشخص" : formatToman(product.priceToman)}</small>
          </span>
        </Link>)}</div>}
      </div>}
    </div>
  );
}
