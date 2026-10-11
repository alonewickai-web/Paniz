import Link from "next/link";
import { notFound } from "next/navigation";
import { StorefrontShell } from "../../components/storefront-shell";

const pages: Record<string, { title: string; description: string; sections: { heading: string; body: string }[] }> = {
  shipping: {
    title: "روش‌های ارسال",
    description: "اطلاعات ارسال سفارش‌های پانیذ",
    sections: [
      { heading: "هزینهٔ ارسال", body: "هزینهٔ ارسال هنوز در تنظیمات فروشگاه تعریف نشده است. مبلغ نهایی بعد از مشخص‌شدن شهر و روش ارسال به شما اعلام می‌شود؛ جمع کالاها در صفحهٔ تسویه‌حساب شامل ارسال نیست." },
      { heading: "زمان تحویل", body: "زمان تقریبی تحویل به مقصد و روش ارسال وابسته است و پیش از تأیید نهایی سفارش اعلام خواهد شد." },
      { heading: "پیگیری مرسوله", body: "پس از ثبت کد رهگیری توسط فروشگاه، وضعیت سفارش در صفحهٔ پیگیری سفارش نمایش داده می‌شود." },
    ],
  },
  faq: {
    title: "پرسش‌های پرتکرار",
    description: "پاسخ به پرسش‌های رایج خرید از پانیذ",
    sections: [
      { heading: "چطور سایز مناسب را انتخاب کنم؟", body: "در صفحهٔ هر محصول، سایزهای موجود مشخص هستند. جدول اندازه‌گیری پس از ثبت اندازه‌های واقعی هر مدل نمایش داده می‌شود؛ اگر برای محصولی جدول نمی‌بینی، اطلاعات تکمیلی هنوز ثبت نشده است." },
      { heading: "آیا محصولات موجود هستند؟", body: "موجودی رنگ و سایز از دیتابیس بررسی می‌شود. هنگام ثبت درخواست خرید نیز موجودی دوباره کنترل و برای مدت کوتاهی رزرو می‌شود." },
      { heading: "چطور هزینه و وضعیت سفارش را ببینم؟", body: "هزینهٔ ارسال هنوز پیکربندی نشده است. برای دیدن وضعیت سفارش ثبت‌شده، شمارهٔ سفارش و تلفن گیرنده را در صفحهٔ حساب کاربری وارد کن." },
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
  return <StorefrontShell><main className="store-page"><article className="page-shell store-info-page"><nav className="store-breadcrumb"><Link href="/">خانه</Link><span>/</span><span>راهنما</span><span>/</span><span>{page.title}</span></nav><span className="section-kicker">راهنمای خرید</span><h1>{page.title}</h1><p className="store-info-lead">{page.description}</p><div className="store-info-sections">{page.sections.map((section) => <section key={section.heading}><h2>{section.heading}</h2><p>{section.body}</p></section>)}</div><Link className="button-primary" href="/products">بازگشت به فروشگاه</Link></article></main></StorefrontShell>;
}
