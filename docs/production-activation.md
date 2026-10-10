# فعال‌سازی نهایی PanizStyle

## وضعیت فعلی

- فروشگاه: <https://paniz-production-17f9.up.railway.app/>
- API: <https://api-production-bbf4.up.railway.app>
- سلامت API و اتصال MySQL: <https://api-production-bbf4.up.railway.app/api/v1/health/ready>
- دامنهٔ موردنظر: `panizstyle.ir`
- فایل‌های APK نسخهٔ `0.2.2+4` با HTTPS به API Railway وصل می‌شوند.

## اتصال دامنه به Railway

در سرویس سایت `Paniz`، از **Settings → Networking → Custom Domain** دامنه‌های `panizstyle.ir` و `www.panizstyle.ir` را اضافه کنید. پورت سرویس سایت `8080` است.

در سرویس `api` نیز `api.panizstyle.ir` را اضافه کنید. پورت API `4000` است. Railway برای هر دامنه رکوردهای DNS مخصوص همان دامنه را نمایش می‌دهد. رکورد CNAME و رکورد TXT تأیید مالکیت را عیناً در پنل DNS دامنه ثبت کنید؛ مقدار این رکوردها یکتا است و نباید حدس زده شود. برای دامنهٔ ریشه، DNS باید ALIAS/ANAME یا CNAME flattening را پشتیبانی کند. پس از تأیید DNS و صدور HTTPS، هر سه نشانی را بازبینی کنید.

## متغیرهای Railway

در سرویس سایت:

```text
NEXT_PUBLIC_SITE_URL=https://panizstyle.ir
NEXT_PUBLIC_API_BASE_URL=https://api.panizstyle.ir/api/v1
```

در سرویس API:

```text
WEB_ORIGINS=https://panizstyle.ir,https://www.panizstyle.ir
CUSTOMER_AUTH_SECRET=<راز تصادفی و محرمانه، حداقل ۳۲ نویسه>
ADMIN_BOOTSTRAP_KEY=<کلید تصادفی یک‌بارمصرف و محرمانه، حداقل ۳۲ نویسه>
```

این مقادیر را در **Variables** سرویس‌های Railway وارد کنید، نه در GitHub. پس از Deploy، APK مدیر را با API سفارشی دوباره بسازید. مدیر با `ADMIN_BOOTSTRAP_KEY` حساب مالک را یک‌بار از صفحهٔ راه‌اندازی اولیه ایجاد کند؛ سپس همان متغیر را از Railway حذف کنید.

## تکمیل فروشگاه

پس از ورود به اپ مدیر، محصولات واقعی، تصاویر، قیمت‌ها، رنگ‌ها، اندازه‌ها و موجودی را ثبت و منتشر کنید. دیتابیس فعلی هنوز محصول منتشرشده ندارد. ورود پیامکی مشتری به سرویس SMS واقعی نیاز دارد و پرداخت بانکی/ارسال سفارش نیز تا اتصال سرویس‌دهندهٔ مربوط آمادهٔ دریافت سفارش واقعی نیست.

## ثبت در گوگل

پس از فعال‌شدن دامنه و Deploy، این مسیرها باید باز شوند:

- <https://panizstyle.ir/robots.txt>
- <https://panizstyle.ir/sitemap.xml>

در [Google Search Console](https://search.google.com/search-console)، مالکیت دامنه را تأیید و `https://panizstyle.ir/sitemap.xml` را در بخش **Sitemaps** ثبت کنید. گوگل زمان مشخصی برای نمایش سایت در نتایج تضمین نمی‌کند؛ ابتدا باید دامنه قابل دسترسی و محتوای واقعی سایت منتشر شده باشد.
