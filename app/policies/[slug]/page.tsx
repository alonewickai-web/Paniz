import Link from "next/link";
import { notFound } from "next/navigation";
import { StorefrontShell } from "../../components/storefront-shell";
import { apiBaseUrl } from "../../lib/catalog";

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
      { heading: "اطلاعات روی دستگاه", body: "سبد خرید و فهرست علاقه‌مندی‌های مهمان در حافظهٔ مرورگر همین دستگاه نگهداری می‌شوند. برای شمارش ناشناس محبوبیت محصولات، فهرست علاقه‌مندی‌ها همراه شناسهٔ تصادفی مرورگر به سرور همگام می‌شود؛ سرور فقط هش شناسه را نگه می‌دارد و نام یا شمارهٔ تماس دریافت نمی‌کند. این فهرست بین دستگاه‌ها همگام نمی‌شود." },
      { heading: "آمار بازدید", body: "برای سنجش بازدید سایت، مسیر صفحه و نسخهٔ هش‌شدهٔ یک شناسهٔ تصادفی و ناشناس مرورگر ثبت می‌شود. این گزارش پارامترهای آدرس، نام، شمارهٔ تماس و نشانی شما را ذخیره نمی‌کند و فقط برای تهیهٔ آمار کلی فروشگاه استفاده می‌شود." },
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
  return { title: `${policies[slug]?.title ?? "قوانین"} | پانیذ` };
}

export default async function PolicyPage({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const policy = policies[slug];
  if (!policy) notFound();
  const sections = slug === "returns" ? (await getPublicReturnsPolicy() ?? policy.sections) : policy.sections;
  return <StorefrontShell><main className="store-page"><article className="page-shell store-info-page"><nav className="store-breadcrumb"><Link href="/">خانه</Link><span>/</span><span>{policy.title}</span></nav><span className="section-kicker">اطلاعات فروشگاه</span><h1>{policy.title}</h1><div className="store-info-sections">{sections.map((section) => <section key={section.heading}><h2>{section.heading}</h2><p>{section.body}</p></section>)}</div><Link className="button-primary" href="/products">بازگشت به فروشگاه</Link></article></main></StorefrontShell>;
}

async function getPublicReturnsPolicy(): Promise<{ heading: string; body: string }[] | null> {
  try {
    const response = await fetch(`${apiBaseUrl()}/storefront/config`, {
      cache: "no-store",
      signal: AbortSignal.timeout(5000),
    });
    if (!response.ok) return null;
    const payload = await response.json() as {
      data?: { returnsPolicy?: { sections?: unknown } | null };
    };
    const sections = payload.data?.returnsPolicy?.sections;
    if (!Array.isArray(sections)) return null;
    const valid = sections.filter((section): section is { heading: string; body: string } =>
      Boolean(section && typeof section === "object" &&
        typeof (section as { heading?: unknown }).heading === "string" &&
        typeof (section as { body?: unknown }).body === "string" &&
        (section as { heading: string }).heading.trim() &&
        (section as { body: string }).body.trim())
    );
    return valid.length ? valid : null;
  } catch {
    return null;
  }
}
