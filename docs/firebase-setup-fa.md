# راهنمای کامل آماده‌سازی Firebase — مرحله ۷ 🔥

> این راهنما قدم‌به‌قدم و به زبان ساده است. بدون انجام این مراحل،
> اپ کاملاً آفلاین کار می‌کند و در تنظیمات پیام «Firebase هنوز
> پیکربندی نشده» می‌بینی — این طبیعی است و خطا نیست.

---

## ۱. ساخت پروژه Firebase

1. به [console.firebase.google.com](https://console.firebase.google.com) برو و با حساب گوگل وارد شو.
2. **Add project** (ایجاد پروژه) → نام: مثلاً `english-teacher-app`.
3. Google Analytics اختیاری است (می‌توانی خاموش بگذاری).
4. **Create project** و چند ثانیه صبر کن.

## ۲. افزودن اپ اندروید

1. در داشبورد پروژه، روی آیکون **اندروید** (Add an app) کلیک کن.
2. **Android package name:** دقیقاً این را وارد کن:
   ```
   com.englishteacher.app
   ```
   (باید دقیقاً با `applicationId` در `android/app/build.gradle` یکی باشد.)
3. **App nickname:** مثلاً `English Teacher Android` (اختیاری).
4. **SHA certificate fingerprints (اثر انگشت گواهی):**
   - برای نسخهٔ دیباگ (تست): در ترمینال لینوکس/ویندوز:
     ```
     keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
     ```
     مقدار **SHA1** و **SHA256** را کپی کن و در همین فرم Firebase وارد کن.
   - برای نسخهٔ نهایی که از GitHub Actions می‌سازی: اثر انگشت گواهی امضای خودت را از همان‌جا وارد کن.
   - ⚠️ اگر اثر انگشت را وارد نکنی، بعضی سرویس‌ها (مثل ورود با گوگل در آینده) کار نمی‌کنند؛ ولی برای همگام‌سازی ایمیل/رمز، الزامی نیست.
5. **Register app**.

## ۳. دانلود `google-services.json` و جای‌گذاری

1. فایل `google-services.json` را دانلود کن.
2. آن را دقیقاً در این مسیر پروژه بگذار:
   ```
   android/app/google-services.json
   ```
3. ⚠️ **این فایل را هیچ‌وقت در مخزن Public آپلود نکن.** در `.gitignore` این خط را اضافه کن:
   ```
   google-services.json
   ```

## ۴. تنظیم Gradle اندروید

1. در فایل `android/build.gradle` (سطح پروژه)، داخل `plugins` یا `dependencies`:
   ```gradle
   dependencies {
       classpath 'com.google.gms:google-services:4.4.2'
   }
   ```
2. در فایل `android/app/build.gradle` (سطح اپ)، **انتهای فایل**:
   ```gradle
   apply plugin: 'com.google.gms.google-services'
   ```
   (اگر از بلوک `plugins {}` استفاده می‌کنی، به‌جای آن این خط را در `plugins` بگذار:
   `id 'com.google.gms.google-services'`)
3. مطمئن شو `minSdk` برابر **۲۴** یا بیشتر است (در `android/app/build.gradle`).

## ۵. فعال‌سازی سرویس‌ها در کنسول

از منوی **Build** کنسول Firebase:

### Authentication (احراز هویت)
1. Build → **Authentication** → **Get started**.
2. تب **Sign-in method** → روی **Email/Password** کلیک کن → **Enable** → Save.
3. (ورود با گوگل لازم نیست.)

### Cloud Firestore (پایگاه داده ابری)
1. Build → **Firestore Database** → **Create database**.
2. حالت **production mode** را انتخاب کن.
3. منطقه (location): نزدیک‌ترین، مثلاً `europe-west3` یا `asia-southeast1`.
4. بعد از ساخت، تب **Rules** را باز کن و این قوانین را بگذار (فقط صاحب داده به داده‌اش دسترسی دارد):
   ```
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /users/{uid}/{document=**} {
         allow read, write: if request.auth != null && request.auth.uid == uid;
       }
     }
   }
   ```
5. **Publish** را بزن.

### Storage (فضای ذخیرهٔ فایل)
1. Build → **Storage** → **Get started** → حالت production.
2. تب **Rules**:
   ```
   rules_version = '2';
   service firebase.storage {
     match /b/{bucket}/o {
       match /users/{uid}/{allPaths=**} {
         allow read, write: if request.auth != null && request.auth.uid == uid;
       }
     }
   }
   ```
3. **Publish** را بزن.

## ۶. ساخت APK با Firebase

بعد از مراحل بالا، مثل همیشه از GitHub Actions (طبق `docs/build-apk-fa.md`) خروجی بگیر.
اولین اجرای اپ روی گوشی، Firebase را مقداردهی می‌کند؛ اگر همه‌چیز درست
باشد، در تنظیمات بخش «همگام‌سازی ابری» وضعیت **متصل ✅** را می‌بینی.

## ۷. عیب‌یابی رایج

| مشکل | راه‌حل |
|---|---|
| پیام «Firebase هنوز پیکربندی نشده» | `google-services.json` در `android/app/` نیست یا پلاگین google-services در Gradle اعمال نشده |
| خطای `API key not found` | فایل json برای همین package name نیست؛ دوباره دانلود کن |
| همگام‌سازی ناموفق با خطای دسترسی | قوانین Firestore/Storage (مرحله ۵) را چک کن و Publish را بزن |
| ایمیل بازیابی رمز نمی‌آید | در Authentication، قالب ایمیل (Templates) را چک کن؛ پوشهٔ اسپم را هم ببین |

---

## ۸. در مرحله ۷ چه کدی وصل شده است؟

- `lib/data/sync/firebase_service.dart` — مقداردهی اولیه، تشخیص پیکربندی، کاربر Firebase، ارسال ایمیل بازیابی رمز
- `lib/data/sync/sync_engine.dart` — موتور همگام‌سازی همهٔ جدول‌ها با قانون «جدیدترین می‌ماند، نسخهٔ قبلی نگه‌داری می‌شود»
- `lib/data/export/export_service.dart` — خروجی PDF (راست‌به‌چپ، فونت وزیرمتن) و JSON
- `lib/presentation/screens/settings/sync_section.dart` — رابط کاربری پشتیبان‌گیری/بازیابی/همگام‌سازی خودکار/خروجی
- پلاگین‌های `pubspec.yaml`: `firebase_core ^5.0.0`، `firebase_auth ^7.0.0`، `cloud_firestore ^7.0.0`، `firebase_storage ^14.0.0`، `connectivity_plus ^7.3.2`، `pdf ^3.13.1` `share_plus ^13.3.1`
