"use client";

import Link from "next/link";
import { useEffect, useMemo, useState, type FormEvent } from "react";
import { ArrowLeft, Check, MapPin, Plus, ShieldCheck } from "lucide-react";
import { StorefrontShell } from "../components/storefront-shell";
import { apiBaseUrl, formatToman } from "../lib/catalog";
import { CustomerApiError, customerApi, type CustomerAddress, type CustomerProfile } from "../lib/customer-api";
import { useStorefront } from "../lib/storefront-state";

type Quote = { items: { variantId: string; productName: string; color: string; size: string; quantity: number; unitPriceToman: number; lineTotalToman: number }[]; subtotalToman: number; discountToman: number; couponCode: string | null; shippingToman: number | null; totalToman: number | null; shippingConfigured: boolean; paymentConfigured: boolean };
type CreatedOrder = { orderNumber: string; status: string; paymentStatus: string; totalToman: number; reservationExpiresAt: string | null; shippingConfigured: boolean; paymentConfigured: boolean };
type AddressForm = {
  title: string; recipientName: string; recipientPhone: string; province: string; city: string;
  street: string; alley: string; plaqueNumber: string; unit: string; deliveryDetails: string; postalCode: string; isDefault: boolean;
};

const provinces = ["آذربایجان شرقی", "آذربایجان غربی", "اردبیل", "اصفهان", "البرز", "ایلام", "بوشهر", "تهران", "چهارمحال و بختیاری", "خراسان جنوبی", "خراسان رضوی", "خراسان شمالی", "خوزستان", "زنجان", "سمنان", "سیستان و بلوچستان", "فارس", "قزوین", "قم", "کردستان", "کرمان", "کرمانشاه", "کهگیلویه و بویراحمد", "گلستان", "گیلان", "لرستان", "مازندران", "مرکزی", "هرمزگان", "همدان", "یزد"];
const emptyAddress = (phone = "", recipientName = ""): AddressForm => ({ title: "خانه", recipientName, recipientPhone: phone, province: "", city: "", street: "", alley: "", plaqueNumber: "", unit: "", deliveryDetails: "", postalCode: "", isDefault: false });

