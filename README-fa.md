# معلم انگلیسی من 🇬🇧📚

اپلیکیشن اندرویدی آموزش زبان انگلیسی برای فارسی‌زبان‌ها — کاملاً آفلاین، راست‌به‌چپ، با طراحی Material 3 و فونت وزیرمتن.

> بسته: `com.englishteacher.app` — نسخه: `1.0.0+1`

## مرحله ۱ شامل چه چیزهایی است؟ ✅

- [x] اسکلت پروژه Flutter (ساختار پوشه‌ها، تم روشن/تیره، مسیریابی)
- [x] ورود چندحسابه محلی (هر نفر حساب خودش را دارد؛ رمزها هش‌شده ذخیره می‌شوند)
- [x] اسکیمای کامل دیتابیس محلی (SQLite): حساب‌ها، دفتر «قواعد من»، لغت‌ها، آزمون‌ها و یادآوری مرور
- [x] ورک‌فلو GitHub Actions برای ساخت خودکار APK

## ساختار پوشه‌ها 🗂️

```
english-teacher-app/
├── lib/
│   ├── main.dart                 # نقطه شروع برنامه
│   ├── core/                     # تم، ثابت‌ها، ابزارهای مشترک
│   ├── data/                     # دیتابیس (SQLite)، مدل‌ها، ریپازیتوری‌ها
│   └── presentation/             # صفحه‌ها و ویجت‌ها (UI)
├── android/                      # تنظیمات اندروید (package: com.englishteacher.app)
├── .github/workflows/
│   └── build-apk.yml             # ساخت خودکار APK در گیت‌هاب
├── docs/
│   ├── build-apk-fa.md           # راهنمای ساخت APK (گیت‌هاب/کدمجیک/keystore)
│   ├── firebase-setup-fa.md      # آماده‌سازی Firebase (مرحله ۷)
│   ├── dependencies-fa.md        # جدول وابستگی‌ها و دلیل انتخابشان
│   └── build-errors-fa.md        # خطاهای پرتکرار بیلد و راه‌حل
└── pubspec.yaml                  # نام: english_teacher — نسخه: 1.0.0+1
```

## باز کردن پروژه در ویرایشگر 💻

**VS Code:**
1. افزونه Flutter را نصب کن.
2. پوشه `english-teacher-app` را باز کن (File → Open Folder).
3. `flutter pub get` را در ترمینال اجرا کن.

**Android Studio:**
1. افزونه Flutter را نصب کن.
2. Open → پوشه `english-teacher-app` را انتخاب کن.
3. صبر کن تا `pub get` خودکار انجام شود.

## گرفتن APK 📦

کافی است کد را push کنی یا ورک‌فلو را دستی اجرا کنی — راهنمای کامل قدم‌به‌قدم:

👉 **[docs/build-apk-fa.md](docs/build-apk-fa.md)**

## نقشه راه مرحله‌ها 🗺️

| مرحله | موضوع | وضعیت |
|---|---|---|
| ۱ | اسکلت + ورود چندحسابه + دیتابیس محلی + CI | ✅ انجام شد |
| ۲ | اسکن تکلیف دست‌نویس (دوربین/گالری، تمیزکاری تصویر، تشخیص متن) | ⏳ |
| ۳ | ترجمه با تپ روی لغت | ✅ |
| ۴ | درس‌های عمیق گرامر فارسی + دفتر «قواعد من» | ✅ |
| ۵ | چت با معلم هوش مصنوعی (کلید در تنظیمات، رمزنگاری‌شده) | ✅ |
| ۶ | آزمون‌ها + تکرار با فاصله (Spaced Repetition) | ✅ |
| ۷ | همگام‌سازی ابری با Firebase + خروجی PDF/JSON | ✅ |

> هر ۷ مرحله کامل شد ✅ — از این به بعد مرحله‌های جدید (در صورت درخواست) خودکار پشت سر هم ساخته می‌شوند.

## قوانین مشارکت 🤝

