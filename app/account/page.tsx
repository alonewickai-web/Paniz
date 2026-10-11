"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useMemo, useState, type FormEvent } from "react";
import { ArrowLeft, Check, Copy, ExternalLink, LogOut, MapPin, MessageCircle, Package, Pencil, Plus, ShieldCheck, Smartphone, Trash2, Unlink, UserRound } from "lucide-react";
import { StorefrontShell } from "../components/storefront-shell";
import { formatToman } from "../lib/catalog";
import { CustomerApiError, customerApi, type CustomerAddress, type CustomerOrder, type CustomerProfile } from "../lib/customer-api";

const provinces = ["آذربایجان شرقی", "آذربایجان غربی", "اردبیل", "اصفهان", "البرز", "ایلام", "بوشهر", "تهران", "چهارمحال و بختیاری", "خراسان جنوبی", "خراسان رضوی", "خراسان شمالی", "خوزستان", "زنجان", "سمنان", "سیستان و بلوچستان", "فارس", "قزوین", "قم", "کردستان", "کرمان", "کرمانشاه", "کهگیلویه و بویراحمد", "گلستان", "گیلان", "لرستان", "مازندران", "مرکزی", "هرمزگان", "همدان", "یزد"];

type AddressForm = {
  title: string;
  recipientName: string;
  recipientPhone: string;
  province: string;
  city: string;
  street: string;
  alley: string;
  plaqueNumber: string;
  unit: string;
  deliveryDetails: string;
  postalCode: string;
  isDefault: boolean;
};

type RubikaLink = { code: string; expiresAt: string; botUrl: string | null; botUsername: string | null };

const emptyAddress = (phone = "", recipientName = ""): AddressForm => ({
  title: "خانه", recipientName, recipientPhone: phone, province: "", city: "", street: "", alley: "",
  plaqueNumber: "", unit: "", deliveryDetails: "", postalCode: "", isDefault: false,
});

const orderStatus: Record<string, string> = {
  pending_payment: "در انتظار پرداخت", paid: "پرداخت‌شده", confirmed: "تأییدشده", preparing: "در حال آماده‌سازی",
  shipped: "تحویل به شرکت حمل‌ونقل", delivered: "تحویل‌شده", cancelled: "لغوشده", expired: "مهلت رزرو تمام شده", returned: "مرجوع‌شده",
};