export default function CheckoutPage() {
  const { cart, setCart, ready } = useStorefront();
  const [quote, setQuote] = useState<Quote | null>(null);
  const [quoteError, setQuoteError] = useState("");
  const [loadingQuote, setLoadingQuote] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [submitError, setSubmitError] = useState("");
  const [order, setOrder] = useState<CreatedOrder | null>(null);
  const [profile, setProfile] = useState<CustomerProfile | null>(null);
  const [accountLoading, setAccountLoading] = useState(true);
  const [addresses, setAddresses] = useState<CustomerAddress[]>([]);
  const [selectedAddressId, setSelectedAddressId] = useState("");
  const [showAddressForm, setShowAddressForm] = useState(false);
  const [savingAddress, setSavingAddress] = useState(false);
  const [addressError, setAddressError] = useState("");
  const [addressForm, setAddressForm] = useState<AddressForm>(emptyAddress());
  const [customerNote, setCustomerNote] = useState("");
  const [couponDraft, setCouponDraft] = useState("");
  const [appliedCoupon, setAppliedCoupon] = useState("");
  const cartPayload = useMemo(() => JSON.stringify(cart.map((line) => ({ variantId: line.variantId, quantity: line.quantity }))), [cart]);

  useEffect(() => {
    if (!ready) return;
    let cancelled = false;
    setAccountLoading(true);
    customerApi<CustomerProfile>("/customer/profile").then((customer) => {
      if (cancelled) return;
      setProfile(customer);
      setAddresses(customer.addresses);
      setAddressForm(emptyAddress(customer.phone, customer.fullName ?? ""));
      const preferred = customer.addresses.find((address) => address.isDefault) ?? customer.addresses[0];
      setSelectedAddressId(preferred?.id ?? "");
      setShowAddressForm(customer.addresses.length === 0);
    }).catch((error: unknown) => {
      if (cancelled) return;
      setProfile(null);
      if (!(error instanceof CustomerApiError && error.status === 401)) {
        setSubmitError(error instanceof Error ? error.message : "بررسی حساب کاربری انجام نشد.");
      }
    }).finally(() => { if (!cancelled) setAccountLoading(false); });
    return () => { cancelled = true; };
  }, [ready]);

  useEffect(() => {
    if (!ready || !cart.length) { setQuote(null); setQuoteError(""); return; }
    const controller = new AbortController();
    if (cart.some((line) => !line.variantId)) {
      setQuoteError("یکی از انتخاب‌های سبد قدیمی است؛ آن را حذف و دوباره اضافه کن.");
      return () => controller.abort();
    }
    setLoadingQuote(true); setQuoteError("");
    fetch(`${apiBaseUrl()}/checkout/quote`, {
      method: "POST", headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ items: cart.map((line) => ({ variantId: line.variantId, quantity: line.quantity })), ...(appliedCoupon ? { couponCode: appliedCoupon } : {}) }),
      signal: controller.signal, cache: "no-store",
    }).then(async (response) => {
      const payload = await response.json();
      if (!response.ok) throw new Error(readError(payload));
      setQuote(payload.data as Quote);
    }).catch((error: unknown) => {
      if (!controller.signal.aborted) {
        setQuoteError(error instanceof Error ? error.message : "بررسی سبد خرید انجام نشد.");
        setQuote(null);
      }
    }).finally(() => { if (!controller.signal.aborted) setLoadingQuote(false); });
    return () => controller.abort();
  }, [cartPayload, ready, appliedCoupon]);

  async function saveAddress(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); setSavingAddress(true); setAddressError("");
    try {
      const address = await customerApi<CustomerAddress>("/customer/addresses", {
        method: "POST",
        body: JSON.stringify({ ...addressForm, postalCode: asciiDigits(addressForm.postalCode) }),
      });
      setAddresses((current) => [address, ...current.filter((item) => item.id !== address.id).map((item) => address.isDefault ? { ...item, isDefault: false } : item)]);
      setSelectedAddressId(address.id);
      setShowAddressForm(false);
      setAddressForm(profile ? emptyAddress(profile.phone, profile.fullName ?? "") : emptyAddress());
    } catch (reason) { setAddressError(reason instanceof Error ? reason.message : "ذخیرهٔ نشانی انجام نشد."); }
    finally { setSavingAddress(false); }
  }

  async function submitOrder(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); setSubmitError("");
    if (!profile) { setSubmitError("برای ثبت سفارش ابتدا وارد حساب کاربری شو."); return; }
    if (!selectedAddressId) { setSubmitError("یک نشانی ذخیره‌شده برای تحویل انتخاب کن."); return; }
    if (!quote || quoteError) { setSubmitError("اول قیمت و موجودی سبد را دوباره بررسی کن."); return; }
    setSubmitting(true);
    let previousAttempt: { cart: string; key: string } | null = null;
    try { previousAttempt = JSON.parse(window.sessionStorage.getItem("panizstyle-order-attempt") || "null") as { cart: string; key: string } | null; } catch { previousAttempt = null; }
    const idempotencyKey = previousAttempt?.cart === cartPayload ? previousAttempt.key : createIdempotencyKey();
    window.sessionStorage.setItem("panizstyle-order-attempt", JSON.stringify({ cart: cartPayload, key: idempotencyKey }));
    try {
      const created = await customerApi<CreatedOrder>("/orders", {
        method: "POST",
        headers: { "Idempotency-Key": idempotencyKey },
        body: JSON.stringify({ addressId: selectedAddressId, customerNote, ...(appliedCoupon ? { couponCode: appliedCoupon } : {}), items: cart.map((line) => ({ variantId: line.variantId, quantity: line.quantity })) }),
      });
      setOrder(created);
      window.sessionStorage.removeItem("panizstyle-order-attempt");
      setCart([]);
    } catch (reason) {
      setSubmitError(reason instanceof Error ? reason.message : "ثبت سفارش انجام نشد؛ دوباره تلاش کن.");
    } finally { setSubmitting(false); }
  }

  if (!ready) return <StorefrontShell><main className="store-page"><div className="page-shell store-message">در حال آماده‌کردن سبد خرید…</div></main></StorefrontShell>;

  return (
    <StorefrontShell>
      <main className="store-page"><div className="page-shell">
        <nav className="store-breadcrumb" aria-label="مسیر صفحه"><Link href="/">خانه</Link><span>/</span><Link href="/cart">سبد خرید</Link><span>/</span><span>تسویه‌حساب</span></nav>
        {order ? <section className="store-order-success" role="status">
          <span className="store-success-icon"><Check size={28} /></span><span className="section-kicker">درخواست خرید ثبت شد</span><h1>سفارش {order.orderNumber}</h1>
          <p>موجودی انتخاب‌هایت تا {order.reservationExpiresAt ? new Date(order.reservationExpiresAt).toLocaleTimeString("fa-IR", { hour: "2-digit", minute: "2-digit" }) : "۱۵ دقیقه"} رزرو شد.</p>
          <div className="store-payment-notice"><ShieldCheck size={20} /><span><strong>سفارش ثبت شد اما پرداخت بانکی هنوز فعال نیست.</strong><small>درگاه پرداخت و هزینهٔ ارسال در تنظیمات فروشگاه تعریف نشده‌اند؛ مبلغ فعلی فقط جمع کالاهاست و پرداخت نهایی بعد از اتصال این سرویس‌ها انجام می‌شود.</small></span></div>
          <div className="store-success-actions"><Link className="button-primary" href="/account">مشاهدهٔ سفارش‌ها</Link><Link className="outline-button" href="/products">بازگشت به فروشگاه</Link></div>
        </section> : !cart.length ? <div className="store-empty-page"><h1>سبد خرید خالی است</h1><p>برای ادامه، ابتدا محصولی به سبدت اضافه کن.</p><Link className="button-primary" href="/products">دیدن محصولات</Link></div> : (
          <>
            <div className="store-page-heading"><div><span className="section-kicker">تسویه‌حساب امن</span><h1>نشانی تحویل را انتخاب کن</h1><p>برای ثبت سفارش باید وارد حساب کاربری شوی؛ نشانی‌های ذخیره‌شده برای خریدهای بعدی هم در دسترس می‌مانند.</p></div></div>
            <div className="store-checkout-layout">
              <div className="store-checkout-form">
                {accountLoading ? <section className="store-form-section"><p className="store-loading-note">در حال بررسی حساب کاربری…</p></section> : !profile ? <section className="customer-checkout-login"><span className="customer-section-icon"><ShieldCheck size={21} /></span><div><h2>ورود برای ادامهٔ خرید</h2><p>با شمارهٔ موبایل وارد شو یا حساب تازه بساز. سبد خریدت پس از ورود حفظ می‌شود.</p></div><Link className="button-primary" href="/account?next=%2Fcheckout">ورود / ساخت حساب<ArrowLeft size={17} /></Link></section> : <>
                  <section className="store-form-section customer-checkout-addresses">
                    <div className="customer-section-heading"><span className="customer-section-icon"><MapPin size={19} /></span><div><h2>نشانی تحویل</h2><p>گیرنده: {profile.fullName || profile.phone}</p></div>{addresses.length > 0 && <button className="outline-button customer-add-address" type="button" onClick={() => { setShowAddressForm((current) => !current); setAddressError(""); }}><Plus size={17} /> نشانی تازه</button>}</div>
                    {addresses.length > 0 && <div className="checkout-address-options">{addresses.map((address) => <label className={`checkout-address-option ${selectedAddressId === address.id ? "selected" : ""}`} key={address.id}>
                      <input type="radio" name="delivery-address" value={address.id} checked={selectedAddressId === address.id} onChange={() => setSelectedAddressId(address.id)} />
                      <span className="checkout-address-copy"><strong>{address.title || "نشانی"} {address.isDefault && <small>پیش‌فرض</small>}</strong><span>{address.recipientName} · <bdi dir="ltr">{address.recipientPhone}</bdi></span><span>{address.province}، {address.city}، {address.addressLine}</span><span>کدپستی: <bdi dir="ltr">{address.postalCode}</bdi></span></span>
                    </label>)}</div>}
                    {showAddressForm && <form className="customer-address-form customer-checkout-address-form" onSubmit={(event) => void saveAddress(event)}>
                      <div className="customer-address-form-heading"><h3>{addresses.length ? "افزودن نشانی تازه" : "برای خرید یک نشانی ثبت کن"}</h3>{addresses.length > 0 && <button type="button" className="customer-text-button" onClick={() => setShowAddressForm(false)}>انصراف</button>}</div>
                      <div className="store-form-grid">
                        <label className="store-field"><span>عنوان نشانی</span><input maxLength={80} value={addressForm.title} onChange={(event) => setAddressForm((form) => ({ ...form, title: event.target.value }))} /></label>
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
                        <label className="customer-default-check"><input type="checkbox" checked={addressForm.isDefault} onChange={(event) => setAddressForm((form) => ({ ...form, isDefault: event.target.checked }))} /><span>به‌عنوان نشانی پیش‌فرض ذخیره شود</span></label>
                      </div>
                      {addressError && <p className="store-inline-error" role="alert">{addressError}</p>}
                      <button className="outline-button customer-save-address" type="submit" disabled={savingAddress}>{savingAddress ? "در حال ذخیره…" : "ذخیره و انتخاب این نشانی"}<Check size={17} /></button>
                    </form>}
                    {!addresses.length && !showAddressForm && <button className="button-primary" type="button" onClick={() => setShowAddressForm(true)}><Plus size={17} /> ثبت نشانی</button>}
                  </section>

                  <form className="store-form-section customer-checkout-note" onSubmit={(event) => void submitOrder(event)}>
                    <label className="store-field"><span>یادداشت برای فروشگاه <small>(اختیاری)</small></span><textarea maxLength={1000} rows={2} value={customerNote} onChange={(event) => setCustomerNote(event.target.value)} /></label>
                    <div className="store-payment-notice"><ShieldCheck size={20} /><span><strong>درگاه پرداخت هنوز به فروشگاه متصل نشده است.</strong><small>ثبت سفارش در این مرحله، پرداخت بانکی انجام نمی‌دهد و سفارش در انتظار پرداخت می‌ماند.</small></span></div>
                    {quoteError && <p className="store-inline-error" role="alert">{quoteError}</p>}
                    {submitError && <p className="store-inline-error" role="alert">{submitError}</p>}
                    <button className="button-primary store-submit-order" type="submit" disabled={submitting || loadingQuote || !quote || Boolean(quoteError) || !selectedAddressId}>{submitting ? "در حال ثبت…" : "ثبت سفارش"}<ArrowLeft size={18} /></button>
                  </form>
                </>}
              </div>
              <aside className="store-order-summary store-checkout-summary"><h2>خلاصهٔ انتخاب‌ها</h2>
                {(quote?.items ?? []).map((item) => <div className="store-checkout-item" key={item.variantId}><span>{item.productName}<small>{item.color} · {item.size} · {new Intl.NumberFormat("fa-IR").format(item.quantity)} عدد</small></span><strong>{formatToman(item.lineTotalToman)}</strong></div>)}
                <form className="store-coupon-form" onSubmit={(event) => { event.preventDefault(); setQuoteError(""); setAppliedCoupon(couponDraft.trim().toUpperCase()); }}>
                  <label className="store-field"><span>کد تخفیف</span><input dir="ltr" maxLength={64} value={couponDraft} onChange={(event) => setCouponDraft(event.target.value)} placeholder="مثلاً PANI20" /></label>
                  <button className="outline-button" type="submit" disabled={!couponDraft.trim() || loadingQuote}>اعمال کد</button>
                  {appliedCoupon && <button className="customer-text-button" type="button" onClick={() => { setAppliedCoupon(""); setCouponDraft(""); setQuoteError(""); }}>حذف کد</button>}
                </form>
                <div><span>جمع کالاها</span><strong>{formatToman(quote?.subtotalToman ?? 0)}</strong></div><div><span>هزینهٔ ارسال</span><strong className="store-pending-value">بعد از تأیید</strong></div>
                {Boolean(quote?.discountToman) && <div><span>تخفیف {quote?.couponCode}</span><strong>- {formatToman(quote?.discountToman ?? 0)}</strong></div>}
                <div className="store-summary-total"><span>مبلغ نهایی</span><strong>پس از تعیین ارسال</strong></div>
                {loadingQuote && <small className="store-loading-note">در حال بررسی قیمت و موجودی…</small>}
                <Link className="store-back-link" href="/cart">بازگشت و ویرایش سبد</Link>
              </aside>
            </div>
          </>
        )}
      </div></main>
    </StorefrontShell>
  );
}

function createIdempotencyKey() {
  return typeof crypto.randomUUID === "function" ? crypto.randomUUID() : `paniz-${Date.now()}-${Math.random().toString(16).slice(2)}`;
}

function asciiDigits(value: string) {
  const persian = "۰۱۲۳۴۵۶۷۸۹"; const arabic = "٠١٢٣٤٥٦٧٨٩";
  return value.replace(/[۰-۹]/g, (digit) => String(persian.indexOf(digit))).replace(/[٠-٩]/g, (digit) => String(arabic.indexOf(digit)));
}

function readError(payload: unknown): string {
  if (payload && typeof payload === "object") {
    const value = payload as { message?: string | string[]; error?: { message?: string } };
    if (typeof value.message === "string") return value.message;
    if (Array.isArray(value.message)) return value.message.join("، ");
    if (value.error?.message) return value.error.message;
  }
  return "قیمت یا موجودی یکی از کالاها تغییر کرده؛ سبد را بررسی کن.";
}