- کامنت‌ها و نام‌های فارسی/انگلیسی خوانا؛ **کامنت‌های توضیحی فارسی** بنویس.
- **هیچ رمزی در کد نگذار** — نه کلید API، نه توکن، نه رمز دیتابیس. کلیدها فقط در تنظیمات برنامه (توسط خود کاربر) وارد می‌شوند.
- قبل از push، `flutter analyze` باید سبز باشد (ورک‌فلو هم همین را چک می‌کند).
- متن‌های نمایشی به فارسی؛ استایل کد طبق `flutter_lints`.

## مرحله ۲ — اسکن دست‌نویس ✅

بخش «مشق‌ها» حالا واقعی است: مشق دست‌نویس را اسکن کن، متن را تصحیح کن، ذخیره کن.

- [x] انتخاب تصویر از **دوربین یا گالری** (image_picker)
- [x] **برش (crop)** تصویر قبل از اسکن — برای قاب‌بندی دقیق دست‌نویس (crop_your_image)
- [x] **تمیزکاری تصویر** (package:image): خاکستری‌کردن + افزایش کنتراست برای خواناتر شدن متن؛ صادقانه بگویم: اصلاح پرسپکتیو خودکار نداریم — قاب‌بندی را با همان ابزار برش انجام بده
- [x] تشخیص متن **کاملاً آفلاین** با ML Kit (google_mlkit_text_recognition)؛ مدل تشخیص در اولین استفاده دانلود می‌شود، پس خود APK سبک می‌ماند
- [x] **Stub برای Gemini Vision**: موتور ابری آماده است ولی واقعی‌اش در مرحله ۵ وصل می‌شود (وقتی کلید در تنظیمات وارد شود)
- [x] متن استخراج‌شده قبل از ذخیره **قابل ویرایش** است — غلط‌های تشخیص را خودت اصلاح کن
- [x] **چندصفحه‌ای**: هر مشق می‌تواند چند عکس داشته باشد و متن همه‌شان کنار هم ذخیره می‌شود
- [x] ذخیره‌سازی **جداگانه برای هر حساب** (SharedPreferences + حافظه محلی)
- [x] فهرست مشق‌ها: عنوان، تاریخ ثبت و خلاصه‌ی متن؛ مشاهده‌ی جزئیات با تصاویر صفحه‌ها؛ حذف با تأیید

> نکته: تاریخ‌های نمایش داده‌شده فعلاً **میلادی با ارقام فارسی** هستند؛ تبدیل به شمسی در نسخه‌های بعد اضافه می‌شود.

صفحه‌های مرتبط: `lib/presentation/screens/scan/scan_screen.dart` · `lib/presentation/screens/homeworks/`

## مرحله ۳ — ترجمه ✅

حالا متن هر مشق را جمله‌به‌جمله به فارسی ترجمه کن و با تپ روی هر کلمه، معنی و جمله‌ی نمونه‌اش را ببین.

- [x] **ترجمه‌ی جمله‌به‌جمله**: زیر هر جمله‌ی انگلیسی، با دکمه‌ی «نمایش ترجمه» ترجمه‌ی فارسی‌اش ظاهر می‌شود (نتیجه کش می‌شود تا rebuild دوباره ترجمه نکند)
- [x] ترجمه‌ی **کاملاً آفلاین** با ML Kit (google_mlkit_translate)؛ مدل ترجمه در اولین استفاده دانلود می‌شود (حین دانلود پیام «دانلود مدل ترجمه…» نشان داده می‌شود)، پس خود APK سبک می‌ماند
- [x] **Stub برای Gemini**: موتور ابری آماده است ولی واقعی‌اش در مرحله ۵ وصل می‌شود (وقتی کلید در تنظیمات وارد شود) — در رابط کاربری به‌صورت غیرفعال با توضیح «در مرحله ۵ فعال می‌شود» نشان داده می‌شود
- [x] **تپ روی لغت**: با تپ روی هر کلمه، پنجره‌ای (bottom sheet) باز می‌شود با خود کلمه، معنی فارسی، جمله‌ی نمونه (همان جمله‌ای که کلمه از آن آمده) و دکمه‌ی «افزودن به فلش‌کارت»
- [x] فلش‌کارت‌ها در دیتابیس محلی و **جداگانه برای هر حساب** ذخیره می‌شوند (جدول words)

