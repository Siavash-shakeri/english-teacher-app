# راهنمای ساخت APK — «معلم انگلیسی من» 📦

این راهنما قدم‌به‌قدم توضیح می‌دهد چطور بدون کامپیوتر قوی، فایل نصب (APK) برنامه را بسازی.
دو راه رایگان ابری معرفی می‌شود: **GitHub Actions** (پیشنهاد اول) و **Codemagic**.

> بسته (package): `com.englishteacher.app` — نسخه: `1.0.0+1`

---

## الف) ساخت با GitHub Actions (پیشنهاد اصلی) ☁️

### ۱. ساخت حساب و مخزن (Repo)
1. در [github.com](https://github.com) یک حساب بساز (رایگان).
2. دکمه سبز **New repository** را بزن:
   - نام: مثلاً `english-teacher`
   - گزینه **Public** یا **Private** (هر دو رایگان‌اند؛ Private امن‌تر است)
   - **Create repository**

### ۲. آپلود کد در مخزن
در ترمینال (یا Git Bash) داخل پوشه پروژه:

```bash
git init
git add .
git commit -m "stage 1: skeleton + auth + db schema"
git branch -M main
git remote add origin https://github.com/USERNAME/english-teacher.git
git push -u origin main
```

> `USERNAME` را با نام کاربری گیت‌هابت جایگزین کن.

### ۳. اجرای ورک‌فلو و دانلود APK
1. در صفحه مخزن، تب **Actions** را باز کن.
2. ورک‌فلو **Build APK** را انتخاب کن و دکمه **Run workflow** را بزن
   (با هر push به شاخه `main` که فایل‌های `lib/`، `pubspec.yaml` یا `android/` عوض شوند هم خودکار اجرا می‌شود).
3. چند دقیقه صبر کن تا تیک سبز ✅ بخورد (معمولاً ۵ تا ۱۰ دقیقه).
4. پایین همان صفحه، بخش **Artifacts** → فایل `english-teacher-apk` را دانلود کن.
5. فایل ZIP را باز کن؛ سه فایل APK داخلش است.

### ۴. کدام APK را نصب کنم؟ 🤔

| فایل | یعنی چه؟ | برای چه گوشی؟ |
|---|---|---|
| `app-arm64-v8a-release.apk` | پردازنده ۶۴ بیتی جدید | ✅ تقریباً همه گوشی‌های امروزی (از حدود ۲۰۱۷ به بعد) |
| `app-armeabi-v7a-release.apk` | پردازنده ۳۲ بیتی قدیمی | گوشی‌های خیلی قدیمی |
| `app-x86_64-release.apk` | پردازنده اینتل | شبیه‌ساز (Emulator) روی کامپیوتر |

**قانون ساده:** اول `arm64-v8a` را نصب کن. اگر گوشی‌ات قدیمی است و نصب نشد، `armeabi-v7a`.

> ⚠️ برای نصب، در گوشی «نصب از منابع ناشناس» را برای مرورگر/فایل‌منیجر فعال کن.

---

## ب) ساخت با Codemagic 🪄

1. در [codemagic.io](https://codemagic.io) با حساب GitHub وارد شو (رایگان).
2. **Add application** → مخزن `english-teacher` را انتخاب کن → نوع پروژه **Flutter App**.
3. در تنظیمات Build:
   - **Flutter version:** نسخه‌ای که در `build-apk.yml` آمده (مثلاً 3.47.7)
   - **Build for platforms:** فقط **Android** را تیک بزن
   - **Build type:** Release
4. دکمه **Start new build** را بزن.
5. بعد از اتمام، از بخش **Artifacts** فایل APK را دانلود کن.

> نکته: سهمیه رایگان Codemagic محدود است (ماهانه چند صد دقیقه)؛ GitHub Actions برای مخزن Public کاملاً رایگان و نامحدود است.

---

## ج) ساخت Keystore یک‌بار — تا آپدیت‌ها روی هم نصب شوند 🔑

اندروید برای اینکه نسخه جدید برنامه **روی نسخه قبلی نصب شود** (نه اینکه خطای
`INSTALL_FAILED_UPDATE_INCOMPATIBLE` بدهد)، باید هر دو با **همان کلید امضا** ساخته شده باشند.
پس یک‌بار یک keystore می‌سازیم و در GitHub Secrets ذخیره می‌کنیم:

### ۱. ساخت keystore (یک‌بار، روی هر کامپیوتری با Java)

```bash
keytool -genkey -v \
  -keystore english-teacher-release.keystore \
  -alias english_teacher \
  -keyalg RSA -keysize 2048 -validity 10000
```

- دو رمز ازت می‌خواهد (یکی برای keystore، یکی برای key) — یادداشت و **امن نگهشان دار**.
- فایل `english-teacher-release.keystore` ساخته می‌شود. **ازش بکاپ بگیر** (فلش/درایو)؛ اگر گم شود دیگر هیچ‌وقت نمی‌توانی آپدیت روی نسخه قبلی بدهی!

### ۲. تبدیل به base64 و ذخیره در GitHub Secrets

```bash
base64 -w 0 english-teacher-release.keystore
```

خروجی (یک رشته طولانی) را کپی کن. بعد در صفحه مخزن گیت‌هاب:

**Settings → Secrets and variables → Actions → New repository secret**

و این ۴ سکرت را بساز:

| نام سکرت | مقدار |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | خروجی دستور base64 بالا |
| `ANDROID_KEYSTORE_PASSWORD` | رمز keystore |
| `ANDROID_KEY_ALIAS` | `english_teacher` |
| `ANDROID_KEY_PASSWORD` | رمز key |

از این به بعد، ورک‌فلو `build-apk.yml` خودش keystore را بازسازی می‌کند و APK امضاشده می‌سازد.

> 🔒 این رمزها را **هیچ‌وقت** داخل کد، چت یا فایل عمومی نگذار — فقط در Secrets گیت‌هاب.

---

## خطاهای پرتکرار این مرحله

- **ورک‌فلو قرمز شد:** روی run کلیک کن و لاگ قدم قرمز را بخوان؛ شایع‌ترین علت‌ها در [build-errors-fa.md](build-errors-fa.md) آمده.
- **APK نصب نمی‌شود:** اول مطمئن شو نسخه arm64 را امتحان کرده‌ای؛ اگر قبلاً نسخه‌ای با کلید دیگر نصب بوده، اول آن را پاک کن بعد نصب کن.
