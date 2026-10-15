"use client";

import Link from "next/link";
import dynamic from "next/dynamic";
import { useRouter } from "next/navigation";
import { useEffect, useMemo, useState, type FormEvent } from "react";
import { ArrowLeft, Check, LogOut, MapPin, MessageCircle, Package, Pencil, Plus, ShieldCheck, Smartphone, Trash2, UserRound } from "lucide-react";
import { StorefrontShell } from "../components/storefront-shell";
import { formatToman } from "../lib/catalog";
import { CustomerApiError, customerApi, customerAssetUrl, type CustomerAddress, type CustomerOrder, type CustomerProfile } from "../lib/customer-api";
import iranGeography from "../data/iran-geography.json";
import { JalaliDatePicker } from "../components/jalali-date-picker";

const AddressLocationPicker = dynamic(
  () => import("../components/address-location-picker").then((module) => module.AddressLocationPicker),
  { ssr: false, loading: () => <div className="address-map-loading" aria-label="در حال آماده‌سازی نقشه" /> },
);

const provinces = iranGeography.provinces;
const cities = iranGeography.cities;

type AddressForm = {
  title: string;
  recipientName: string;
  recipientPhone: string;
  province: string;
  city: string;
  street: string;
  alley: string;
  plaqueNumber: string;
  floor: string;
  unit: string;
  backupPhone: string;
  latitude: number | null;
  longitude: number | null;
  deliveryDetails: string;
  postalCode: string;
  isDefault: boolean;
};

type SupportTicket = { id: string; subject: string; status: string; createdAt: string; lastMessageAt: string; messages: { id: string; senderType: string; body: string; imagePath: string | null; createdAt: string }[] };
type CustomerReturn = { id: string; orderNumber: string; reason: string; status: string; adminNote: string | null; refundReceiptPath: string | null; requestedAt: string; refundAmountToman: number };

function cityLocation(province: string, city: string) {
  const provinceId = provinces.find((item) => item.name === province)?.id;
  return cities.find((item) => item.provinceId === provinceId && item.name === city) ?? null;
}

const emptyAddress = (phone = "", recipientName = ""): AddressForm => ({
  title: "خانه", recipientName, recipientPhone: phone, province: "", city: "", street: "", alley: "",
  plaqueNumber: "", floor: "", unit: "", backupPhone: "", latitude: null, longitude: null,
  deliveryDetails: "", postalCode: "", isDefault: false,
});

const orderStatus: Record<string, string> = {
  pending_payment: "در انتظار پرداخت", paid: "پرداخت‌شده", confirmed: "تأییدشده", preparing: "در حال آماده‌سازی",
  shipped: "تحویل به شرکت حمل‌ونقل", delivered: "تحویل‌شده", cancelled: "لغوشده", expired: "مهلت رزرو تمام شده", returned: "مرجوع‌شده",
};
const returnStatus: Record<string, string> = { requested: "در انتظار بررسی", approved: "درخواست تأیید شد", received: "کالای مرجوعی دریافت شد", refunded: "وجه بازگردانده شد", rejected: "درخواست پذیرفته نشد" };

