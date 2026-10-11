# PanizStyle API

Backend مستقل پروژه، با NestJS و API نسخه‌دار `/api/v1`.

## راه‌اندازی محلی

1. Node.js نسخهٔ 20.19 یا بالاتر و Docker Desktop را آماده کنید.
2. از ریشهٔ پروژه دیتابیس توسعه را اجرا کنید:

   ```powershell
   Copy-Item database/.env.example database/.env -Force
   docker compose --project-directory database -f database/compose.yaml up -d
   ```

3. از این پوشه وابستگی‌ها را نصب کنید و فایل محیطی بسازید:

   ```powershell
   npm.cmd install
   Copy-Item .env.example .env -Force
   ```

4. `DATABASE_URL` را در `.env` با اطلاعات MySQL محلی هماهنگ کنید. مقدار پیش‌فرض با `database/.env.example` یکسان است.
5. مدل Prisma را تولید و migration اولیهٔ دیتابیس را اعمال کنید:

   ```powershell
   npm.cmd run prisma:generate
   npm.cmd run prisma:migrate:deploy
   npm.cmd run prisma:seed
   ```

6. سرویس را اجرا کنید:

   ```powershell
   npm.cmd run start:dev
   ```

## مسیرها

- `GET /api/v1/health/live`: بررسی زنده‌بودن API.
- `GET /api/v1/health/ready`: بررسی اتصال API به MySQL.
- `GET /api/v1/categories`: دسته‌بندی‌های فعال.
- `GET /api/v1/products?page=1&pageSize=12&category=...&q=...`: فهرست محصولات منتشرشده.
- `POST /api/v1/admin/uploads/product-image`: بارگذاری تصویر محصول برای مدیر؛ فایل‌های قابل قبول JPG، PNG و WebP تا ۸ مگابایت هستند.
- `GET /api/v1/products/:slug`: جزئیات محصول، تصاویر و تنوع‌های فعال.
- `/api/v1/customer/auth/*`: ورود و ساخت حساب مشتری با کد یک‌بارمصرف.
- `/api/v1/customer/profile`, `/api/v1/customer/addresses`, `/api/v1/customer/orders`: حساب و اطلاعات ذخیره‌شدهٔ مشتری؛ نیازمند کوکی نشست.
- POST /api/v1/customer/rubika/link-code و DELETE /api/v1/customer/rubika/link: ساخت کد اتصال بات و قطع اتصال؛ نیازمند کوکی نشست.
- /api/v1/admin/rubika-campaigns/*: پیش‌نمایش مخاطب، ثبت کمپین و ارسال پیام خصوصی روبیکا؛ نیازمند نشست مدیر.
- `POST /api/v1/orders`: ثبت سفارش برای مشتری واردشده با شناسهٔ نشانی متعلق به همان حساب.
- `/api/docs`: مستندات OpenAPI/Swagger.

برای ورود واقعی مشتری، سرویس پیامک و `CUSTOMER_AUTH_SECRET` حداقل ۳۲ کاراکتری را تنظیم کنید. حالت توسعه کد آزمایشی را در پاسخ API برمی‌گرداند؛ این مسیر در production غیرفعال است. شرح جریان و محدودیت‌ها در `docs/customer-account.md` است.

`prisma:seed` هشت محصول نمایشی و دسته‌بندی‌های آنها را وارد دیتابیس توسعه می‌کند. اجرای دوبارهٔ seed موجودی SKUهای موجود را بازنشانی نمی‌کند. از داده‌های نمونه برای فروش واقعی استفاده نکنید.

برای Dockerfile و راه‌اندازی روی Railway، [راهنمای استقرار پروژه](../../docs/deploy-railway.md) را ببینید.

تصاویر آپلودشده در مسیر `UPLOADS_DIR` و زیرشاخهٔ `products` نگهداری می‌شوند. برای ماندگاری روی Railway، Volume سرویس API را روی `/data` سوار و `UPLOADS_DIR=/data/uploads` تنظیم کنید.
