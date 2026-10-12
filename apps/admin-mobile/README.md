# اپ مدیریت PanizStyle برای Android

این اپ Flutter برای مدیریت روزانهٔ فروشگاه است. اپ فقط از API مرکزی استفاده می‌کند و هیچ اتصال مستقیمی به MySQL ندارد. نسخهٔ جاری `1.0.9+20261012` است؛ نسخه در `pubspec.yaml` تعریف می‌شود و APKهای Release با کلید ثابت امضا می‌شوند تا به‌روزرسانی‌های بعدی بدون حذف برنامه نصب شوند. مستندات راه‌اندازی مدیر و API در [docs/admin-api.md](../../docs/admin-api.md) هستند.

## قابلیت‌های متصل

- ورود مدیر با نام کاربری و گذرواژه
- ساخت خودکار یک‌بارهٔ حساب آزمایشی مدیر توسط API
- ذخیرهٔ توکن نشست در Secure Storage و خروج از نشست جاری
- تغییر نام کاربری یا گذرواژه با تأیید گذرواژهٔ فعلی؛ این تغییر نشست‌های مدیریتی قبلی را باطل می‌کند
- هش گذرواژه در Backend با Argon2id؛ هش‌های قدیمی scrypt پس از ورود موفق ارتقا می‌یابند
- داشبورد فروش پرداخت‌شدهٔ امروز و ماه، سفارش‌های تازه، هشدار موجودی، آمار بازدید سایت و کاربران یکتا
- فهرست، ایجاد، ویرایش کامل اطلاعات کالا (عنوان، نشانی، دسته‌بندی، شرح، جنس، نگهداری، راهنمای سایز و سئو)، پیش‌نویس، انتشار و بایگانی
- دکمهٔ «انتشار» کنار هر محصول برای ارسال تصویر اصلی و کپشن خودکار شامل نام، عنوان، کد، رنگ‌ها، سایزها و لینک خرید به روبیکا
- ایجاد محصول بدون ورود شناسهٔ انگلیسی؛ ساخت خودکار کد `PDC-001` و کد یکتای تنوع‌ها
- انتخاب، افزودن و بایگانی دسته‌بندی از فرم محصول؛ انتخاب سایز از فهرست
- افزودن مستقیم تصویر محصول از گالری گوشی و نمایش پیش‌نمایش قبل از ثبت
- ورود قیمت با جداکنندهٔ سه‌رقمی و اندازهٔ خواناتر
- ویرایش مستقل هر تنوع رنگ/سایز شامل قیمت فروش، قیمت قبل از تخفیف، آستانهٔ هشدار و فعال یا غیرفعال‌کردن؛ کد SKU خودکار و فقط‌خواندنی است
- ویرایش گالری مشترک محصول: بارگذاری و جایگزینی تصویر، متن دسترس‌پذیری، ترتیب نمایش، انتخاب تصویر اصلی و حذف تصویر اضافی
- جست‌وجوی پیشنهادی رنگ با نام یکدست، نمونهٔ HEX و طیف کامل رنگ‌ها
- افزایش یا کاهش موجودی هر تنوع، اتمام موجودی قابل‌فروش همان تنوع و ثبت دلیل در گردش انبار؛ تعداد رزروشده حفظ می‌شود
- مشاهدهٔ سفارش‌ها و تغییر وضعیت‌های مجاز؛ برای ثبت ارسال کد رهگیری لازم است
- مدیریت دسته‌بندی‌ها، بنرها، رنگ‌بندی و بخش‌های صفحهٔ اصلی سایت
- پنج بخش اصلی: خانه، سفارش‌ها، محصولات، آمار و بیشتر؛ ابزارهای کم‌استفاده در منوی «بیشتر» قرار دارند

## قابلیت‌هایی که هنوز متصل نیستند

قابلیت‌های امنیتی پیشرفته شامل TOTP، فهرست دستگاه‌های فعال، تاریخچهٔ کامل امنیتی و بازکردن نشست با اثر انگشت هنوز پیاده‌سازی نشده‌اند. صفحهٔ آمار فروش روز و ماه را کنار آمار بازدید روزانه، بازدیدکنندهٔ یکتا، نمودار هفت‌روزه و صفحات پربازدید نمایش می‌دهد. ارسال پیامک و انتشار در شبکه‌های اجتماعی پس از تنظیم کلیدهای سرویس مربوط در Railway کار می‌کند.

## دریافت APK از GitHub

