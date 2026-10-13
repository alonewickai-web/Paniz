"use client";

import { useState, type FormEvent } from "react";
import { ArrowLeft, LoaderCircle, Send } from "lucide-react";
import { customerApi, CustomerApiError } from "../lib/customer-api";

export function ContactMessageForm() {
  const [busy, setBusy] = useState(false);
  const [notice, setNotice] = useState<{ text: string; error: boolean } | null>(null);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (busy) return;
    const form = event.currentTarget;
    const fields = new FormData(form);
    setBusy(true);
    setNotice(null);
    try {
      await customerApi<{ received: boolean }>("/public/contact", {
        method: "POST",
        body: JSON.stringify({
          name: fields.get("name"),
          phone: fields.get("phone"),
          message: fields.get("message"),
        }),
      });
      form.reset();
      setNotice({ text: "پیامت با موفقیت برای پشتیبانی فرستاده شد.", error: false });
    } catch (error) {
      setNotice({
        text: error instanceof CustomerApiError ? error.message : "ارسال پیام انجام نشد؛ کمی بعد دوباره تلاش کن.",
        error: true,
      });
    } finally {
      setBusy(false);
    }
  }

  return (
    <section className="store-form-section" aria-labelledby="contact-form-title">
      <h2 id="contact-form-title">پیام برای پشتیبانی</h2>
      <form className="store-form-grid" onSubmit={submit}>
        <label className="store-field">
          <span>نام</span>
          <input name="name" autoComplete="name" required minLength={2} maxLength={100} />
        </label>
        <label className="store-field">
          <span>شمارهٔ موبایل</span>
          <input name="phone" type="tel" inputMode="tel" autoComplete="tel" placeholder="09123456789" required pattern="(?:\+98|0098|0)?9\d{9}" />
        </label>
        <label className="store-field store-form-wide">
          <span>متن پیام</span>
          <textarea name="message" rows={5} required minLength={3} maxLength={1500} placeholder="چطور می‌توانیم کمکت کنیم؟" />
        </label>
        <div className="store-form-wide">
          <button className="button-primary" type="submit" disabled={busy}>
            {busy ? <LoaderCircle size={17} className="contact-submit-spinner" /> : <Send size={16} />}
            {busy ? "در حال ارسال…" : "ارسال پیام"}
            {!busy && <ArrowLeft size={16} />}
          </button>
          {notice && <p role={notice.error ? "alert" : "status"} className="store-info-callout contact-message-status">{notice.text}</p>}
        </div>
      </form>
    </section>
  );
}
