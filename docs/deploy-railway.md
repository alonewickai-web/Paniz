# استقرار PanizStyle روی Railway

این پروژه برای اجرا روی Railway به سه سرویس نیاز دارد: MySQL، API و سایت. فایل APK اپ مدیریت جداگانه برای Android می‌ماند؛ Railway میزبان APK نیست. پس از استقرار API، باید APK را با نشانی عمومی HTTPS همان API دوباره ساخت.

## ۱. ساخت پروژه و دیتابیس

1. در Railway یک Project بسازید و مخزن GitHub پروژه را به آن وصل کنید.
2. از **New → Database → MySQL** یک سرویس MySQL بسازید و نامش را `MySQL` بگذارید.
3. دیتابیس را عمومی نکنید؛ API از شبکهٔ خصوصی Railway به آن وصل می‌شود.

Railway بر اساس اشتراک و مصرف منابع هزینه می‌گیرد. پلن Hobby در حال حاضر حداقل ۵ دلار در ماه است و ۵ دلار اعتبار مصرف منابع را شامل می‌شود؛ مصرف بالاتر از اعتبار هزینهٔ اضافه دارد. جزئیات را در [صفحهٔ رسمی قیمت‌گذاری Railway](https://docs.railway.com/pricing/plans) ببینید.

## ۲. استقرار API

یک سرویس GitHub دیگر از همان مخزن بسازید و این تنظیمات را اعمال کنید:

- نام سرویس: `api`
- Branch: `main`
- Root Directory: `/apps/api`
- Builder: Dockerfile؛ فایل `apps/api/Dockerfile` به‌صورت خودکار شناسایی می‌شود.
- Healthcheck Path: `/api/v1/health/ready`

در Variables سرویس API این مقادیر را اضافه کنید:

| متغیر | مقدار |
| --- | --- |
| `NODE_ENV` | `production` |
| `DATABASE_URL` | `${{MySQL.MYSQL_URL}}` |
| `DATABASE_CONNECTION_LIMIT` | `5` |
| `WEB_ORIGINS` | پس از اتصال دامنه: `https://panizstyle.ir,https://www.panizstyle.ir` |
| `CUSTOMER_AUTH_SECRET` | یک مقدار تصادفی محرمانه و حداقل ۳۲ نویسه‌ای |
| `UPLOADS_DIR` | `/data/uploads` |
| `BACKUP_DIR` | `/data/backups` |
| `BACKUP_RETENTION_COUNT` | `7` |
| `BACKUP_SCHEDULE_ENABLED` | `true` |

برای ماندگاری تصاویر محصول، در سرویس API از **Settings → Volumes** یک Volume با Mount Path برابر `/data` بسازید. فایل‌های عکس در `UPLOADS_DIR` ذخیره می‌شوند؛ بدون Volume، فایل‌های آپلودی روی دیسک موقت کانتینرند و با جایگزینی آن از بین می‌روند.

Railway متغیر `PORT` را تزریق می‌کند؛ آن را دستی ثابت نکنید. API روی `0.0.0.0` و همان پورت اجرا می‌شود. Dockerfile پیش از شروع API، migrationهای Prisma را اعمال می‌کند.

برای فایل‌های نسخهٔ پشتیبان، همان Volume سرویس API را روی `/data` نگه دارید و `BACKUP_DIR=/data/backups` را تنظیم کنید. API از `mysqldump` نصب‌شده در image برای تهیهٔ فایل SQL استفاده می‌کند؛ صفحهٔ «سرور و پشتیبان‌گیری» در اپ مدیر وضعیت دسترسی Volume و فهرست backupها را نشان می‌دهد. تنظیمات پیامک و انتشار شبکه‌های اجتماعی در [راهنمای ابزارهای مدیریتی](admin-customer-marketing-ops.md) آمده است.

بعد از Deploy، برای API دامنهٔ Railway بسازید و بررسی کنید این مسیر پاسخ موفق بدهد:

```text
https://<دامنه-api>/api/v1/health/ready
```

## ۳. استقرار سایت

یک سرویس GitHub دیگر از همان مخزن بسازید:

- نام سرویس: `storefront`
- Branch: `main`
- Root Directory: `/`
- Builder: Dockerfile؛ فایل `Dockerfile` در ریشهٔ مخزن استفاده می‌شود.
- در Variables مقدارهای زیر را ثبت کنید:

```text
NEXT_PUBLIC_API_BASE_URL=https://api.panizstyle.ir/api/v1
NEXT_PUBLIC_SITE_URL=https://panizstyle.ir
```

برای شروع پیش از اتصال دامنهٔ سفارشی، نشانی API Railway را در `NEXT_PUBLIC_API_BASE_URL` قرار دهید:

```text
https://${{api.RAILWAY_PUBLIC_DOMAIN}}/api/v1
```

سایت روی Railway با دامنهٔ موقت `paniz-production-17f9.up.railway.app` و API با دامنهٔ موقت `api-production-bbf4.up.railway.app` در دسترس‌اند. برای فعال‌کردن دامنهٔ اختصاصی:

1. در سرویس سایت، **Settings → Networking → Custom Domain** را باز و `panizstyle.ir` را اضافه کنید؛ پورت مقصد سایت `8080` است.
2. در سرویس API، همین مسیر را باز و `api.panizstyle.ir` را اضافه کنید؛ پورت مقصد API `4000` است.
3. Railway برای هر دامنه رکوردهای CNAME و TXT مخصوص همان دامنه را نشان می‌دهد. دقیقاً همان مقادیر را در پنل DNS دامنه ثبت کنید؛ برای دامنهٔ ریشه از ALIAS/ANAME یا CNAME flattening پشتیبانی‌شدهٔ سرویس DNS استفاده کنید.
4. پس از تأیید HTTPS، متغیرهای Railway را به نشانی‌های دامنهٔ بالا تغییر دهید و هر دو سرویس را Deploy کنید.

در Variables سرویس API مقدار `WEB_ORIGINS` را به دامنهٔ واقعی سایت تغییر دهید:

```text
https://panizstyle.ir,https://www.panizstyle.ir
```

## ۴. راه‌اندازی مدیر و APK

1. پس از Deploy، API حساب آزمایشی `erfan` با گذرواژهٔ `2018` را به‌صورت خودکار و فقط یک‌بار می‌سازد.
2. در اپ با همین نام کاربری و گذرواژه وارد شوید. کد bootstrap یا متغیر تازه‌ای در Railway لازم نیست.
3. این گذرواژه فقط برای آزمایش است؛ پیش از استفاده روی سرور اصلی آن را از بخش «امنیت و ورود» تغییر دهید.
4. APK نسخهٔ فعلی به API موقت Railway وصل است. پس از فعال‌شدن `api.panizstyle.ir` آن را با دامنهٔ جدید بسازید:

```powershell
cd apps/admin-mobile
flutter build apk --release --split-per-abi `
  --dart-define=PANIZ_API_BASE_URL=https://<دامنه-api>/api/v1/ `
  --dart-define=PANIZ_WEB_BASE_URL=https://<دامنه-سایت>/
```

فایل‌های ساخته‌شده در `apps/admin-mobile/build/app/outputs/flutter-apk/` قرار می‌گیرند.

## ثبت در گوگل

پس از فعال‌شدن دامنه و Deploy، باز کنید:

- `https://panizstyle.ir/robots.txt`
- `https://panizstyle.ir/sitemap.xml`

سپس دامنه را در Google Search Console تأیید و نشانی `https://panizstyle.ir/sitemap.xml` را در بخش Sitemaps ثبت کنید. ارسال sitemap درخواست بررسی است و زمان نمایش در نتایج جست‌وجو را تضمین نمی‌کند. برای دیده‌شدن محصولات، ابتدا محصولات و تصاویر واقعی را از اپ مدیر وارد کنید.

## وضعیت قابلیت‌های نیازمند سرویس بیرونی

ورود پیامکی مشتری در production تا اتصال یک سرویس‌دهندهٔ واقعی SMS فعال نمی‌شود؛ کد ورود آزمایشی فقط برای توسعه است. درگاه پرداخت هم باید پیش از دریافت وجه واقعی جداگانه تنظیم و از سمت سرور تأیید شود. رازها را فقط در Variables Railway ذخیره کنید و هیچ فایل `.env` را در GitHub بارگذاری نکنید.