export default function AccountPage() {
  const router = useRouter();
  const [booting, setBooting] = useState(true);
  const [profile, setProfile] = useState<CustomerProfile | null>(null);
  const [orders, setOrders] = useState<CustomerOrder[]>([]);
  const [supportTickets, setSupportTickets] = useState<SupportTicket[]>([]);
  const [returns, setReturns] = useState<CustomerReturn[]>([]);
  const [phone, setPhone] = useState("");
  const [code, setCode] = useState("");
  const [codeSent, setCodeSent] = useState(false);
  const [resendSeconds, setResendSeconds] = useState(0);
  const [developmentCode, setDevelopmentCode] = useState(false);
  const [profileForm, setProfileForm] = useState({ fullName: "", birthDateJalali: "", email: "", marketingOptIn: false });
  const [addressForm, setAddressForm] = useState<AddressForm>(emptyAddress());
  const [editingAddressId, setEditingAddressId] = useState<string | null>(null);
  const [addressFormOpen, setAddressFormOpen] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");

  const nextPath = useMemo(() => {
    if (typeof window === "undefined") return "";
    const candidate = new URLSearchParams(window.location.search).get("next") ?? "";
    return candidate.startsWith("/") && !candidate.startsWith("//") ? candidate : "";
  }, []);

  async function refreshAccount() {
    const customer = await customerApi<CustomerProfile>("/customer/profile");
    const [customerOrders, customerTickets, customerReturns] = await Promise.all([
      customerApi<CustomerOrder[]>("/customer/orders"),
      customerApi<SupportTicket[]>("/customer/support/tickets"),
      customerApi<CustomerReturn[]>("/customer/returns"),
    ]);
    setProfile(customer);
    setOrders(customerOrders);
    setSupportTickets(customerTickets);
    setReturns(customerReturns);
    setProfileForm({
      fullName: customer.fullName ?? "", birthDateJalali: customer.birthDateJalali ?? "", email: customer.email ?? "",
      marketingOptIn: customer.marketingOptIn,
    });
    setAddressForm((current) => ({ ...current, recipientPhone: current.recipientPhone || customer.phone, recipientName: current.recipientName || customer.fullName || "" }));
    return customer;
  }

  useEffect(() => {
    void refreshAccount().catch((reason: unknown) => {
      if (!(reason instanceof CustomerApiError) || reason.status !== 401) {
        setError(reason instanceof Error ? reason.message : "دریافت حساب کاربری انجام نشد.");
      }
      setProfile(null);
    }).finally(() => setBooting(false));
  }, []);

  useEffect(() => {
    const lastPhone = window.sessionStorage.getItem("panizstyle:otp:last-phone");
    if (!lastPhone) return;
    setPhone(lastPhone);
    setCodeSent(true);
    setResendSeconds(Math.max(0, Math.ceil((Number(window.sessionStorage.getItem(`panizstyle:otp:${lastPhone}`) || 0) - Date.now()) / 1000)));
  }, []);

  useEffect(() => {
    if (!codeSent || !phone || typeof window === "undefined") return;
    const storageKey = `panizstyle:otp:${phone}`;
    const updateCountdown = () => {
      const until = Number(window.sessionStorage.getItem(storageKey) || 0);
      setResendSeconds(Math.max(0, Math.ceil((until - Date.now()) / 1000)));
    };
    updateCountdown();
    const timer = window.setInterval(updateCountdown, 1000);
    return () => window.clearInterval(timer);
  }, [codeSent, phone]);

  async function requestCode() {
    setBusy(true); setError(""); setNotice("");
    try {
      const result = await customerApi<{ phone: string; expiresAt: string; retryAfterSeconds: number; developmentCode?: string }>("/customer/auth/send-code", {
        method: "POST", body: JSON.stringify({ phone }),
      });
      setPhone(result.phone);
      setCodeSent(true);
      const resendAt = Date.now() + result.retryAfterSeconds * 1000;
      window.sessionStorage.setItem(`panizstyle:otp:${result.phone}`, String(resendAt));
      window.sessionStorage.setItem("panizstyle:otp:last-phone", result.phone);
      setResendSeconds(result.retryAfterSeconds);
      if (result.developmentCode) {
        setCode(result.developmentCode);
        setDevelopmentCode(true);
        setNotice("کد آزمایشی در همین محیط آماده شد؛ برای پیامک واقعی باید سرویس پیامک فروشگاه تنظیم شود.");
      } else {
        setDevelopmentCode(false);
        setNotice("کد ورود برای شمارهٔ همراهت ارسال شد.");
      }
    } catch (reason) {
      if (reason instanceof CustomerApiError && reason.retryAfterSeconds) setResendSeconds(reason.retryAfterSeconds);
      setError(reason instanceof Error ? reason.message : "ارسال کد انجام نشد.");
    } finally { setBusy(false); }
  }

  async function sendCode(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    await requestCode();
  }

  async function resendCode() {
    if (busy || resendSeconds > 0) return;
    await requestCode();
  }

  async function verifyCode(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setBusy(true); setError(""); setNotice("");
    try {
      await customerApi("/customer/auth/verify-code", { method: "POST", body: JSON.stringify({ phone, code: asciiDigits(code) }) });
      window.sessionStorage.removeItem(`panizstyle:otp:${phone}`);
      window.sessionStorage.removeItem("panizstyle:otp:last-phone");
      const customer = await refreshAccount();
      if (!customer.fullName?.trim()) setNotice("شماره‌ات تأیید شد. برای تکمیل حساب، نام و نام خانوادگی‌ات را ثبت کن.");
      else if (nextPath && customer.addresses.length > 0) router.replace(nextPath);
      else setNotice("وارد حساب شدی. نشانی‌ات را ذخیره کن تا خرید را ادامه بدهی.");
    } catch (reason) {
      if (reason instanceof CustomerApiError && reason.retryAfterSeconds) setResendSeconds(reason.retryAfterSeconds);
      setError(reason instanceof Error ? reason.message : "تأیید کد انجام نشد.");
    } finally { setBusy(false); }
  }

  async function saveProfile(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); setBusy(true); setError(""); setNotice("");
    try {
      if (!profileForm.birthDateJalali) throw new Error("تاریخ تولد را از تقویم انتخاب کن.");
      await customerApi("/customer/profile", { method: "PATCH", body: JSON.stringify({ ...profileForm, birthDateJalali: profileForm.birthDateJalali || null }) });
      await refreshAccount();
      setNotice("اطلاعات حساب ذخیره شد.");
    } catch (reason) { setError(reason instanceof Error ? reason.message : "ذخیرهٔ اطلاعات انجام نشد."); }
    finally { setBusy(false); }
  }

  function beginAddressEdit(address?: CustomerAddress) {
    setEditingAddressId(address?.id ?? null);
    setAddressForm(address ? {
      title: address.title ?? "", recipientName: address.recipientName, recipientPhone: address.recipientPhone,
      province: address.province, city: address.city, street: address.street ?? "", alley: address.alley ?? "",
      plaqueNumber: address.plaqueNumber ?? "", floor: address.floor ?? "", unit: address.unit ?? "", backupPhone: address.backupPhone ?? "",
      latitude: address.latitude, longitude: address.longitude, deliveryDetails: address.deliveryDetails ?? "",
      postalCode: address.postalCode, isDefault: address.isDefault,
    } : emptyAddress(profile?.phone ?? "", profile?.fullName ?? ""));
    setAddressFormOpen(true); setError(""); setNotice("");
  }

  async function saveAddress(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); setBusy(true); setError(""); setNotice("");
    try {
      if (!addressForm.unit.trim()) throw new Error("شمارهٔ واحد را وارد کن.");
      if (addressForm.latitude === null || addressForm.longitude === null) throw new Error("موقعیت دقیق نشانی را روی نقشه انتخاب کن.");
      await customerApi(editingAddressId ? `/customer/addresses/${editingAddressId}` : "/customer/addresses", {
        method: editingAddressId ? "PATCH" : "POST", body: JSON.stringify({ ...addressForm, postalCode: asciiDigits(addressForm.postalCode), backupPhone: addressForm.backupPhone.trim() || undefined }),
      });
      const customer = await refreshAccount();
      setAddressFormOpen(false); setEditingAddressId(null);
      setNotice("نشانی با موفقیت ذخیره شد.");
      if (nextPath && customer.addresses.length > 0) router.replace(nextPath);
    } catch (reason) { setError(reason instanceof Error ? reason.message : "ذخیرهٔ نشانی انجام نشد."); }
    finally { setBusy(false); }
  }

  async function setDefault(addressId: string) {
    setBusy(true); setError(""); setNotice("");
    try { await customerApi(`/customer/addresses/${addressId}/default`, { method: "POST" }); await refreshAccount(); setNotice("نشانی پیش‌فرض تغییر کرد."); }
    catch (reason) { setError(reason instanceof Error ? reason.message : "تغییر نشانی پیش‌فرض انجام نشد."); }
    finally { setBusy(false); }
  }

  async function deleteAddress(address: CustomerAddress) {
    if (!window.confirm(`نشانی «${address.title || address.city}» حذف شود؟`)) return;
    setBusy(true); setError(""); setNotice("");
    try { await customerApi(`/customer/addresses/${address.id}`, { method: "DELETE" }); await refreshAccount(); setNotice("نشانی حذف شد."); }
    catch (reason) { setError(reason instanceof Error ? reason.message : "حذف نشانی انجام نشد."); }
    finally { setBusy(false); }
  }

  async function createSupportTicket(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); setBusy(true); setError(""); setNotice("");
    const target = event.currentTarget;
    const form = new FormData(target);
    try {
      const imagePath = await uploadSupportImage(form.get("image"));
      await customerApi("/customer/support/tickets", { method: "POST", body: JSON.stringify({ subject: form.get("subject"), message: form.get("message"), imagePath }) });
      target.reset(); await refreshAccount(); setNotice("درخواست پشتیبانی ثبت شد.");
    } catch (reason) { setError(reason instanceof Error ? reason.message : "ثبت درخواست انجام نشد."); }
    finally { setBusy(false); }
  }

  async function replySupportTicket(event: FormEvent<HTMLFormElement>, ticketId: string) {
    event.preventDefault(); setBusy(true); setError(""); setNotice("");
    const target = event.currentTarget;
    const form = new FormData(target);
    try {
      const imagePath = await uploadSupportImage(form.get("image"));
      await customerApi(`/customer/support/tickets/${ticketId}/messages`, { method: "POST", body: JSON.stringify({ body: form.get("body"), imagePath }) });
      target.reset(); await refreshAccount(); setNotice("پیامت برای پشتیبان فرستاده شد.");
    } catch (reason) { setError(reason instanceof Error ? reason.message : "ارسال پیام انجام نشد."); }
    finally { setBusy(false); }
  }

  async function uploadSupportImage(value: FormDataEntryValue | null): Promise<string | undefined> {
    if (!(value instanceof File) || value.size === 0) return undefined;
    if (value.size > 5 * 1024 * 1024) throw new Error("حجم تصویر باید کمتر از ۵ مگابایت باشد.");
    if (!["image/jpeg", "image/png", "image/webp"].includes(value.type)) throw new Error("تصویر باید JPG، PNG یا WebP باشد.");
    const upload = new FormData(); upload.set("file", value);
    const result = await customerApi<{ imagePath: string }>("/customer/support/uploads/image", { method: "POST", body: upload });
    return result.imagePath;
  }

  async function createReturn(event: FormEvent<HTMLFormElement>, orderNumber: string) {
    event.preventDefault(); setBusy(true); setError(""); setNotice("");
    const form = new FormData(event.currentTarget);
    try {
      await customerApi(`/customer/orders/${encodeURIComponent(orderNumber)}/return`, { method: "POST", body: JSON.stringify({ reason: form.get("reason"), iban: asciiDigits(String(form.get("iban") ?? "")).replace(/\s/g, "").toUpperCase(), cardNumber: asciiDigits(String(form.get("cardNumber") ?? "")).replace(/\D/g, "") }) });
      event.currentTarget.reset(); await refreshAccount(); setNotice("درخواست مرجوعی ثبت شد. وضعیتش را همین‌جا می‌بینی.");
    } catch (reason) { setError(reason instanceof Error ? reason.message : "ثبت مرجوعی انجام نشد."); }
    finally { setBusy(false); }
  }

  async function logout() {
    setBusy(true);
    try { await customerApi("/customer/auth/logout", { method: "POST" }); setProfile(null); setOrders([]); setCodeSent(false); setNotice("از حساب خارج شدی."); }
    catch (reason) { setError(reason instanceof Error ? reason.message : "خروج از حساب انجام نشد."); }
    finally { setBusy(false); }
  }

  if (booting) return <StorefrontShell><main className="store-page"><div className="page-shell store-message">در حال بررسی حساب کاربری…</div></main></StorefrontShell>;

  return (
    <StorefrontShell>
      <main className="store-page"><div className="page-shell customer-account-page">
        <nav className="store-breadcrumb" aria-label="مسیر صفحه"><Link href="/">خانه</Link><span>/</span><span>حساب کاربری</span></nav>
        <div className="store-page-heading customer-heading"><div><span className="section-kicker">همراه پانیذ</span><h1>{profile ? `سلام ${profile.fullName || "عزیزم"}` : "ورود به حساب کاربری"}</h1><p>{profile ? "اطلاعات و نشانی‌های ذخیره‌شده‌ات را مدیریت کن." : "برای خرید، پیگیری سفارش‌ها و ذخیرهٔ نشانی‌ها با شمارهٔ موبایلت وارد شو."}</p></div>
          {profile && <button className="outline-button customer-logout" type="button" onClick={() => void logout()} disabled={busy}><LogOut size={17} /> خروج از حساب</button>}
        </div>

        {error && <p className="store-inline-error customer-feedback" role="alert">{error}</p>}
        {notice && <p className="customer-feedback customer-feedback-success" role="status"><Check size={16} />{notice}</p>}

        {!profile ? <div className="customer-login-card">
          <div className="customer-login-intro"><span className="customer-icon"><Smartphone size={23} /></span><h2>ورود امن با شمارهٔ موبایل</h2><p>کد یک‌بارمصرف به شماره‌ات ارسال می‌شود. با اولین ورود، حساب کاربری‌ات ساخته خواهد شد.</p><small><ShieldCheck size={15} /> شمارهٔ موبایل برای تأیید هویت و پیگیری سفارش استفاده می‌شود.</small></div>
          {!codeSent ? <form className="customer-login-form" onSubmit={(event) => void sendCode(event)}>
            <label className="store-field"><span>شمارهٔ موبایل</span><input dir="ltr" type="tel" inputMode="tel" autoComplete="tel" required pattern="(?:\+98|0098|0)?9[0-9۰-۹٠-٩]{9}" title="شمارهٔ موبایل معتبر وارد کن" placeholder="۰۹۱۲۱۲۳۴۵۶۷" value={phone} onChange={(event) => setPhone(event.target.value)} /></label>
            <button className="button-primary" type="submit" disabled={busy}>{busy ? "در حال ارسال…" : "دریافت کد ورود"}<ArrowLeft size={18} /></button>
          </form> : <form className="customer-login-form" onSubmit={(event) => void verifyCode(event)}>
            <label className="store-field"><span>کد ۶ رقمی پیامک‌شده</span><input dir="ltr" type="text" inputMode="numeric" autoComplete="one-time-code" required pattern="[0-9۰-۹٠-٩]{6}" maxLength={6} value={code} onChange={(event) => setCode(event.target.value)} /></label>
            {developmentCode && <small className="customer-dev-code">محیط توسعه: کد آزمایشی در فیلد وارد شده است.</small>}
            <button className="button-primary" type="submit" disabled={busy}>{busy ? "در حال تأیید…" : "تأیید و ورود"}<ArrowLeft size={18} /></button>
            <div className="customer-resend-row" aria-live="polite">
              {resendSeconds > 0
                ? <span>ارسال دوبارهٔ کد تا {new Intl.NumberFormat("fa-IR", { minimumIntegerDigits: 2 }).format(Math.floor(resendSeconds / 60))}:{new Intl.NumberFormat("fa-IR", { minimumIntegerDigits: 2 }).format(resendSeconds % 60)}</span>
                : <button className="customer-text-button customer-resend-button" type="button" onClick={() => void resendCode()} disabled={busy}>{busy ? "در حال ارسال…" : "ارسال دوبارهٔ کد"}</button>}
            </div>
            <button className="customer-text-button" type="button" onClick={() => { setCodeSent(false); setCode(""); setError(""); setNotice(""); }}>ویرایش شمارهٔ موبایل</button>
          </form>}
        </div> : <div className="customer-dashboard">
          <section className="customer-section customer-profile-section">
            <div className="customer-section-heading"><span className="customer-section-icon"><UserRound size={19} /></span><div><h2>اطلاعات حساب</h2><p>شمارهٔ تأییدشده و مشخصات تماس تو</p></div></div>
            <div className="customer-verified-phone"><span>شمارهٔ همراه</span><strong dir="ltr">{profile.phone}</strong><small><Check size={14} /> تأییدشده</small></div>
            {!profile.fullName?.trim() && <p className="customer-feedback customer-feedback-success" role="status">برای تکمیل حساب، نام و نام خانوادگی‌ات را وارد کن. ایمیل اختیاری است.</p>}
            <form className="store-form-grid customer-profile-form" onSubmit={(event) => void saveProfile(event)}>
              <label className="store-field"><span>نام و نام خانوادگی</span><input autoComplete="name" autoFocus={!profile.fullName?.trim()} required minLength={2} maxLength={160} value={profileForm.fullName} onChange={(event) => setProfileForm((form) => ({ ...form, fullName: event.target.value }))} /></label>
              <JalaliDatePicker value={profileForm.birthDateJalali} onChange={(birthDateJalali) => setProfileForm((form) => ({ ...form, birthDateJalali }))} />
              <label className="store-field"><span>ایمیل <small>(اختیاری)</small></span><input type="email" autoComplete="email" maxLength={254} value={profileForm.email} onChange={(event) => setProfileForm((form) => ({ ...form, email: event.target.value }))} /></label>
              <label className="customer-default-check store-form-wide"><input type="checkbox" checked={profileForm.marketingOptIn} onChange={(event) => setProfileForm((form) => ({ ...form, marketingOptIn: event.target.checked }))} /><span>مایلم پیشنهادها و محصولات تازهٔ فروشگاه را دریافت کنم. هر زمان بخواهم می‌توانم این گزینه را غیرفعال کنم.</span></label>
              <button className="button-primary customer-save-profile" type="submit" disabled={busy}>{profile.fullName?.trim() ? "ذخیرهٔ اطلاعات" : "ثبت مشخصات و تکمیل حساب"}</button>
            </form>
          </section>

          <section className="customer-section">
            <div className="customer-section-heading"><span className="customer-section-icon"><MapPin size={19} /></span><div><h2>نشانی‌های تحویل</h2><p>کدپستی و نشانی دقیق برای ارسال سفارش‌ها</p></div><button className="outline-button customer-add-address" type="button" onClick={() => beginAddressEdit()}><Plus size={17} /> افزودن نشانی</button></div>
            {profile.addresses.length ? <div className="customer-address-grid">{profile.addresses.map((address) => <article className={`customer-address-card ${address.isDefault ? "is-default" : ""}`} key={address.id}>
              <div className="customer-address-title"><strong>{address.title || "نشانی"}</strong>{address.isDefault && <span>پیش‌فرض</span>}</div>
              <p>{address.recipientName} · <bdi dir="ltr">{address.recipientPhone}</bdi></p>
              <p>{address.province}، {address.city}</p>
              <p>{address.addressLine}</p>
              <p>کدپستی: <bdi dir="ltr">{address.postalCode}</bdi></p>
              <div className="customer-address-actions">
                {!address.isDefault && <button type="button" onClick={() => void setDefault(address.id)} disabled={busy}>پیش‌فرض کردن</button>}
                <button type="button" aria-label={`ویرایش نشانی ${address.title || address.city}`} onClick={() => beginAddressEdit(address)}><Pencil size={15} /> ویرایش</button>
                <button type="button" aria-label={`حذف نشانی ${address.title || address.city}`} onClick={() => void deleteAddress(address)} disabled={busy}><Trash2 size={15} /> حذف</button>
              </div>
            </article>)}</div> : <div className="customer-empty-address"><MapPin size={22} /><p>هنوز نشانی‌ای ذخیره نکرده‌ای. برای نهایی کردن خرید، اول یک نشانی دقیق اضافه کن.</p><button className="button-primary" type="button" onClick={() => beginAddressEdit()}><Plus size={17} /> افزودن نشانی</button></div>}

            {addressFormOpen && <form className="customer-address-form" onSubmit={(event) => void saveAddress(event)}>
              <div className="customer-address-form-heading"><h3>{editingAddressId ? "ویرایش نشانی" : "نشانی تازه"}</h3><button type="button" className="customer-text-button" onClick={() => { setAddressFormOpen(false); setEditingAddressId(null); }}>انصراف</button></div>
              <div className="store-form-grid">
                <label className="store-field"><span>عنوان نشانی</span><input maxLength={80} placeholder="خانه، محل کار…" value={addressForm.title} onChange={(event) => setAddressForm((form) => ({ ...form, title: event.target.value }))} /></label>
                <label className="store-field"><span>نام گیرنده</span><input autoComplete="name" required minLength={2} maxLength={160} value={addressForm.recipientName} onChange={(event) => setAddressForm((form) => ({ ...form, recipientName: event.target.value }))} /></label>
                <label className="store-field"><span>موبایل گیرنده</span><input dir="ltr" type="tel" inputMode="tel" autoComplete="tel" required pattern="(?:\+98|0098|0)?9[0-9۰-۹٠-٩]{9}" value={addressForm.recipientPhone} onChange={(event) => setAddressForm((form) => ({ ...form, recipientPhone: event.target.value }))} /></label>
                <label className="store-field"><span>استان</span><select required value={addressForm.province} onChange={(event) => setAddressForm((form) => ({ ...form, province: event.target.value, city: "", latitude: null, longitude: null }))}><option value="">انتخاب استان</option>{provinces.map((province) => <option key={province.id} value={province.name}>{province.name}</option>)}</select></label>
                <label className="store-field"><span>شهر</span><select autoComplete="address-level2" required disabled={!addressForm.province} value={addressForm.city} onChange={(event) => {
                  const city = event.target.value;
      setAddressForm((form) => ({ ...form, city, latitude: null, longitude: null }));
                }}><option value="">انتخاب شهر</option>{cities.filter((item) => item.provinceId === provinces.find((province) => province.name === addressForm.province)?.id).map((city) => <option key={city.id} value={city.name}>{city.name}</option>)}</select></label>
                <label className="store-field"><span>خیابان اصلی</span><input autoComplete="address-line1" required minLength={2} maxLength={200} value={addressForm.street} onChange={(event) => setAddressForm((form) => ({ ...form, street: event.target.value }))} /></label>
                <label className="store-field"><span>کوچه / خیابان فرعی <small>(در صورت وجود)</small></span><input maxLength={200} value={addressForm.alley} onChange={(event) => setAddressForm((form) => ({ ...form, alley: event.target.value }))} /></label>
                <label className="store-field"><span>پلاک</span><input required maxLength={40} value={addressForm.plaqueNumber} onChange={(event) => setAddressForm((form) => ({ ...form, plaqueNumber: event.target.value }))} /></label>
                <label className="store-field"><span>طبقه</span><input maxLength={40} value={addressForm.floor} onChange={(event) => setAddressForm((form) => ({ ...form, floor: event.target.value }))} /></label>
                <label className="store-field"><span>واحد</span><input required maxLength={40} value={addressForm.unit} onChange={(event) => setAddressForm((form) => ({ ...form, unit: event.target.value }))} /></label>
                <label className="store-field"><span>شمارهٔ تماس جایگزین <small>(اختیاری)</small></span><input dir="ltr" type="tel" inputMode="tel" pattern="(?:\+98|0098|0)?9[0-9۰-۹٠-٩]{9}" value={addressForm.backupPhone} onChange={(event) => setAddressForm((form) => ({ ...form, backupPhone: event.target.value }))} /></label>
                <label className="store-field"><span>کدپستی ۱۰ رقمی</span><input dir="ltr" inputMode="numeric" autoComplete="postal-code" required pattern="[0-9۰-۹٠-٩]{10}" maxLength={10} value={addressForm.postalCode} onChange={(event) => setAddressForm((form) => ({ ...form, postalCode: event.target.value }))} /></label>
                <div className="store-form-wide"><label className="store-field"><span>موقعیت روی نقشه</span></label><AddressLocationPicker latitude={addressForm.latitude} longitude={addressForm.longitude} onChange={(latitude, longitude) => setAddressForm((form) => ({ ...form, latitude, longitude }))} fallbackLatitude={cityLocation(addressForm.province, addressForm.city)?.lat} fallbackLongitude={cityLocation(addressForm.province, addressForm.city)?.lon} /></div>
                <label className="store-field store-form-wide"><span>توضیحات تکمیلی برای پیک <small>(اختیاری)</small></span><textarea maxLength={300} rows={2} placeholder="مثلاً زنگ طبقهٔ دوم سمت راست" value={addressForm.deliveryDetails} onChange={(event) => setAddressForm((form) => ({ ...form, deliveryDetails: event.target.value }))} /></label>
                <label className="customer-default-check"><input type="checkbox" checked={addressForm.isDefault} onChange={(event) => setAddressForm((form) => ({ ...form, isDefault: event.target.checked }))} /><span>این نشانی، نشانی پیش‌فرض خرید باشد</span></label>
              </div>
              <div className="customer-address-form-actions"><button className="button-primary" type="submit" disabled={busy}>{busy ? "در حال ذخیره…" : "ذخیرهٔ نشانی"}<Check size={17} /></button></div>
            </form>}
          </section>

          <section className="customer-section customer-orders-section">
            <div className="customer-section-heading"><span className="customer-section-icon"><Package size={19} /></span><div><h2>سفارش‌های من</h2><p>سفارش‌ها و وضعیت فعلی آن‌ها</p></div></div>
            {orders.length ? <div className="customer-order-list">{orders.map((order) => {
              const returnRequest = returns.find((item) => item.orderNumber === order.orderNumber);
              const progress = order.status === "delivered" ? 3 : order.status === "shipped" ? 2 : order.status === "preparing" ? 1 : 0;
              const closed = ["cancelled", "expired", "returned"].includes(order.status);
              return <article className="customer-order-card" key={order.orderNumber}>
              <div><span className="customer-order-number">{order.orderNumber}</span><small>{new Date(order.placedAt).toLocaleDateString("fa-IR")}</small></div>
              <div className="customer-order-products">{order.items.map((item, index) => <span key={`${item.name}-${index}`}>{item.name} · {item.color} · {item.size} × {new Intl.NumberFormat("fa-IR").format(item.quantity)}</span>)}</div>
              <div className="customer-order-total"><span className={`customer-order-status status-${order.status}`}>{orderStatus[order.status] ?? order.status}</span><strong>{formatToman(order.totalToman)}</strong></div>
              {!closed && <div className="customer-order-expanded">
                <ol className="customer-order-progress" aria-label="مراحل سفارش">{["منتظر تأیید سفارش", "در حال آماده‌سازی", "تحویل پست شد", "تحویل سفارش"].map((step, index) => <li className={index < progress ? "done" : index === progress ? "current" : ""} key={step}><span>{index < progress ? "✓" : new Intl.NumberFormat("fa-IR").format(index + 1)}</span><small>{step}</small></li>)}</ol>
                {order.trackingCode && <p className="customer-tracking-code">کد پیگیری پست: <bdi dir="ltr">{order.trackingCode}</bdi></p>}
                {order.timeline.length > 0 && <details className="customer-order-history"><summary>دیدن تاریخچهٔ تغییر وضعیت</summary><ul>{order.timeline.map((entry, index) => <li key={`${entry.at}-${index}`}><strong>{orderStatus[entry.status] ?? entry.status}</strong>{entry.note && <span>{entry.note}</span>}<time>{new Date(entry.at).toLocaleString("fa-IR")}</time></li>)}</ul></details>}
              </div>}
              <details className="customer-invoice">
                <summary>فاکتور و جزئیات مبلغ</summary>
                <div className="customer-invoice-lines">
                  {order.items.map((item, index) => (
                    <div key={`${item.name}-${index}`}>
                      <span>{item.name} · {item.color} · {item.size}<small>{new Intl.NumberFormat("fa-IR").format(item.quantity)} عدد × {formatRial(item.unitPriceToman)}</small></span>
                      <strong>{formatRial(item.lineTotalToman)}</strong>
                    </div>
                  ))}
                  <div><span>هزینهٔ ارسال</span><strong>{order.shippingToman ? formatRial(order.shippingToman) : "رایگان"}</strong></div>
                  {order.discountToman > 0 && <div><span>تخفیف</span><strong>− {formatRial(order.discountToman)}</strong></div>}
                  <div className="customer-invoice-total"><span>مبلغ قابل پرداخت</span><strong>{formatRial(order.totalToman)}</strong></div>
                </div>
                <button type="button" className="button-primary customer-pay-order" disabled={!order.paymentConfigured} title={!order.paymentConfigured ? "درگاه پرداخت هنوز روی فروشگاه تنظیم نشده است" : undefined}>
                  {order.paymentConfigured ? "پرداخت سفارش" : "درگاه پرداخت تنظیم نشده"}<ArrowLeft size={16} />
                </button>
              </details>
              {order.status === "delivered" && order.paymentStatus === "paid" && !returnRequest && <details className="customer-return-form"><summary>درخواست مرجوعی کالا</summary><p>هزینهٔ بازگشت کالا با خریدار است. بازپرداخت پس از دریافت کامل کالای مرجوعی انجام می‌شود.</p><form className="store-form-grid" onSubmit={(event) => void createReturn(event, order.orderNumber)}><label className="store-field store-form-wide"><span>دلیل مرجوعی</span><textarea name="reason" required minLength={3} maxLength={2000} rows={3} /></label><label className="store-field"><span>شماره شبا</span><input name="iban" dir="ltr" inputMode="text" placeholder="IR000000000000000000000000" required pattern="IR[0-9۰-۹٠-٩]{24}" /></label><label className="store-field"><span>شماره کارت</span><input name="cardNumber" dir="ltr" inputMode="numeric" required pattern="[0-9۰-۹٠-٩]{16}" maxLength={16} /></label><button className="outline-button customer-save-profile" disabled={busy} type="submit">ثبت درخواست مرجوعی</button></form></details>}
              {returnRequest && <div className="customer-return-status"><strong>درخواست مرجوعی: {returnStatus[returnRequest.status] ?? returnRequest.status}</strong><span>{returnRequest.adminNote ?? "وضعیت درخواست از همین صفحه به‌روز می‌شود."}</span>{returnRequest.refundReceiptPath && <a href={customerAssetUrl(returnRequest.refundReceiptPath) ?? undefined} target="_blank" rel="noreferrer">مشاهدهٔ رسید واریز</a>}</div>}
            </article>})}</div> : <p className="customer-no-orders">هنوز سفارشی در حسابت ثبت نشده است. <Link href="/products">دیدن محصولات</Link></p>}
          </section>

          <section id="support" className="customer-section customer-support-section">
            <div className="customer-section-heading"><span className="customer-section-icon"><MessageCircle size={19} /></span><div><h2>پشتیبانی</h2><p>درخواست ثبت کن یا گفت‌وگویت را ادامه بده.</p></div></div>
            <form className="customer-support-form" onSubmit={(event) => void createSupportTicket(event)}><label className="store-field"><span>موضوع</span><input name="subject" required minLength={3} maxLength={180} /></label><label className="store-field"><span>پیام</span><textarea name="message" required minLength={2} maxLength={4000} rows={3} /></label><label className="store-field"><span>تصویر پیوست <small>(اختیاری · JPG، PNG یا WebP تا ۵ مگابایت)</small></span><input type="file" name="image" accept="image/jpeg,image/png,image/webp" /></label><button className="button-primary" type="submit" disabled={busy}>ثبت درخواست پشتیبانی</button></form>
            {supportTickets.map((ticket) => <article className="customer-ticket" key={ticket.id}><div className="customer-ticket-heading"><strong>{ticket.subject}</strong><span>{ticket.status === "waiting_customer" ? "پاسخ پشتیبان" : ticket.status === "closed" ? "تیکت بسته شد" : "در حال پیگیری"}</span></div>{ticket.status === "closed" && <p className="customer-ticket-closed" role="status">این تیکت بسته شد. برای پیگیری بیشتر، یک درخواست پشتیبانی تازه ثبت کن.</p>}<ol>{ticket.messages.map((message) => <li className={message.senderType === "admin" ? "from-support" : "from-customer"} key={message.id}><strong>{message.senderType === "admin" ? "پشتیبان پانیذ" : "من"}</strong><p>{message.body}</p>{message.imagePath && <a href={customerAssetUrl(message.imagePath) ?? undefined} target="_blank" rel="noreferrer"><img className="customer-ticket-image" src={customerAssetUrl(message.imagePath) ?? undefined} alt="تصویر پیوست گفت‌وگوی پشتیبانی" loading="lazy" /></a>}<time>{new Date(message.createdAt).toLocaleString("fa-IR")}</time></li>)}</ol>{ticket.status !== "closed" && <form className="customer-ticket-reply" onSubmit={(event) => void replySupportTicket(event, ticket.id)}><label className="store-field"><span>پاسخ</span><textarea name="body" required maxLength={4000} rows={2} /></label><label className="store-field"><span>تصویر (اختیاری)</span><input type="file" name="image" accept="image/jpeg,image/png,image/webp" /></label><button className="outline-button" type="submit" disabled={busy}>ارسال پیام</button></form>}</article>)}
          </section>
        </div>}
      </div></main>
    </StorefrontShell>
  );
}

function asciiDigits(value: string) {
  const persian = "۰۱۲۳۴۵۶۷۸۹"; const arabic = "٠١٢٣٤٥٦٧٨٩";
  return value.replace(/[۰-۹]/g, (digit) => String(persian.indexOf(digit))).replace(/[٠-٩]/g, (digit) => String(arabic.indexOf(digit)));
}

function formatRial(valueToman: number) {
  return `${new Intl.NumberFormat("fa-IR").format(Math.round(valueToman * 10))} ریال`;
}
