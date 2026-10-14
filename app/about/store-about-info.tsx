"use client";

import { MapPin, MapPinned, Phone } from "lucide-react";
import { useEffect, useState } from "react";
import { apiBaseUrl } from "../lib/catalog";

type StoreAbout = {
  address: string;
  phone: string;
  rubikaUrl: string;
  instagramUrl: string;
  physicalAddress: string;
  mapUrl: string;
};

const emptyAbout: StoreAbout = {
  address: "",
  phone: "",
  rubikaUrl: "",
  instagramUrl: "",
  physicalAddress: "",
  mapUrl: "",
};

export function StoreAboutInfo() {
  const [about, setAbout] = useState<StoreAbout | null>(null);

  useEffect(() => {
    const controller = new AbortController();
    void fetch(`${apiBaseUrl()}/storefront/config`, { cache: "no-store", signal: controller.signal })
      .then((response) => response.ok ? response.json() as Promise<{ data?: { about?: Partial<StoreAbout> } }> : null)
      .then((payload) => {
        if (!controller.signal.aborted) {
          const saved = payload?.data?.about;
          setAbout(Object.fromEntries(Object.keys(emptyAbout).map((key) => {
            const value = saved?.[key as keyof StoreAbout];
            return [key, typeof value === "string" ? value : ""];
          })) as StoreAbout);
        }
      })
      .catch(() => {
        if (!controller.signal.aborted) setAbout(emptyAbout);
      });
    return () => controller.abort();
  }, []);

  if (!about) {
    return <section className="about-contact-section" aria-busy="true" aria-label="اطلاعات تماس پانیذ">
      <h2>راه‌های ارتباط با پانیذ</h2>
      <div className="about-contact-skeleton" />
    </section>;
  }

  const instagramHref = safeInstagramUrl(about.instagramUrl);
  const rubikaHref = safeRubikaUrl(about.rubikaUrl);
  const mapHref = safeHttpsUrl(about.mapUrl);
  const callHref = phoneHref(about.phone);

  return <section className="about-contact-section" aria-label="اطلاعات تماس پانیذ">
    <h2>راه‌های ارتباط با پانیذ</h2>
    {Object.values(about).every((value) => !value.trim())
      ? <p className="about-contact-empty">اطلاعات تماس هنوز در تنظیمات فروشگاه ثبت نشده است.</p>
      : <div className="about-contact-grid">
        {about.address.trim() && <article className="about-contact-card">
          <span className="about-contact-icon"><MapPin size={20} /></span>
          <div className="about-contact-copy"><strong>نشانی فروشگاه</strong><p>{about.address}</p></div>
        </article>}
        {about.phone.trim() && <article className="about-contact-card">
          <span className="about-contact-icon"><Phone size={20} /></span>
          <div className="about-contact-copy"><strong>شمارهٔ تماس</strong><p dir="ltr">{about.phone}</p></div>
          {callHref && <a className="about-call-button" href={callHref} aria-label={`تماس با پانیذ، ${about.phone}`}><Phone size={16} /> تماس</a>}
        </article>}
        {about.rubikaUrl.trim() && (rubikaHref
          ? <a className="about-contact-card about-contact-link" href={rubikaHref} target="_blank" rel="noreferrer"><RubikaMark /><div className="about-contact-copy"><strong>کانال روبیکا</strong><p>مشاهدهٔ کانال پانیذ</p></div></a>
          : <article className="about-contact-card"><RubikaMark /><div className="about-contact-copy"><strong>کانال روبیکا</strong><p>{about.rubikaUrl}</p></div></article>)}
        {about.instagramUrl.trim() && (instagramHref
          ? <a className="about-contact-card about-contact-link" href={instagramHref} target="_blank" rel="noreferrer"><span className="about-contact-icon instagram-contact-icon"><InstagramMark /></span><div className="about-contact-copy"><strong>اینستاگرام پانیذ</strong><p>{about.instagramUrl}</p></div></a>
          : <article className="about-contact-card"><span className="about-contact-icon instagram-contact-icon"><InstagramMark /></span><div className="about-contact-copy"><strong>اینستاگرام پانیذ</strong><p>پیوند واردشده معتبر نیست</p></div></article>)}
        {about.physicalAddress.trim() && <article className="about-contact-card about-contact-card-wide">
          <span className="about-contact-icon"><MapPinned size={20} /></span>
          <div className="about-contact-copy"><strong>خرید حضوری</strong><p>{about.physicalAddress}</p></div>
          {mapHref && <a className="about-map-button" href={mapHref} target="_blank" rel="noreferrer">نمایش روی نقشه <MapPin size={15} /></a>}
        </article>}
      </div>}
  </section>;
}

function safeHttpsUrl(value: string) {
  try {
    const url = new URL(value.trim());
    return url.protocol === "https:" ? url.toString() : null;
  } catch {
    return null;
  }
}

function safeInstagramUrl(value: string) {
  const trimmed = value.trim();
  const direct = safeHttpsUrl(trimmed);
  if (direct) {
    const host = new URL(direct).hostname.toLowerCase();
    return host === "instagram.com" || host.endsWith(".instagram.com") ? direct : null;
  }
  const username = trimmed.replace(/^@/, "");
  return /^[a-zA-Z0-9._]{1,30}$/.test(username) ? `https://www.instagram.com/${username}/` : null;
}

function safeRubikaUrl(value: string) {
  const trimmed = value.trim();
  const direct = safeHttpsUrl(trimmed);
  if (direct) {
    const host = new URL(direct).hostname.toLowerCase();
    return host === "rubika.ir" || host === "www.rubika.ir" ? direct : null;
  }
  const channel = trimmed.replace(/^@/, "").replace(/^\/+/, "");
  return /^[a-zA-Z0-9._-]{2,100}$/.test(channel) ? `https://rubika.ir/${channel}` : null;
}

function phoneHref(value: string) {
  const persianDigits = "۰۱۲۳۴۵۶۷۸۹";
  const arabicDigits = "٠١٢٣٤٥٦٧٨٩";
  const ascii = value.replace(/[۰-۹٠-٩]/g, (digit) => {
    const index = persianDigits.indexOf(digit);
    return String(index >= 0 ? index : arabicDigits.indexOf(digit));
  });
  const number = ascii.replace(/[^\d+]/g, "");
  return /^\+?\d{5,15}$/.test(number) ? `tel:${number}` : null;
}

function RubikaMark() {
  return <span className="about-contact-icon rubika-contact-icon" aria-hidden="true">
    <svg viewBox="0 0 32 32" focusable="false">
      <path d="M10 24V10.5A4.5 4.5 0 0 1 14.5 6h4a5 5 0 0 1 0 10H14m1 0 8 8" />
    </svg>
  </span>;
}

function InstagramMark() {
  return <svg viewBox="0 0 32 32" aria-hidden="true" focusable="false">
    <rect x="4.5" y="4.5" width="23" height="23" rx="7" />
    <circle cx="16" cy="16" r="5.2" />
    <circle cx="23.3" cy="8.9" r="1.2" className="instagram-mark-dot" />
  </svg>;
}
