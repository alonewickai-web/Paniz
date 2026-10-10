# اپ مدیریت PanizStyle برای Android

این اپ Flutter برای مدیریت روزانهٔ فروشگاه است. اپ فقط از API مرکزی استفاده می‌کند و هیچ اتصال مستقیمی به MySQL ندارد. نسخهٔ Flutter در **apps/admin-mobile/** و مستندات راه‌اندازی مدیر و API در [docs/admin-api.md](../../docs/admin-api.md) هستند.

## قابلیت‌های متصل

- ورود مدیر با نام کاربری یا شمارهٔ همراه و گذرواژه
- راه‌اندازی یک‌بارهٔ مدیر مالک با **ADMIN_BOOTSTRAP_KEY** و تعیین گذرواژهٔ قوی
- ذخیرهٔ توکن نشست در Secure Storage و خروج از نشست جاری
- تغییر نام کاربری یا گذرواژه با تأیید گذرواژهٔ فعلی؛ این تغییر نشست‌های مدیریتی قبلی را باطل می‌کند
- هش گذرواژه در Backend با Argon2id؛ هش‌های قدیمی scrypt پس از ورود موفق ارتقا می‌یابند
- داشبورد فروش پرداخت‌شدهٔ امروز و ماه، سفارش‌های تازه و هشدار موجودی
- فهرست، ایجاد، ویرایش، پیش‌نویس، انتشار و بایگانی محصول
- مدیریت تنوع رنگ و سایز، قیمت‌ها و تصاویر محصول
- مشاهده و اصلاح موجودی هر تنوع همراه با ثبت دلیل در گردش انبار
- مشاهدهٔ سفارش‌ها و تغییر وضعیت‌های مجاز؛ برای ثبت ارسال کد رهگیری لازم است
- مدیریت دسته‌بندی‌ها، بنرها، رنگ‌بندی و بخش‌های صفحهٔ اصلی سایت
- پنج بخش اصلی: خانه، سفارش‌ها، محصولات، آمار و بیشتر؛ ابزارهای کم‌استفاده در منوی «بیشتر» قرار دارند

## قابلیت‌هایی که هنوز متصل نیستند

مدیریت مشتریان، کد تخفیف، تبلیغات و روبیکا، TOTP، فهرست دستگاه‌های فعال، تاریخچهٔ کامل امنیتی، بازکردن با اثر انگشت و نمودار فروش روزانه هنوز به API متصل نیستند. صفحهٔ آمار فعلی فروش پرداخت‌شدهٔ امروز و ماه و شمار سفارش‌ها را از API می‌گیرد؛ نمودار روزانه و خروجی مالی ندارد.

## دریافت APK از GitHub

فایل‌ها در پوشهٔ **APK/** مخزن قرار دارند و از این نشانی‌های مستقیم قابل دانلودند:

| فایل | معماری دستگاه | لینک |
| --- | --- | --- |
| PanizStyle-Admin-ARM64.apk | ARM64؛ انتخاب پیشنهادی برای بیشتر گوشی‌های جدید | [دانلود مستقیم](https://media.githubusercontent.com/media/alonewickai-web/Paniz/main/APK/PanizStyle-Admin-ARM64.apk) |
| PanizStyle-Admin-ARMV7.apk | ARMV7؛ دستگاه‌های قدیمی ۳۲ بیتی | [دانلود مستقیم](https://media.githubusercontent.com/media/alonewickai-web/Paniz/main/APK/PanizStyle-Admin-ARMV7.apk) |
| PanizStyle-Admin-x86_64.apk | x86_64؛ عمدتاً شبیه‌سازها | [دانلود مستقیم](https://media.githubusercontent.com/media/alonewickai-web/Paniz/main/APK/PanizStyle-Admin-x86_64.apk) |

اگر Android اجازهٔ نصب نداد، برای مرورگری که فایل را گرفته گزینهٔ Install unknown apps را در تنظیمات دستگاه فعال کنید. از بین این سه APK فقط فایل سازگار با معماری دستگاه را نصب کنید.

APK نسخهٔ **0.2.2+4** با HTTPS به API زندهٔ Railway وصل می‌شود و آدرس پیش‌فرض شبیه‌ساز را استفاده نمی‌کند. برای ورود، مدیر باید ابتدا مقدار `ADMIN_BOOTSTRAP_KEY` را در متغیرهای API در Railway تنظیم کند و حساب مالک را از صفحهٔ راه‌اندازی اولیه بسازد. APKها با کلید Debug امضا شده‌اند و برای انتشار در فروشگاه برنامه مناسب نیستند.

## پیش‌نیاز ساخت

- Flutter SDK با Dart سازگار با محدودیت **pubspec.yaml**، یعنی Dart 3.7 یا جدیدتر
- Android SDK و ابزارهای build
- Java 17 یا نسخهٔ سازگارتر با Android Gradle Plugin نصب‌شده
- API فروشگاه برای استفادهٔ واقعی؛ API محلی هم برای آزمایش در دسترس باشد

پیش از ساخت، از پوشهٔ **apps/admin-mobile** اجرا کنید:

~~~powershell
flutter doctor -v
flutter pub get
~~~

## آدرس API و اجرای اپ

آدرس پیش‌فرض اپ **http://10.0.2.2:4000/api/v1/** است؛ این نشانی فقط در Android Emulator به رایانهٔ میزبان اشاره می‌کند. برای آزمایش Debug روی گوشی واقعی، رایانه و گوشی را به یک شبکه وصل کنید، API را برای دسترسی از شبکه آماده کنید و نشانی IP رایانه را استفاده کنید. نمونه:

~~~powershell
flutter build apk --debug --dart-define=PANIZ_API_BASE_URL=http://192.168.1.20:4000/api/v1/ --dart-define=PANIZ_WEB_BASE_URL=http://192.168.1.20:3000/
~~~

IP را با نشانی رایانهٔ خود جایگزین کنید و دسترسی فایروال به پورت API را بررسی کنید. HTTP فقط در ساخت Debug مجاز است.

برای ساخت نسخهٔ Release باید URL واقعی HTTPS API و سایت را هنگام build تعیین کنید؛ مقادیر نمونه را با دامنهٔ واقعی عوض کنید:

~~~powershell
flutter build apk --release --split-per-abi `
  --dart-define=PANIZ_API_BASE_URL=https://api-production-bbf4.up.railway.app/api/v1/ `
  --dart-define=PANIZ_WEB_BASE_URL=https://paniz-production-17f9.up.railway.app/
~~~

برای نسخهٔ فعلی از این مقادیر استفاده کنید:

~~~powershell
flutter build apk --release --split-per-abi `
  --dart-define=PANIZ_API_BASE_URL=https://api-production-bbf4.up.railway.app/api/v1/ `
  --dart-define=PANIZ_WEB_BASE_URL=https://paniz-production-17f9.up.railway.app/
~~~

وقتی دامنهٔ سفارشی فعال شد، URLها را به `https://api.panizstyle.ir/api/v1/` و `https://panizstyle.ir/` تغییر دهید. فرمان بالا سه APK برای ARMV7، ARM64 و x86_64 می‌سازد. خروجی‌ها در **build/app/outputs/flutter-apk/** هستند. هر دستگاه فقط یکی از آن‌ها را نصب می‌کند. Release بدون مقدار HTTPS معتبر برای API قابل استفاده نیست؛ کد اپ در ساخت Release اتصال HTTP را نمی‌پذیرد.

برای نصب یا انتشار نسخهٔ رسمی باید در **android/app/build.gradle.kts** به‌جای signing config دیباگ، کلید امضای Release امن و اختصاصی تنظیم شود. فایل keystore و رمز آن را در Git یا APK قرار ندهید.

## راه‌اندازی مدیر و API

1. در **apps/api/.env** مقدار محرمانهٔ تصادفی برای **ADMIN_BOOTSTRAP_KEY** تنظیم و API را دوباره اجرا کنید.
2. از صفحهٔ «راه‌اندازی اولیهٔ مدیر» در اپ، مدیر مالک را یک بار ایجاد کنید. نام کاربری پیشنهادی فرم **erfan** است و قابل تغییر است؛ گذرواژه را خود مدیر تعیین می‌کند و داخل APK نیست.
3. پس از راه‌اندازی مدیر، کلید bootstrap را از محیط API حذف کنید.
4. برای جزئیات مسیرها، migration، نشست‌ها و محدودیت‌های سفارش به [راهنمای API مدیریت](../../docs/admin-api.md) مراجعه کنید.

در توسعه، سرویس پیامک واقعی متصل نیست و کد آزمایشی ورود مشتری از API برمی‌گردد؛ در production باید سرویس پیامک و **CUSTOMER_AUTH_SECRET** تنظیم شوند. درگاه پرداخت و روش ارسال نیز هنوز به پروژه متصل نشده‌اند.