> نکته‌ی صادقانه: تلفظ و نقش دستوری (اسم/فعل/…) هر کلمه را نمی‌توان آفلاین حدس زد؛ این‌ها با هوش مصنوعی در **مرحله ۵** کامل می‌شوند.

فایل‌های مرتبط: `lib/presentation/screens/homeworks/homework_detail_screen.dart` · `lib/presentation/widgets/tappable_text.dart` · `lib/data/translate/translate_service.dart` · `lib/data/translate/sentence_splitter.dart` · `lib/domain/models/word.dart` · `lib/domain/repositories/vocabulary_repository.dart` · `lib/data/vocabulary/local_vocabulary_repository.dart`

## مرحله ۴ — قواعد ✅

دفتر شخصی «قواعد من»: هر قاعده با دسته‌بندی، توضیح کامل فارسی، فرمول، مثال‌ها و اشتباهات رایج فارسی‌زبانان ذخیره می‌شود؛ ستاره‌دار کردن، جست‌وجو و حذف هم دارد.

- [x] **«قواعد من» کامل**: فهرست قواعد حساب فعال، گروه‌بندی‌شده بر اساس دسته (زمان‌ها، حروف اضافه، جملات شرطی، …)؛ جست‌وجو در عنوان/دسته/توضیح؛ فیلتر «فقط ستاره‌دارها»؛ ستاره و حذف با تأیید؛ حالت خالی با راهنما و بارگذاری اسکلتی
- [x] **صفحهٔ جزئیات قاعده**: توضیح، فرمول (چپ‌به‌راست)، مثال‌ها با ترجمه، اشتباهات رایج (⚠️)، تاریخ اولین دیدن با ارقام فارسی، و «کلمات کلیدی» با دکمهٔ افزودن به فلش‌کارت
- [x] **قانون عدم تکرار**: قاعده‌ای که با همان دسته و عنوان (بدون حساسیت به بزرگی/کوچکی حروف) قبلاً ثبت شده، دوباره ساخته نمی‌شود — فقط به‌روز می‌شود (در `LocalGrammarRepository.upsertRule`)
- [x] **افزودن دستی**: دکمهٔ «📚 تحلیل قواعد این مشق» در صفحهٔ جزئیات هر مشق، و دکمهٔ شناور «قاعدهٔ دستی» در تب قواعد
- [x] **Stub برای تحلیل خودکار Gemini**: موتور `GeminiAnalysisEngine` با همان الگوی مرحله‌های ۲ و ۳ — `isAvailable=false` و پرتاب خطا با پیام فارسی؛ هرگز تحلیل جعلی نشان داده نمی‌شود. در مرحلهٔ ۵ با همان رابط، واقعی وصل می‌شود و هیچ صفحه‌ای نیاز به تغییر ندارد

> نکته‌ی صادقانه: تحلیل خودکار هر مشق (زمان و ساختار هر جمله، توضیح قاعده با دلیل، مثال‌ها، اصلاح اشتباه‌های خودت) به کلید Gemini نیاز دارد که در **مرحله ۵** در تنظیمات وارد می‌شود؛ تا آن موقع دفتر «قواعد من» با افزودن دستی کاملاً قابل‌استفاده است.

فایل‌های مرتبط: `lib/domain/models/grammar_rule.dart` · `lib/domain/repositories/grammar_repository.dart` · `lib/data/grammar/local_grammar_repository.dart` · `lib/data/analysis/analysis_service.dart` · `lib/presentation/screens/grammar/grammar_screen.dart` · `lib/presentation/screens/grammar/grammar_rule_detail_screen.dart` · `lib/presentation/screens/grammar/manual_rule_sheet.dart` · `lib/presentation/widgets/fa_digits.dart`

## مرحله ۵ — معلم هوش مصنوعی ✅

چت فارسی با Gemini که به مشق‌ها و «قواعد من» تو دسترسی دارد.

