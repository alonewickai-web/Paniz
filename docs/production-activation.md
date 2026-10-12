# فعال‌سازی نهایی PanizStyle

استقرار فعلی روی سرور ایران انجام می‌شود و از دیتابیس تازهٔ MySQL استفاده می‌کند. سرویس میزبانی قبلی مرجع اجرای API یا سایت نیست.

## دامنه و HTTPS

در Cloudflare رکوردهای `panizstyle.ir`، `www.panizstyle.ir` و `api.panizstyle.ir` را به IPv4 سرور ایران وصل کنید. ابتدا رکوردها را DNS only بگذارید تا Caddy گواهی معتبر HTTPS بگیرد. جزئیات firewall، اجرای Compose و بررسی سلامت سرویس در [راهنمای سرور ایران](deploy-arvan.md) است.

نشانی‌های نهایی:

- فروشگاه: `https://panizstyle.ir`
- API: `https://api.panizstyle.ir/api/v1`
- سلامت API و دیتابیس: `https://api.panizstyle.ir/api/v1/health/ready`

## اپ مدیر

APK نصب‌شده قبلی در زمان ساخت به API قبلی اشاره می‌کند. بعد از انتشار نسخه‌ای که دامنهٔ API ایران را دارد، APK تازه بسازید و نصب کنید. دستور ساخت در [README اپ اندروید](../apps/admin-mobile/README.md) آمده است.

## SMS و شبکه‌های اجتماعی

کلیدهای SMS.ir، Rubika و Instagram به دیتابیس وابسته نیستند و خودکار منتقل نمی‌شوند. آن‌ها را در فایل خصوصی `.env.server` روی سرور ثبت کنید. برای استفاده از کلید SMS افشاشدهٔ قبلی، اول آن را در پنل SMS.ir تعویض کنید.

## ثبت در گوگل

پس از فعال‌شدن دامنه و HTTPS، این مسیرها را بازبینی کنید:

- `https://panizstyle.ir/robots.txt`
- `https://panizstyle.ir/sitemap.xml`

سپس دامنه را در [Google Search Console](https://search.google.com/search-console) تأیید و `https://panizstyle.ir/sitemap.xml` را ثبت کنید. ثبت sitemap زمان نمایش در نتایج گوگل را تضمین نمی‌کند.
