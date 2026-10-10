import Link from "next/link";
import { notFound } from "next/navigation";
import { StorefrontShell } from "../../components/storefront-shell";

const policies: Record<string, { title: string; sections: { heading: string; body: string }[] }> = {
  returns: {
    title: "تعویض و مرجوعی",
    sections: [
      { heading: "شرایط درخواست", body: "مهلت و شرایط تعویض یا مرجوعی هنوز توسط فروشگاه تعیین و در تنظیمات ثبت نشده است. پیش از پرداخت نهایی، جزئیات مربوط به سفارش خود را از پشتیبانی فروشگاه دریافت کنید." },
      { heading: "پیگیری درخواست", body: "پس از ثبت سفارش، شمارهٔ سفارش را برای پیگیری نگه دارید. مسیر ثبت درخواست مرجوعی پس از نهایی‌شدن سیاست فروشگاه فعال می‌شود." },
    ],
  },
  privacy: {
    title: "حریم خصوصی",
    sections: [
      { heading: "اطلاعات سفارش", body: "اطلاعات گیرنده و نشانی فقط برای ثبت و پیگیری درخواست خرید در دیتابیس فروشگاه ذخیره می‌شود. پیگیری سفارش برای نمایش وضعیت، شمارهٔ سفارش و تلفن گیرنده را با هم تطبیق می‌دهد." },
      { heading: "اطلاعات روی دستگاه", body: "سبد خرید و فهرست علاقه‌مندی‌های مهمان در حافظهٔ مرورگر همین دستگاه نگهداری می‌شوند. ورود حساب کاربری و همگام‌سازی بین دستگاه‌ها پس از راه‌اندازی سرویس پیامک فعال خواهد شد." },
      { heading: "پرداخت", body: "درگاه پرداخت آنلاین هنوز متصل نیست؛ این نسخه اطلاعات بانکی دریافت یا ذخیره نمی‌کند." },
    ],
  },
  terms: {
    title: "قوانین خرید",
    sections: [
      { heading: "قیمت و موجودی", body: "قیمت و موجودی رنگ و سایز در سمت سرور دوباره بررسی می‌شود. ثبت درخواست مهمان به‌تنهایی به معنی پرداخت یا تأیید نهایی سفارش نیست." },
      { heading: "تأیید سفارش", body: "در نسخهٔ فعلی روش پرداخت و هزینهٔ ارسال پیکربندی نشده‌اند؛ تأیید نهایی پس از تعیین این موارد انجام می‌شود." },
    ],
  },
};

export async function generateMetadata({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  return { title: `${policies[slug]?.title ?? "قوانین"} | PanizStyle` };
}

export default async function PolicyPage({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const policy = policies[slug];
  if (!policy) notFound();
  return <StorefrontShell><main className="store-page"><article className="page-shell store-info-page"><nav className="store-breadcrumb"><Link href="/">خانه</Link><span>/</span><span>{policy.title}</span></nav><span className="section-kicker">اطلاعات فروشگاه</span><h1>{policy.title}</h1><div className="store-info-sections">{policy.sections.map((section) => <section key={section.heading}><h2>{section.heading}</h2><p>{section.body}</p></section>)}</div><Link className="button-primary" href="/products">بازگشت به فروشگاه</Link></article></main></StorefrontShell>;
}
