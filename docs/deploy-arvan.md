# استقرار PanizStyle روی سرور ایران

این راهنما برای سرور Ubuntu با Docker Compose نوشته شده است. معماری شامل MySQL خصوصی، API، سایت Next.js و Caddy برای HTTPS است. MySQL و پورت‌های برنامه از اینترنت منتشر نمی‌شوند؛ فقط Caddy روی ۸۰ و ۴۴۳ درخواست‌ها را به سرویس‌ها می‌رساند.

## نکتهٔ دیتابیس جدید

این راه‌اندازی یک دیتابیس خالی می‌سازد و migrationهای Prisma را روی آن اجرا می‌کند. داده‌های سرویس قبلی، مثل مشتری‌ها، سفارش‌ها، محصولات و حساب‌های موجود، منتقل نمی‌شوند. تصاویر آپلودی و backupهای جدید روی volume پایدار `/data` نگهداری می‌شوند.

## ۱. آماده‌کردن سرور

در پنل Arvan و فایروال Ubuntu اجازهٔ ورودی SSH روی پورت ۲۲ و وب روی پورت‌های ۸۰ و ۴۴۳ را بدهید؛ پورت MySQL یعنی ۳۳۰۶ و پورت API یعنی ۴۰۰۰ را عمومی نکنید. اگر UFW نصب نیست، در ترمینال SSH اجرا کنید:

```bash
apt update && apt install -y ufw
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 443/udp
ufw --force enable
ufw status
```

مطمئن شوید Docker و افزونهٔ Compose نصب‌اند:

```bash
docker --version
docker compose version
```

این سرور ۳ گیگابایت RAM دارد و imageها روی خود سرور ساخته می‌شوند. پیش از build، ۲ گیگابایت swap بسازید تا فشار حافظه باعث کشته‌شدن فرایند build نشود؛ این فرمان را فقط یک‌بار اجرا کنید:

```bash
fallocate -l 2G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab
free -h
```

مخزن روی سرور در `/opt/panizstyle` قرار می‌گیرد. پس از انتشار تغییرات، فایل‌ها را به‌روز کنید:

```bash
cd /opt/panizstyle
git pull --ff-only origin main
```

## ۲. ساخت رازهای تازه و راه‌اندازی سرویس‌ها

اسکریپت یک گذرواژهٔ جدا برای MySQL و یک راز برنامه تولید می‌کند و آن‌ها را فقط در `.env.server` با دسترسی محدود ذخیره می‌کند. این فایل را چاپ یا در Git ثبت نکنید.

```bash
cd /opt/panizstyle
bash ops/create-server-env.sh
bash ops/deploy-server.sh
```

اسکریپت MySQL را بالا می‌آورد، imageهای API و سایت را به‌ترتیب می‌سازد، migrationهای دیتابیس جدید را اجرا می‌کند و سلامت API و سایت را بررسی می‌کند. نام volume دیتابیس `panizstyle_mysql_data` است؛ تا وقتی قصد پاک‌کردن کامل داده‌ها را ندارید، `docker compose down -v` اجرا نکنید.

## ۳. اتصال دامنه در Cloudflare

وقتی API و سایت روی سرور سالم شدند، در **Cloudflare → DNS** رکوردهای زیر را به IP سرور وصل کنید. برای شروع، Proxy Status را روی **DNS only** بگذارید تا Caddy مستقیم گواهی HTTPS بگیرد:

| نوع | نام | مقصد |
| --- | --- | --- |
| A | `@` | `188.121.102.173` |
| CNAME | `www` | `panizstyle.ir` |
| A | `api` | `188.121.102.173` |

فقط رکوردهای متعارض همین سه نام را اصلاح یا حذف کنید؛ رکوردهای ایمیل مثل MX و TXT را دست نزنید. پس از اینکه DNS به IP بالا رسید، روی سرور Caddy را اجرا کنید:

```bash
cd /opt/panizstyle
docker compose --env-file .env.server -f compose.server.yaml up -d caddy
docker compose --env-file .env.server -f compose.server.yaml logs -f caddy
```

بعد از صدور گواهی، با `Ctrl+C` نمایش log را ببندید؛ خود سرویس به کار ادامه می‌دهد. در Cloudflare حالت SSL/TLS را **Full (strict)** نگه دارید. اگر رکوردها را بعداً به حالت Proxied تغییر دادید، این حالت را روی Full (strict) حفظ کنید.

## ۴. بررسی آدرس‌ها

پس از فعال‌شدن DNS و HTTPS این دو نشانی باید پاسخ موفق بدهند:

```text
https://api.panizstyle.ir/api/v1/health/ready
https://panizstyle.ir
```

مسیر سلامت API باید اتصال دیتابیس جدید را نیز تأیید کند. API حساب آزمایشی مدیر را یک‌بار با نام `erfan` و رمز `2018` می‌سازد؛ بلافاصله پس از اولین ورود از بخش امنیت رمز را عوض کنید. اطلاعات مدیر و کاتالوگ جدید از دیتابیس قبلی کپی نمی‌شوند.

## ۵. اپ اندروید و اتصال‌های بیرونی

پیش‌فرض سورس اپ مدیر و سایت روی API جدید `https://api.panizstyle.ir/api/v1` قرار گرفته است. APK نصب‌شده قبلی همچنان نشانی قدیمیِ زمان ساخت خودش را دارد؛ برای اتصال آن باید APK تازه‌ای از همین نسخه ساخته و نصب شود.

این سرور SMS.ir و Rubika را از محیط قبلی به ارث نمی‌برد. متغیرهای محرمانه را فقط در `/opt/panizstyle/.env.server` روی سرور تنظیم کنید و کانتینر API را دوباره بسازید. چون کلید SMS قبلی در گفتگو افشا شده، پیش از استفادهٔ دوباره آن را در پنل SMS.ir تعویض کنید. تا وقتی اعتبارنامهٔ SMS.ir روی سرور ثبت نشود، ورود پیامکی مشتری کار نمی‌کند.

## عملیات روزمره

```bash
cd /opt/panizstyle
docker compose --env-file .env.server -f compose.server.yaml ps
docker compose --env-file .env.server -f compose.server.yaml logs --tail=100 api
docker compose --env-file .env.server -f compose.server.yaml logs --tail=100 storefront
```

برای انتشار نسخهٔ تازه، ابتدا `git pull --ff-only origin main` و سپس `bash ops/deploy-server.sh` را اجرا کنید. اگر تغییر شامل migration باشد، اسکریپت آن را قبل از بالا آوردن API اجرا می‌کند.
