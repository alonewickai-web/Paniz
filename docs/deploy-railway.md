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
| `WEB_ORIGINS` | فعلاً `http://localhost:3000`؛ پس از ساخت دامنهٔ سایت، با دامنهٔ واقعی آن جایگزین شود |
| `ADMIN_BOOTSTRAP_KEY` | یک مقدار تصادفی محرمانه و حداقل ۳۲ نویسه‌ای |
| `CUSTOMER_AUTH_SECRET` | یک مقدار تصادفی محرمانه و حداقل ۳۲ نویسه‌ای |

Railway متغیر `PORT` را تزریق می‌کند؛ آن را دستی ثابت نکنید. API روی `0.0.0.0` و همان پورت اجرا می‌شود. Dockerfile پیش از شروع API، migrationهای Prisma را اعمال می‌کند.

بعد از Deploy، از **Settings → Networking → Generate Domain** برای سرویس API دامنه بسازید. سپس بررسی کنید این مسیر پاسخ موفق بدهد:

```text
https://<دامنه-api>/api/v1/health/ready
```

## ۳. استقرار سایت

یک سرویس GitHub دیگر از همان مخزن بسازید:

- نام سرویس: `storefront`
- Branch: `main`
- Root Directory: `/`
- Builder: Dockerfile؛ فایل `Dockerfile` در ریشهٔ مخزن استفاده می‌شود.
- در Variables مقدار `NEXT_PUBLIC_API_BASE_URL` را ثبت کنید:

```text
https://${{api.RAILWAY_PUBLIC_DOMAIN}}/api/v1
```

پیش از Deploy سایت، برای API دامنه بسازید تا نشانی API هنگام build در سایت قرار بگیرد. سپس برای سرویس `storefront` هم از **Settings → Networking → Generate Domain** دامنه بسازید.

در Variables سرویس API مقدار `WEB_ORIGINS` را به دامنهٔ واقعی سایت تغییر دهید:

```text
https://${{storefront.RAILWAY_PUBLIC_DOMAIN}}
```

## ۴. راه‌اندازی مدیر و APK

1. در APK، گزینهٔ «راه‌اندازی اولیهٔ مدیر» را باز کنید.
2. مقدار `ADMIN_BOOTSTRAP_KEY` را از Variables سرویس API وارد کنید و حساب مدیر را بسازید.
3. پس از ساخت مدیر، مقدار `ADMIN_BOOTSTRAP_KEY` را از Railway حذف کنید.
4. APK Release را با دامنه‌های واقعی بسازید:

```powershell
cd apps/admin-mobile
flutter build apk --release --split-per-abi `
  --dart-define=PANIZ_API_BASE_URL=https://<دامنه-api>/api/v1/ `
  --dart-define=PANIZ_WEB_BASE_URL=https://<دامنه-سایت>/
```

فایل‌های ساخته‌شده در `apps/admin-mobile/build/app/outputs/flutter-apk/` قرار می‌گیرند.

## وضعیت قابلیت‌های نیازمند سرویس بیرونی

ورود پیامکی مشتری در production تا اتصال یک سرویس‌دهندهٔ واقعی SMS فعال نمی‌شود؛ کد ورود آزمایشی فقط برای توسعه است. درگاه پرداخت هم باید پیش از دریافت وجه واقعی جداگانه تنظیم و از سمت سرور تأیید شود. رازها را فقط در Variables Railway ذخیره کنید و هیچ فایل `.env` را در GitHub بارگذاری نکنید.
