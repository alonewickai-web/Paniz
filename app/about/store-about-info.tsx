"use client";

import { MapPin, Phone } from "lucide-react";
import { useEffect, useState } from "react";
import { apiBaseUrl } from "../lib/catalog";

type StoreAbout = {
  introTitle: string;
  introDescription: string;
  address: string;
  phone: string;
  rubikaUrl: string;
  instagramUrl: string;
  mapUrl: string;
  latitude: number | null;
  longitude: number | null;
};

const emptyAbout: StoreAbout = {
  introTitle: "",
  introDescription: "",
  address: "",
  phone: "",
  rubikaUrl: "",
  instagramUrl: "",
  mapUrl: "",
  latitude: null,
  longitude: null,
};

export function StoreAboutInfo() {
  const [about, setAbout] = useState<StoreAbout | null>(null);
  const [loadError, setLoadError] = useState(false);
  const [reload, setReload] = useState(0);

  useEffect(() => {
    const controller = new AbortController();
    setLoadError(false);
    void fetch(`${apiBaseUrl()}/storefront/config`, { cache: "no-store", signal: controller.signal })
      .then((response) => {
        if (!response.ok) throw new Error("STORE_ABOUT_LOAD_FAILED");
        return response.json() as Promise<{ data?: { about?: Partial<StoreAbout> } }>;
      })
      .then((payload) => {
        if (!controller.signal.aborted) {
          const saved = payload?.data?.about;
          setAbout({
            introTitle: typeof saved?.introTitle === "string" ? saved.introTitle : "",
            introDescription: typeof saved?.introDescription === "string" ? saved.introDescription : "",
            address: typeof saved?.address === "string" ? saved.address : "",
            phone: typeof saved?.phone === "string" ? saved.phone : "",
            rubikaUrl: typeof saved?.rubikaUrl === "string" ? saved.rubikaUrl : "",
            instagramUrl: typeof saved?.instagramUrl === "string" ? saved.instagramUrl : "",
            mapUrl: typeof saved?.mapUrl === "string" ? saved.mapUrl : "",
            latitude: typeof saved?.latitude === "number" ? saved.latitude : null,
            longitude: typeof saved?.longitude === "number" ? saved.longitude : null,
          });
        }
      })
      .catch(() => {
        if (!controller.signal.aborted) {
          setAbout(emptyAbout);
          setLoadError(true);
        }
      });
    return () => controller.abort();
  }, [reload]);

  if (loadError) {
    return <section className="about-contact-section" aria-label="درباره و اطلاعات تماس پانیذ" role="status">
      <p className="about-contact-empty">دریافت اطلاعات فروشگاه با مشکل روبه‌رو شد.</p>
      <button className="about-retry-button" type="button" onClick={() => setReload((value) => value + 1)}>تلاش دوباره</button>
    </section>;
  }

  if (!about) {
    return <section className="about-contact-section" aria-busy="true" aria-label="اطلاعات تماس پانیذ">
      <div className="about-intro-skeleton" />
      <h2>راه‌های ارتباط با پانیذ</h2>
      <div className="about-contact-skeleton" />
    </section>;
  }

  const instagramHref = safeInstagramUrl(about.instagramUrl);
  const rubikaHref = safeRubikaUrl(about.rubikaUrl);
  const hasLocation = Number.isFinite(about.latitude) && Number.isFinite(about.longitude);
  const latitude = about.latitude ?? 0;
  const longitude = about.longitude ?? 0;
  const mapHref = safeHttpsUrl(about.mapUrl);
  const callHref = phoneHref(about.phone);
  const hasContact = [about.address, about.phone, about.rubikaUrl, about.instagramUrl].some((value) => value.trim()) || hasLocation;
  const mapUrl = hasLocation ? `https://www.openstreetmap.org/export/embed.html?bbox=${longitude - 0.006}%2C${latitude - 0.004}%2C${longitude + 0.006}%2C${latitude + 0.004}&layer=mapnik&marker=${latitude}%2C${longitude}` : null;
  const googleDirections = hasLocation ? `https://www.google.com/maps/dir/?api=1&destination=${latitude},${longitude}` : mapHref;
  const baladDirections = hasLocation ? `https://balad.ir/location?latitude=${latitude}&longitude=${longitude}&zoom=16` : null;
  const neshanDirections = hasLocation ? `https://neshan.org/maps/@${latitude},${longitude},16z` : null;

  return <section className="about-contact-section" aria-label="درباره و اطلاعات تماس پانیذ">
    <h1>{about.introTitle.trim() || "دربارهٔ پانیذ"}</h1>
    {about.introDescription.trim()
      ? <p className="store-info-lead about-intro-description">{about.introDescription}</p>
      : <p className="about-contact-empty">برای نمایش معرفی واقعی فروشگاه، عنوان و متن را در اپ مدیریت، بخش «درباره ما» ثبت کن.</p>}
    <h2>راه‌های ارتباط با پانیذ</h2>
    {!hasContact
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
        {hasLocation && mapUrl && <article className="about-contact-card about-location-card">
          <div className="about-contact-copy"><strong>موقعیت فروشگاه</strong><p>برای مسیریابی، یکی از برنامه‌ها را انتخاب کن.</p></div>
          <iframe className="about-map-frame" title="موقعیت فروشگاه پانیذ روی نقشه" src={mapUrl} loading="lazy" referrerPolicy="no-referrer" />
          <div className="about-map-directions">
            {googleDirections && <a className="about-map-button" href={googleDirections} target="_blank" rel="noreferrer"><span className="map-brand map-google">G</span> مسیریابی با Google Maps</a>}
            {baladDirections && <a className="about-map-button" href={baladDirections} target="_blank" rel="noreferrer"><span className="map-brand map-balad">ب</span> مسیریابی با بلد</a>}
            {neshanDirections && <a className="about-map-button" href={neshanDirections} target="_blank" rel="noreferrer"><span className="map-brand map-neshan">ن</span> مسیریابی با نشان</a>}
          </div>
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