فایل‌ها در پوشهٔ **APK/** مخزن قرار دارند و از این نشانی‌های مستقیم قابل دانلودند:

| فایل | معماری دستگاه | لینک |
| --- | --- | --- |
| PanizStyle-Admin-ARM64.apk | ARM64؛ انتخاب پیشنهادی برای بیشتر گوشی‌های جدید | [دانلود مستقیم](https://media.githubusercontent.com/media/alonewickai-web/Paniz/main/APK/PanizStyle-Admin-ARM64.apk) |
| PanizStyle-Admin-ARMV7.apk | ARMV7؛ دستگاه‌های قدیمی ۳۲ بیتی | [دانلود مستقیم](https://media.githubusercontent.com/media/alonewickai-web/Paniz/main/APK/PanizStyle-Admin-ARMV7.apk) |
| PanizStyle-Admin-x86_64.apk | x86_64؛ عمدتاً شبیه‌سازها | [دانلود مستقیم](https://media.githubusercontent.com/media/alonewickai-web/Paniz/main/APK/PanizStyle-Admin-x86_64.apk) |

اگر Android اجازهٔ نصب نداد، برای مرورگری که فایل را گرفته گزینهٔ Install unknown apps را در تنظیمات دستگاه فعال کنید. از بین این سه APK فقط فایل سازگار با معماری دستگاه را نصب کنید.

APKهای Release با کلید ثابت Release امضا می‌شوند؛ کلید و رمز آن خارج از Git نگه‌داری می‌شوند. چون امضای نسخه‌های Debug و Release متفاوت است، برای نصب اولین نسخهٔ Release روی گوشی‌ای که نسخهٔ Debug دارد، ابتدا نسخهٔ قبلی را حذف کنید؛ در نسخه‌های بعدی با همین کلید نیازی به حذف برنامه نیست. اگر Play Protect دربارهٔ نصب از منبع ناشناس هشدار داد، ناشی از نصب خارج از Google Play است و امضای Release به‌تنهایی آن هشدار توزیع را حذف نمی‌کند. محافظت Play Protect را خاموش نکنید.

برای ساخت Release، فایل نادیده‌گرفته‌شدهٔ `android/key.properties` باید این چهار مقدار را داشته باشد (مسیر keystore و رمزها را با مقادیر امن سیستم خودتان جایگزین کنید):

~~~properties
storeFile=C:/Users/USER/.android/panizstyle-release.jks
storePassword=YOUR_STORE_PASSWORD
keyAlias=panizstyle-release
keyPassword=YOUR_KEY_PASSWORD
~~~

می‌توان به‌جای فایل، متغیرهای محیطی `PANIZ_RELEASE_STORE_FILE`، `PANIZ_RELEASE_STORE_PASSWORD`، `PANIZ_RELEASE_KEY_ALIAS` و `PANIZ_RELEASE_KEY_PASSWORD` را تنظیم کرد. ساخت Release بدون پیکربندی امضا متوقف می‌شود و به‌صورت ناخواسته با کلید Debug خروجی نمی‌دهد. از keystore و رمزهایش نسخهٔ پشتیبان امن و جدا از مخزن بگیرید؛ گم‌شدن کلید مانع به‌روزرسانی APKهای نصب‌شده خواهد شد.

در محیط آزمایشی با نام کاربری **erfan** و گذرواژهٔ **2018** وارد شوید. API حساب را یک‌بار خودکار می‌سازد و گذرواژه را به‌صورت Argon2id ذخیره می‌کند. این اطلاعات فقط برای آزمایش است؛ پیش از استفاده روی سرور اصلی گذرواژه را عوض کنید.

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

برای ساخت APK نسخهٔ Release روی گوشی واقعی، از URLهای HTTPS استفاده کنید. آدرس‌های Railway فعلی پیش‌فرض اپ هستند؛ فرمان صریح ساخت فقط ARM64:

~~~powershell
flutter build apk --release --target-platform android-arm64 --split-per-abi `
  --dart-define=PANIZ_API_BASE_URL=https://api-production-bbf4.up.railway.app/api/v1/ `
  --dart-define=PANIZ_WEB_BASE_URL=https://paniz-production-17f9.up.railway.app/
~~~

خروجی در **build/app/outputs/flutter-apk/app-arm64-v8a-release.apk** قرار می‌گیرد. وقتی دامنهٔ سفارشی روی Railway فعال شد، URLها را به `https://api.panizstyle.ir/api/v1/` و `https://panizstyle.ir/` تغییر دهید. Release باید از HTTPS استفاده کند؛ نسخهٔ Release به API با HTTP وصل نمی‌شود.

پیکربندی امضای Release در **android/app/build.gradle.kts** انجام شده است. فایل keystore و رمز آن را در Git یا APK قرار ندهید.

## ورود مدیر و API

پس از Deploy شدن API، اپ را با نام کاربری **erfan** و گذرواژهٔ **2018** باز کنید. اگر دیتابیس قبلاً مدیر دیگری داشته، API حساب آزمایشی را هم در اولین راه‌اندازی نسخهٔ جدید ایجاد می‌کند. برای جزئیات مسیرها، migration، نشست‌ها و محدودیت‌های سفارش به [راهنمای API مدیریت](../../docs/admin-api.md) مراجعه کنید.

در توسعه، سرویس پیامک واقعی متصل نیست و کد آزمایشی ورود مشتری از API برمی‌گردد؛ در production باید سرویس پیامک و **CUSTOMER_AUTH_SECRET** تنظیم شوند. درگاه پرداخت و روش ارسال نیز هنوز به پروژه متصل نشده‌اند.
## UI refresh

Version `0.2.12+14` adds 16 coordinated storefront palettes, including two-color gradients, and a recoverable homepage banner archive. Removing a banner takes it off the storefront, keeps its image and content in the archive on the same screen, and lets a manager restore it to the site.

Version `0.2.10+12` adds in-place image uploads from the gallery for product galleries, store categories, homepage banners, and social posts. The shared picker shows a preview and upload progress, supports replacing or removing a selected image, and keeps Instagram's public HTTPS image requirement. It also includes the PANIZ Admin launcher artwork and drag-and-drop homepage section ordering from the previous release.

Version `0.2.6+8` introduces the PANIZ Admin mobile design system: a data-driven dashboard, five-tab RTL navigation, secondary tools in the drawer and More screen, consistent status and empty states, and a saved light/dark preference. A moon/sun toggle is visible at the top of the login page, main tabs, and secondary tool pages. The refreshed screens keep the existing API contracts and operational flows. Sales charts remain absent because the current API does not provide daily trend data.

See [the admin mobile design notes](../../design-system/panizstyle/pages/admin-mobile.md) for palette, interaction, and navigation details.

## New management tools

Version `0.2.8+10` adds customer filters, consent-aware SMS campaigns, coupon management, scheduled Rubika/Instagram publishing, and server/SQL-backup status. Setup requirements and Railway variables are listed in [the admin tools guide](../../docs/admin-customer-marketing-ops.md). External providers remain inactive until their API secrets and account permissions are configured on the backend.