- [x] **کلاینت مشترک Gemini** (`lib/data/ai/gemini_client.dart`): REST بدون SDK، پاسخ معمولی + استریمینگ (SSE)، خطاهای فارسی (قطعی اینترنت، کلید نامعتبر، تمام شدن سهمیه، خطای سرور). مدل پیش‌فرض `gemini-3.8-flash` و قابل تغییر در تنظیمات (گزینه‌ها: 3.8/3.7/3.6/3.5-flash؛ مدل‌های 2.0 خاموش و 2.5 برای پروژه‌های جدید محدودند)
- [x] **کلید رمزنگاری‌شده**: `flutter_secure_storage` (Keystore + AES-GCM)؛ کلید فقط در تنظیمات وارد می‌شود، در UI فقط ماسک‌شده نمایش داده می‌شود (`AIza•••x9Q2`)، هیچ‌وقت در کد/لاگ/خطا نیست
- [x] **صفحهٔ چت**: پیام‌های فارسی راست‌به‌چپ، استریم زنده، نشانگر «در حال فکر کردن…»، تلاش دوباره با پیام خطای فارسی، گفت‌وگوی جدید (پاک‌سازی تاریخچه)، چیپ‌های پیشنهاد سریع
- [x] **تاریخچهٔ هر حساب جدا**: جدول `chat_messages` (قبلاً در اسکیما بود) + مخزن `LocalChatRepository` با حذف نرم
- [x] **تزریق بافت**: دستور سیستمی شامل حداکثر ۲۰ قاعده (اول ستاره‌دارها) و ۱۰ مشق اخیر با سقف نویسه — مستند در `ContextBuilder`
- [x] **«بپرس از هوش مصنوعی»**: کنار هر جمله در صفحهٔ مشق و هر قاعده در «قواعد من»؛ بدون کلید → دیالوگ فارسی + هدایت به تنظیمات
- [x] **سیم‌کشی استاب‌های قبلی**: `GeminiVisionOcrEngine` (اسکن آنلاین واقعی)، `GeminiTranslateEngine` (ترجمهٔ آنلاین واقعی) و `GeminiAnalysisEngine` (تحلیل گرامری واقعی با خروجی JSON ساخت‌یافته) — همه فقط وقتی کلید هست فعال‌اند، وگرنه همان رفتار صادقانهٔ قبلی
- [x] **صفحهٔ نتیجهٔ تحلیل**: زمان/ساختار هر جمله، اصلاح اشتباه‌ها با دلیل، قواعد پیشنهادی با «ذخیره در قواعد من»، کلمات کلیدی با «افزودن به فلش‌کارت»
- [x] **راهنمای کلید**: `docs/ai-studio-key-fa.md` — گرفتن کلید رایگان از Google AI Studio قدم‌به‌قدم

> نکته‌ی صادقانه: بدون کلید، همهٔ بخش‌های آنلاین همان پیام فارسی «کلید را در تنظیمات وارد کن» را نشان می‌دهند و هیچ نتیجه‌ای جعل نمی‌شود. کامپایل واقعی با GitHub Actions (`flutter analyze`) چک می‌شود.

فایل‌های مرتبط: `lib/data/ai/gemini_client.dart` · `lib/data/ai/secure_key_store.dart` · `lib/data/ai/ai_gate.dart` · `lib/data/ai/context_builder.dart` · `lib/data/ai/local_chat_repository.dart` · `lib/domain/models/chat_message.dart` · `lib/domain/repositories/chat_repository.dart` · `lib/presentation/screens/ai_tutor/ai_tutor_screen.dart` · `lib/presentation/screens/settings/ai_key_section.dart` · `lib/presentation/widgets/ask_ai_button.dart` · `lib/presentation/screens/grammar/analysis_result_screen.dart` · `docs/ai-studio-key-fa.md`

## مرحله ۶ — تمرین‌ها ✅

آزمون‌سازی آفلاین از داده‌های خودت + تکرار با فاصلهٔ زمانی.

