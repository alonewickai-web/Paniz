import Link from "next/link";
import { notFound } from "next/navigation";
import { StorefrontShell } from "../../components/storefront-shell";
import { apiBaseUrl } from "../../lib/catalog";

type PublicShipping = {
  name: string;
  description: string | null;
  estimatedDaysMin: number | null;
  estimatedDaysMax: number | null;
  baseCostToman: number;
  freeOverToman: number | null;
};

const pages: Record<string, { title: string; description: string; sections: { heading: string; body: string }[] }> = {
  shipping: {
    title: "روش‌های ارسال",
    description: "روش، هزینه و زمان تقریبی ارسال سفارش‌های پانیذ",
    sections: [],
  },
  faq: {
    title: "پرسش‌های پرتکرار",
    description: "پاسخ به پرسش‌های رایج خرید از پانیذ",
    sections: [
      { heading: "چطور سایز مناسب را انتخاب کنم؟", body: "در صفحهٔ هر محصول، سایزهای موجود مشخص هستند. جدول اندازه‌گیری پس از ثبت اندازه‌های واقعی هر مدل نمایش داده می‌شود؛ اگر برای محصولی جدول نمی‌بینی، اطلاعات تکمیلی هنوز ثبت نشده است." },
      { heading: "آیا محصولات موجود هستند؟", body: "موجودی رنگ و سایز از دیتابیس بررسی می‌شود. هنگام ثبت درخواست خرید نیز موجودی دوباره کنترل و برای مدت کوتاهی رزرو می‌شود." },
      { heading: "چطور هزینه و وضعیت سفارش را ببینم؟", body: "هزینهٔ ارسال بر اساس روش فعال فروشگاه و مبلغ سفارش در تسویه‌حساب محاسبه می‌شود. برای دیدن وضعیت سفارش ثبت‌شده، شمارهٔ سفارش و تلفن گیرنده را در صفحهٔ حساب کاربری وارد کن." },
      { heading: "پرداخت آنلاین چطور انجام می‌شود؟", body: "درگاه پرداخت هنوز به پروژه متصل نشده است. ثبت درخواست خرید در نسخهٔ فعلی تراکنش بانکی انجام نمی‌دهد و پرداخت‌شده تلقی نمی‌شود." },
    ],
  },
};

