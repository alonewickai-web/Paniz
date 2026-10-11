import Link from "next/link";
import { MessageCircle } from "lucide-react";
import { StorefrontShell } from "../components/storefront-shell";

export const metadata = { title: "تماس با پانیذ", description: "راه‌های ارتباط با فروشگاه پانیذ." };

export default function ContactPage() {
  return <StorefrontShell><main className="store-page"><article className="page-shell store-info-page"><nav className="store-breadcrumb"><Link href="/">خانه</Link><span>/</span><span>تماس با ما</span></nav><span className="section-kicker"><MessageCircle size={15} /> همراه پانیذ</span><h1>چطور کمکت کنیم؟</h1><p className="store-info-lead">شمارهٔ پشتیبانی، ایمیل و ساعت پاسخ‌گویی هنوز در تنظیمات فروشگاه ثبت نشده‌اند. برای پیگیری سفارشی که ثبت کرده‌ای، شمارهٔ سفارش و موبایل گیرنده را در صفحهٔ حساب کاربری وارد کن.</p><Link className="button-primary" href="/account">پیگیری سفارش</Link><Link className="store-inline-link" href="/help/faq">مشاهدهٔ پرسش‌های پرتکرار</Link></article></main></StorefrontShell>;
}