- [x] **مدل تمرین** (`lib/domain/models/exercise.dart`): `ExerciseSet` دقیقاً مطابق جدول `exercises` (عنوان و سؤال‌ها داخل `payload` چون جدول ستون عنوان ندارد)، `QuizQuestion` (نوع، متن سؤال، گزینه‌ها، پاسخ درست، راهنما)، `ScoreRecord` برای جدول `scores`
- [x] **تولیدکنندهٔ آفلاین** (`lib/data/exercises/exercise_generator.dart`): خالص و بدون دیتابیس؛ ۴ نوع سؤال — جای خالی (حذف کلمهٔ محتوایی از جمله‌های مشق‌ها، ترجیح کلمات دفتر واژگان)، تستی انگلیسی→فارسی، تستی فارسی→انگلیسی (از دفتر واژگان)، مرتب‌سازی کلمات (جمله‌های ۳ تا ۸ کلمه‌ای)؛ با `seed` تکرارپذیر و قابل تست؛ کمبود داده → خطای فارسی `QuizDataShortage` («اول چند مشق اسکن کن و چند کلمه اضافه کن 🙂»)
- [x] **مخزن تمرین** (`lib/data/exercises/local_exercise_repository.dart` + قرارداد دامنه): ذخیرهٔ مجموعه، فهرست، حذف نرم، ثبت نمره در `scores`، میانگین درصد — همه در محدودهٔ حساب فعال
- [x] **اجرای آزمون** (`quiz_setup_screen.dart` + `quiz_screen.dart`): انتخاب نوع‌ها و تعداد (۵/۱۰/۱۵)، یک سؤال در هر صفحه با نوار پیشرفت، بازخورد فوری فارسی (درست/غلط + پاسخ درست + 💡 راهنما)، مرتب‌سازی با چیپ‌های لمسی، صفحهٔ نتیجه با درصد و ثبت خودکار نمره
- [x] **تکرار با فاصله** (`lib/data/review/spaced_repetition.dart`): SM-2 سبک روی جدول‌های `words` و `flashcards` — درست: repetitions+۱ و فاصلهٔ ۱/۶/interval×ease؛ غلط: بازگشت به ۱ روز؛ `dueReviews()` آیتم‌های سررسیده را می‌دهد
- [x] **مرور امروز** (`review_screen.dart`): کارت فلش (نمایش پاسخ → «بلدم / بلد نیستم») با شمارش پیشرفت و صفحهٔ پایان 🎉
- [x] **پیشرفت و تاریخچه**: نمودار میله‌ای CustomPainter (بدون وابستگی جدید) از ۱۲ نمرهٔ اخیر + میانگین، فهرست نمره‌ها با تاریخ فارسی و امکان حذف تاریخچه
- [x] **یکپارچه‌سازی**: دکمهٔ «📝 تمرین بساز» در نوار بالای صفحهٔ جزئیات مشق → آزمون فقط از همان مشق
- [x] **رفع تداخل ML Kit**: `google_mlkit_text_recognition` به `^0.15.1` ارتقا یافت چون `^0.13.1` با `google_mlkit_translation: ^0.13.0` در حل نسخه (`google_mlkit_commons`) تداخل داشت — جزئیات در [docs/dependencies-fa.md](docs/dependencies-fa.md)

> نکته‌ی صادقانه: همهٔ سؤال‌ها از مشق‌ها و کلمه‌های خودت ساخته می‌شوند؛ اگر داده کم باشد به‌جای آزمون خالی، پیام راهنمای فارسی می‌بینی. کامپایل واقعی با GitHub Actions (`flutter analyze`) چک می‌شود.

فایل‌های مرتبط: `lib/domain/models/exercise.dart` · `lib/domain/repositories/exercise_repository.dart` · `lib/data/exercises/exercise_generator.dart` · `lib/data/exercises/local_exercise_repository.dart` · `lib/data/review/spaced_repetition.dart` · `lib/presentation/screens/exercises/exercises_screen.dart` · `lib/presentation/screens/exercises/quiz_setup_screen.dart` · `lib/presentation/screens/exercises/quiz_screen.dart` · `lib/presentation/screens/exercises/review_screen.dart` · `lib/presentation/screens/exercises/history_screen.dart` · `lib/presentation/screens/exercises/score_chart.dart`

## مرحله ۷ — همگام‌سازی ابری + خروجی ✅

پشتیبان‌گیری ابری با Firebase، بازیابی، همگام‌سازی خودکار و خروجی PDF/JSON — آخرین مرحلهٔ پروژه.