export async function generateMetadata({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  return { title: `${pages[slug]?.title ?? "راهنما"} | پانیذ`, description: pages[slug]?.description };
}

export default async function HelpPage({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const page = pages[slug];
  if (!page) notFound();
  const sections = slug === "shipping"
    ? buildShippingSections(await getPublicShipping())
    : slug === "faq"
      ? await getPublicFaqs() ?? page.sections
      : page.sections;
  return <StorefrontShell><main className="store-page"><article className="page-shell store-info-page"><nav className="store-breadcrumb"><Link href="/">خانه</Link><span>/</span><span>راهنما</span><span>/</span><span>{page.title}</span></nav><span className="section-kicker">راهنمای خرید</span><h1>{page.title}</h1><p className="store-info-lead">{page.description}</p><div className="store-info-sections">{sections.map((section) => <section key={section.heading}><h2>{section.heading}</h2><p>{section.body}</p></section>)}</div><Link className="button-primary" href="/products">بازگشت به فروشگاه</Link></article></main></StorefrontShell>;
}

async function getPublicFaqs(): Promise<{ heading: string; body: string }[] | null> {
  try {
    const response = await fetch(`${apiBaseUrl()}/storefront/config`, {
      cache: "no-store",
      signal: AbortSignal.timeout(5000),
    });
    if (!response.ok) return null;
    const payload = await response.json() as {
      data?: { faqs?: { faqs?: unknown } | null };
    };
    const faqs = payload.data?.faqs?.faqs;
    if (!Array.isArray(faqs)) return null;
    const valid = faqs.filter((faq): faq is { question: string; answer: string } =>
      Boolean(faq && typeof faq === "object" &&
        typeof (faq as { question?: unknown }).question === "string" &&
        typeof (faq as { answer?: unknown }).answer === "string" &&
        (faq as { question: string }).question.trim() &&
        (faq as { answer: string }).answer.trim())
    );
    return valid.map(({ question, answer }) => ({ heading: question, body: answer }));
  } catch {
    return null;
  }
}

async function getPublicShipping(): Promise<PublicShipping | null | undefined> {
  try {
    const response = await fetch(`${apiBaseUrl()}/storefront/config`, {
      cache: "no-store",
      signal: AbortSignal.timeout(5000),
    });
    if (!response.ok) return undefined;
    const payload = await response.json() as { data?: { shipping?: PublicShipping | null } };
    return payload.data?.shipping ?? null;
  } catch {
    return undefined;
  }
}

function buildShippingSections(shipping: PublicShipping | null | undefined) {
  if (shipping === undefined) {
    return [
      { heading: "اطلاعات ارسال", body: "دریافت تنظیمات ارسال فروشگاه موقتاً ممکن نیست. کمی بعد دوباره این صفحه را ببین." },
      { heading: "پیگیری مرسوله", body: "پس از ثبت کد رهگیری توسط فروشگاه، وضعیت سفارش در صفحهٔ پیگیری سفارش نمایش داده می‌شود." },
    ];
  }
  if (shipping === null) {
    return [
      { heading: "روش ارسال", body: "روش ارسال هنوز در تنظیمات فروشگاه ثبت نشده است." },
      { heading: "هزینهٔ ارسال", body: "هزینهٔ ارسال پس از ثبت روش ارسال در تنظیمات فروشگاه نمایش داده می‌شود." },
      { heading: "پیگیری مرسوله", body: "پس از ثبت کد رهگیری توسط فروشگاه، وضعیت سفارش در صفحهٔ پیگیری سفارش نمایش داده می‌شود." },
    ];
  }

  const sections = [
    {
      heading: "روش ارسال",
      body: shipping.description?.trim() && shipping.description.trim() !== "هزینهٔ ارسال سفارش بر اساس تنظیم فروشگاه"
        ? `${shipping.name} — ${shipping.description.trim()}`
        : shipping.name,
    },
    {
      heading: "هزینهٔ ارسال",
      body: shipping.baseCostToman === 0
        ? "ارسال سفارش‌ها رایگان است."
        : `هزینهٔ ارسال ${formatShippingMoney(shipping.baseCostToman)} است. مبلغ دقیق در خلاصهٔ سفارش هم نمایش داده می‌شود.`,
    },
    {
      heading: "ارسال رایگان",
      body: shipping.freeOverToman === null
        ? "حد خرید برای ارسال رایگان در تنظیمات فروشگاه تعریف نشده است."
        : `برای سفارش‌هایی که مبلغ کالاهایشان پس از تخفیف به ${formatShippingMoney(shipping.freeOverToman)} یا بیشتر برسد، هزینهٔ ارسال رایگان می‌شود.`,
    },
    {
      heading: "زمان تقریبی تحویل",
      body: formatShippingEstimate(shipping.estimatedDaysMin, shipping.estimatedDaysMax),
    },
    {
      heading: "پیگیری مرسوله",
      body: "پس از ثبت کد رهگیری توسط فروشگاه، وضعیت سفارش در صفحهٔ حساب کاربری نمایش داده می‌شود.",
    },
  ];
  return sections;
}

function formatShippingMoney(value: number) {
  return `${new Intl.NumberFormat("fa-IR").format(value)} تومان`;
}

function formatShippingEstimate(min: number | null, max: number | null) {
  if (min !== null && max !== null) {
    return min === max ? `حدود ${new Intl.NumberFormat("fa-IR").format(min)} روز` : `حدود ${new Intl.NumberFormat("fa-IR").format(min)} تا ${new Intl.NumberFormat("fa-IR").format(max)} روز`;
  }
  if (min !== null) return `از ${new Intl.NumberFormat("fa-IR").format(min)} روز به بعد`;
  if (max !== null) return `حداکثر ${new Intl.NumberFormat("fa-IR").format(max)} روز`;
  return "بازهٔ زمانی تحویل هنوز در تنظیمات فروشگاه ثبت نشده است.";
}