export default function AccountPage() {
  const router = useRouter();
  const [booting, setBooting] = useState(true);
  const [profile, setProfile] = useState<CustomerProfile | null>(null);
  const [orders, setOrders] = useState<CustomerOrder[]>([]);
  const [phone, setPhone] = useState("");
  const [code, setCode] = useState("");
  const [codeSent, setCodeSent] = useState(false);
  const [developmentCode, setDevelopmentCode] = useState(false);
  const [profileForm, setProfileForm] = useState({ fullName: "", email: "", marketingOptIn: false, rubikaMarketingOptIn: false });
  const [rubikaLink, setRubikaLink] = useState<RubikaLink | null>(null);
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
    const customerOrders = await customerApi<CustomerOrder[]>("/customer/orders");
    setProfile(customer);
    setOrders(customerOrders);
    setProfileForm({
      fullName: customer.fullName ?? "", email: customer.email ?? "",
      marketingOptIn: customer.marketingOptIn, rubikaMarketingOptIn: customer.rubikaMarketingOptIn,
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

  async function sendCode(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setBusy(true); setError(""); setNotice("");
    try {
      const result = await customerApi<{ phone: string; expiresAt: string; retryAfterSeconds: number; developmentCode?: string }>("/customer/auth/send-code", {
        method: "POST", body: JSON.stringify({ phone }),
      });
      setPhone(result.phone);
      setCodeSent(true);
      if (result.developmentCode) {
        setCode(result.developmentCode);
        setDevelopmentCode(true);
        setNotice("کد آزمایشی در همین محیط آماده شد؛ برای پیامک واقعی باید سرویس پیامک فروشگاه تنظیم شود.");
      } else {
        setDevelopmentCode(false);
        setNotice("کد ورود برای شمارهٔ همراهت ارسال شد.");
      }
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : "ارسال کد انجام نشد.");
    } finally { setBusy(false); }
  }

  async function verifyCode(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setBusy(true); setError(""); setNotice("");
    try {
      await customerApi("/customer/auth/verify-code", { method: "POST", body: JSON.stringify({ phone, code: asciiDigits(code) }) });
      const customer = await refreshAccount();
      if (nextPath && customer.addresses.length > 0) router.replace(nextPath);
      else setNotice("وارد حساب شدی. نشانی‌ات را ذخیره کن تا خرید را ادامه بدهی.");
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : "تأیید کد انجام نشد.");
    } finally { setBusy(false); }
  }

  async function saveProfile(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); setBusy(true); setError(""); setNotice("");
    try {
      await customerApi("/customer/profile", { method: "PATCH", body: JSON.stringify(profileForm) });
      await refreshAccount();
      setNotice("اطلاعات حساب ذخیره شد.");
    } catch (reason) { setError(reason instanceof Error ? reason.message : "ذخیرهٔ اطلاعات انجام نشد."); }
    finally { setBusy(false); }
  }

  async function connectRubika() {
    if (!profileForm.rubikaMarketingOptIn) {
      setError("برای اتصال روبیکا، گزینهٔ رضایت را فعال و سپس ذخیره کن.");
      return;
    }
    setBusy(true); setError(""); setNotice(""); setRubikaLink(null);
    try {
      await customerApi("/customer/profile", { method: "PATCH", body: JSON.stringify(profileForm) });
      const result = await customerApi<RubikaLink>("/customer/rubika/link-code", { method: "POST" });
      setRubikaLink(result);
      await refreshAccount();
      setNotice("کد اتصال ساخته شد. ربات روبیکا را باز کن و کد را برایش بفرست.");
    } catch (reason) { setError(reason instanceof Error ? reason.message : "ساخت کد اتصال روبیکا انجام نشد."); }
    finally { setBusy(false); }
  }

  async function unlinkRubika() {
    if (!window.confirm("اتصال روبیکا قطع و رضایت دریافت پیام‌های روبیکا غیرفعال شود؟")) return;
    setBusy(true); setError(""); setNotice("");
    try {
      await customerApi("/customer/rubika/link", { method: "DELETE" });
      setRubikaLink(null);
      await refreshAccount();
      setNotice("اتصال روبیکا قطع شد.");
    } catch (reason) { setError(reason instanceof Error ? reason.message : "قطع اتصال روبیکا انجام نشد."); }
    finally { setBusy(false); }
  }

  async function copyRubikaCode() {
    if (!rubikaLink) return;
    try {
      await navigator.clipboard.writeText(rubikaLink.code);
      setNotice("کد اتصال کپی شد.");
    } catch { setNotice("کد را انتخاب و کپی کن: " + rubikaLink.code); }
  }

  function beginAddressEdit(address?: CustomerAddress) {
    setEditingAddressId(address?.id ?? null);
    setAddressForm(address ? {
      title: address.title ?? "", recipientName: address.recipientName, recipientPhone: address.recipientPhone,
      province: address.province, city: address.city, street: address.street ?? "", alley: address.alley ?? "",
      plaqueNumber: address.plaqueNumber ?? "", unit: address.unit ?? "", deliveryDetails: address.deliveryDetails ?? "",
      postalCode: address.postalCode, isDefault: address.isDefault,
    } : emptyAddress(profile?.phone ?? "", profile?.fullName ?? ""));
    setAddressFormOpen(true); setError(""); setNotice("");
  }

  async function saveAddress(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); setBusy(true); setError(""); setNotice("");
    try {
      await customerApi(editingAddressId ? `/customer/addresses/${editingAddressId}` : "/customer/addresses", {
        method: editingAddressId ? "PATCH" : "POST", body: JSON.stringify({ ...addressForm, postalCode: asciiDigits(addressForm.postalCode) }),
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
        <div className="store-page-heading customer-heading"><div><span className="section-kicker">همراه پانیز</span><h1>{profile ? `سلام ${profile.fullName || "عزیزم"}` : "ورود به حساب کاربری"}</h1><p>{profile ? "اطلاعات و نشانی‌های ذخیره‌شده‌ات را مدیریت کن." : "برای خرید، پیگیری سفارش‌ها و ذخیرهٔ نشانی‌ها با شمارهٔ موبایلت وارد شو."}</p></div>
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
            <button className="customer-text-button" type="button" onClick={() => { setCodeSent(false); setCode(""); setError(""); setNotice(""); }}>ویرایش شمارهٔ موبایل</button>
          </form>}
        </div> : <div className="customer-dashboard">
          <section className="customer-section customer-profile-section">
            <div className="customer-section-heading"><span className="customer-section-icon"><UserRound size={19} /></span><div><h2>اطلاعات حساب</h2><p>شمارهٔ تأییدشده و مشخصات تماس تو</p></div></div>
            <div className="customer-verified-phone"><span>شمارهٔ همراه</span><strong dir="ltr">{profile.phone}</strong><small><Check size={14} /> تأییدشده</small></div>
            <form className="store-form-grid customer-profile-form" onSubmit={(event) => void saveProfile(event)}>
              <label className="store-field"><span>نام و نام خانوادگی</span><input autoComplete="name" required minLength={2} maxLength={160} value={profileForm.fullName} onChange={(event) => setProfileForm((form) => ({ ...form, fullName: event.target.value }))} /></label>
              <label className="store-field"><span>ایمیل <small>(اختیاری)</small></span><input type="email" autoComplete="email" maxLength={254} value={profileForm.email} onChange={(event) => setProfileForm((form) => ({ ...form, email: event.target.value }))} /></label>
              <label className="customer-default-check store-form-wide"><input type="checkbox" checked={profileForm.marketingOptIn} onChange={(event) => setProfileForm((form) => ({ ...form, marketingOptIn: event.target.checked }))} /><span>مایلم پیامک‌های اطلاع‌رسانی و پیشنهادهای فروشگاه را دریافت کنم. هر زمان بخواهم می‌توانم این گزینه را غیرفعال کنم.</span></label>
              <button className="outline-button customer-save-profile" type="submit" disabled={busy}>ذخیرهٔ اطلاعات</button>
            </form>
            <div className="customer-rubika-card">
              <label className="customer-default-check"><input type="checkbox" checked={profileForm.rubikaMarketingOptIn} onChange={(event) => setProfileForm((form) => ({ ...form, rubikaMarketingOptIn: event.target.checked }))} /><span>مایلم پیشنهادها و پیام‌های فروشگاه را از طریق ربات روبیکا دریافت کنم. این رضایت مستقل از پیامک است و هر زمان می‌توانم لغوش کنم.</span></label>
              <div className="customer-rubika-actions">
                <span className={profile.rubikaLinked ? "is-connected" : ""}><MessageCircle size={16} />{profile.rubikaLinked ? "حساب روبیکا متصل است" : "حساب روبیکا هنوز متصل نیست"}</span>
                {profile.rubikaLinked
                  ? <button className="outline-button" type="button" onClick={() => void unlinkRubika()} disabled={busy}><Unlink size={16} /> قطع اتصال</button>
                  : <button className="button-primary" type="button" onClick={() => void connectRubika()} disabled={busy || !profileForm.rubikaMarketingOptIn}>{busy ? "در حال ساخت کد…" : "ذخیره رضایت و اتصال روبیکا"}<ArrowLeft size={17} /></button>}
              </div>
              {rubikaLink && <div className="customer-rubika-code" role="status">
                <p>در روبیکا، گفت‌وگوی ربات را باز کن و این کد را برایش بفرست. کد تا ۱۰ دقیقه معتبر است.</p>
                <strong dir="ltr">{rubikaLink.code}</strong>
                <div>
                  <button className="outline-button" type="button" onClick={() => void copyRubikaCode()}><Copy size={15} /> کپی کد</button>
                  {rubikaLink.botUrl && <a className="outline-button" href={rubikaLink.botUrl} target="_blank" rel="noreferrer"><ExternalLink size={15} /> باز کردن ربات</a>}
                  {!rubikaLink.botUrl && rubikaLink.botUsername && <span>نام ربات در روبیکا: @{rubikaLink.botUsername}</span>}
                </div>
              </div>}
            </div>
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
                <label className="store-field"><span>استان</span><select required value={addressForm.province} onChange={(event) => setAddressForm((form) => ({ ...form, province: event.target.value }))}><option value="">انتخاب استان</option>{provinces.map((province) => <option key={province}>{province}</option>)}</select></label>
                <label className="store-field"><span>شهر</span><input autoComplete="address-level2" required minLength={2} maxLength={100} value={addressForm.city} onChange={(event) => setAddressForm((form) => ({ ...form, city: event.target.value }))} /></label>
                <label className="store-field"><span>خیابان اصلی</span><input autoComplete="address-line1" required minLength={2} maxLength={200} value={addressForm.street} onChange={(event) => setAddressForm((form) => ({ ...form, street: event.target.value }))} /></label>
                <label className="store-field"><span>کوچه / خیابان فرعی <small>(در صورت وجود)</small></span><input maxLength={200} value={addressForm.alley} onChange={(event) => setAddressForm((form) => ({ ...form, alley: event.target.value }))} /></label>
                <label className="store-field"><span>پلاک</span><input required maxLength={40} value={addressForm.plaqueNumber} onChange={(event) => setAddressForm((form) => ({ ...form, plaqueNumber: event.target.value }))} /></label>
                <label className="store-field"><span>واحد <small>(اختیاری)</small></span><input maxLength={40} value={addressForm.unit} onChange={(event) => setAddressForm((form) => ({ ...form, unit: event.target.value }))} /></label>
                <label className="store-field"><span>کدپستی ۱۰ رقمی</span><input dir="ltr" inputMode="numeric" autoComplete="postal-code" required pattern="[0-9۰-۹٠-٩]{10}" maxLength={10} value={addressForm.postalCode} onChange={(event) => setAddressForm((form) => ({ ...form, postalCode: event.target.value }))} /></label>
                <label className="store-field store-form-wide"><span>توضیحات تکمیلی برای پیک <small>(اختیاری)</small></span><textarea maxLength={300} rows={2} placeholder="مثلاً زنگ طبقهٔ دوم سمت راست" value={addressForm.deliveryDetails} onChange={(event) => setAddressForm((form) => ({ ...form, deliveryDetails: event.target.value }))} /></label>
                <label className="customer-default-check"><input type="checkbox" checked={addressForm.isDefault} onChange={(event) => setAddressForm((form) => ({ ...form, isDefault: event.target.checked }))} /><span>این نشانی، نشانی پیش‌فرض خرید باشد</span></label>
              </div>
              <div className="customer-address-form-actions"><button className="button-primary" type="submit" disabled={busy}>{busy ? "در حال ذخیره…" : "ذخیرهٔ نشانی"}<Check size={17} /></button></div>
            </form>}
          </section>

          <section className="customer-section customer-orders-section">
            <div className="customer-section-heading"><span className="customer-section-icon"><Package size={19} /></span><div><h2>سفارش‌های من</h2><p>سفارش‌ها و وضعیت فعلی آن‌ها</p></div></div>
            {orders.length ? <div className="customer-order-list">{orders.map((order) => <article className="customer-order-card" key={order.orderNumber}>
              <div><span className="customer-order-number">{order.orderNumber}</span><small>{new Date(order.placedAt).toLocaleDateString("fa-IR")}</small></div>
              <div className="customer-order-products">{order.items.map((item, index) => <span key={`${item.name}-${index}`}>{item.name} · {item.color} · {item.size} × {new Intl.NumberFormat("fa-IR").format(item.quantity)}</span>)}</div>
              <div className="customer-order-total"><span className={`customer-order-status status-${order.status}`}>{orderStatus[order.status] ?? order.status}</span><strong>{formatToman(order.totalToman)}</strong></div>
            </article>)}</div> : <p className="customer-no-orders">هنوز سفارشی در حسابت ثبت نشده است. <Link href="/products">دیدن محصولات</Link></p>}
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