- [x] **سرویس Firebase** (`lib/data/sync/firebase_service.dart`): مقداردهی اولیه با `try/catch` — اگر `google-services.json` نباشد، اپ کاملاً آفلاین می‌ماند و همه‌جا پیام فارسی «Firebase هنوز پیکربندی نشده» نشان داده می‌شود (هیچ رفتار جعلی). کاربر Firebase با ایمیل حساب محلی (رمز تصادفی در حافظهٔ رمزنگاری‌شده)، ارسال ایمیل بازیابی رمز، دسترسی به Firestore و Storage. هیچ کلیدی در کد نیست.
- [x] **موتور همگام‌سازی** (`lib/data/sync/sync_engine.dart`): push/pull همهٔ جدول‌ها (`homeworks`، `grammar_rules`، `words`، `flashcards`، `exercises`، `scores`، `chat_messages`) در مسیر `users/{uid}/{table}/{id}`. **قانون تعارض: جدیدترین می‌ماند، نسخهٔ قبلی نگه‌داری می‌شود** — هر بازنویسی با هر دو نسخه در فایل محلی `sync_conflicts.jsonl` ثبت می‌شود. `last_sync_at` و سوییچ همگام‌سازی خودکار در SharedPreferences؛ همگام‌سازی خودکار با برگشت اینترنت (connectivity_plus)؛ بررسی خالی‌بودن گوشی و وجود داده در ابر برای پیشنهاد بازیابی.
- [x] **رابط تنظیمات** (`lib/presentation/screens/settings/sync_section.dart`): وضعیت اتصال، آخرین همگام‌سازی (تاریخ فارسی)، سوییچ خودکار، «پشتیبان‌گیری الان» (با نوار پیشرفت)، «بازیابی» (با دیالوگ تأیید و توضیح قانون تعارض)، «خروجی PDF» و «خروجی JSON».
- [x] **خروجی PDF/JSON** (`lib/data/export/export_service.dart`): PDF راست‌به‌چپ با فونت وزیرمتن (دانلود اولین‌بار با اینترنت، بعد در حافظهٔ نهان؛ بدون اینترنت پیام فارسی صادقانه)، شامل مشق‌ها + «قواعد من» + واژگان؛ JSON کامل؛ اشتراک‌گذاری با شیت سیستم (share_plus).
- [x] **بازیابی در گوشی جدید**: بعد از ورود موفق، اگر ابر داده دارد و گوشی خالی است، دیالوگ «بازیابی از ابر» پیشنهاد می‌شود (`SyncRestorePrompt` در `login_screen.dart`).
- [x] **بازیابی رمز با ایمیل**: صفحهٔ فراموشی رمز حالا وقتی Firebase پیکربندی شده باشد ایمیل واقعی می‌فرستد (`AuthState.requestPasswordReset`)؛ وگرنه همان پیام صادقانهٔ قبلی.
- [x] **راهنمای کامل Firebase** (`docs/firebase-setup-fa.md`): ساخت پروژه، ثبت اپ اندروید، اثر انگشت SHA، `google-services.json`، تنظیم Gradle، فعال‌سازی Auth/Firestore/Storage با قوانین امنیتی، عیب‌یابی.
- [x] **پکیج‌های جدید** (`pubspec.yaml`): `firebase_core ^5.0.0`، `firebase_auth ^7.0.0`، `cloud_firestore ^7.0.0`، `firebase_storage ^14.0.0`، `connectivity_plus ^7.3.2`، `pdf ^3.13.1`، `share_plus ^13.3.1` — همه با نسخهٔ واقعی از pub.dev.

> نکتهٔ صادقانه: دیتابیس محلی (SQLite) همیشه مرجع اصلی است و همه‌چیز آفلاین کار می‌کند؛ ابر فقط نسخهٔ پشتیبان است. کامپایل واقعی با GitHub Actions (`flutter analyze`) چک می‌شود.

فایل‌های مرتبط: `lib/data/sync/firebase_service.dart` · `lib/data/sync/sync_engine.dart` · `lib/data/export/export_service.dart` · `lib/presentation/screens/settings/sync_section.dart` · `docs/firebase-setup-fa.md`
