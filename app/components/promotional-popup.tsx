"use client";

import { useEffect, useState } from "react";
import { X } from "lucide-react";
import { apiBaseUrl, publicImageUrl } from "../lib/catalog";

type StorePopup = {
  enabled: boolean;
  imagePath: string | null;
  linkUrl: string | null;
  updatedAt: string | null;
};

const popupDismissKey = "panizstyle:promo-popup-dismissed:";

export function PromotionalPopup() {
  const [popup, setPopup] = useState<StorePopup | null>(null);

  useEffect(() => {
    let cancelled = false;

    const loadPopup = async () => {
      try {
        const response = await fetch(`${apiBaseUrl()}/storefront/config`, { cache: "no-store" });
        if (!response.ok) return;
        const payload = await response.json() as { data?: { popup?: Partial<StorePopup> } };
        const candidate = payload.data?.popup;
        if (cancelled || candidate?.enabled !== true || !candidate.imagePath) return;

        const nextPopup: StorePopup = {
          enabled: true,
          imagePath: candidate.imagePath,
          linkUrl: safePopupLink(candidate.linkUrl),
          updatedAt: candidate.updatedAt ?? null,
        };
        const version = nextPopup.updatedAt || `${nextPopup.imagePath}:${nextPopup.linkUrl ?? ""}`;
        try {
          if (window.sessionStorage.getItem(popupDismissKey + version)) return;
          window.sessionStorage.setItem(popupDismissKey + version, "shown");
        } catch { /* Storage can be unavailable in private browsing. */ }
        setPopup(nextPopup);
      } catch { /* The promotional popup is optional when the API is unavailable. */ }
    };

    window.addEventListener("paniz:entry-prompts-finished", loadPopup);
    return () => {
      cancelled = true;
      window.removeEventListener("paniz:entry-prompts-finished", loadPopup);
    };
  }, []);

  useEffect(() => {
    if (!popup) return;
    const previousOverflow = document.body.style.overflow;
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") dismiss();
    };
    document.body.style.overflow = "hidden";
    window.addEventListener("keydown", onKeyDown);
    return () => {
      document.body.style.overflow = previousOverflow;
      window.removeEventListener("keydown", onKeyDown);
    };
  }, [popup]);

  function dismiss() {
    if (!popup) return;
    const version = popup.updatedAt || `${popup.imagePath}:${popup.linkUrl ?? ""}`;
    try { window.sessionStorage.setItem(popupDismissKey + version, "closed"); } catch { /* The close button still works without storage. */ }
    setPopup(null);
  }

  if (!popup?.imagePath) return null;
  const image = <img className="promo-popup-image" src={publicImageUrl(popup.imagePath)} alt="پیشنهاد ویژهٔ پانیذ" />;
  const externalTarget = popup.linkUrl ? /^https:\/\//i.test(popup.linkUrl) : false;

  return <div className="promo-popup-backdrop" onMouseDown={(event) => { if (event.target === event.currentTarget) dismiss(); }}>
    <section className="promo-popup-card" role="dialog" aria-modal="true" aria-label="پیشنهاد ویژهٔ پانیذ">
      <button className="promo-popup-close" type="button" onClick={dismiss} aria-label="بستن پیشنهاد"><X size={20} /></button>
      {popup.linkUrl
        ? <a className="promo-popup-image-link" href={popup.linkUrl} target={externalTarget ? "_blank" : undefined} rel={externalTarget ? "noreferrer" : undefined}>{image}</a>
        : image}
    </section>
  </div>;
}

function safePopupLink(value: string | null | undefined): string | null {
  const link = value?.trim();
  if (!link) return null;
  if (link.startsWith("/") && !link.startsWith("//") && !link.split("/").includes("..")) return link;
  try {
    const parsed = new URL(link);
    return parsed.protocol === "https:" ? parsed.toString() : null;
  } catch {
    return null;
  }
}
