// lib/data/translate/translate_service.dart
//
// قرارداد موتورهای ترجمهٔ انگلیسی به فارسی (مرحلهٔ ۳ — ترجمه).
//
// در مرحلهٔ ۳، موتور آفلاین ML Kit پیاده‌سازی شده است؛
// این فایل الگوی `ocr_service.dart` (مرحلهٔ ۲) را دنبال می‌کند:
// موتور Gemini در مرحلهٔ ۵ (معلم هوش مصنوعی) سیم‌کشی می‌شود.

import 'package:google_mlkit_translation/google_mlkit_translation.dart';

import 'package:english_teacher/data/ai/ai_gate.dart';

/// رابط مشترک موتورهای ترجمه (انگلیسی به فارسی).
///
/// قرارداد: هر موتور واقعی باید ترجمهٔ واقعی برگرداند؛
/// برگرداندن ترجمهٔ جعلی/ساختگی ممنوع است.
abstract class TranslateEngine {
  /// شناسهٔ یکتای موتور: 'mlkit' یا 'gemini'
  String get engineId;

  /// نام نمایشی فارسی برای نمایش در رابط کاربری
  String get displayName;

  /// آیا موتور در حال حاضر قابل استفاده است؟
  bool get isAvailable;

  /// دلیل فارسی در دسترس نبودن؛ فقط وقتی معنا دارد که [isAvailable] نادرست باشد
  String get unavailableReason;

  /// ترجمهٔ متن انگلیسی به فارسی.
  /// ورودی خالی/فاصله فقط، بدون فراخوانی موتور، رشتهٔ خالی برمی‌گرداند.
  /// در صورت ناموفق بودن، خطا (با پیام فارسی) پرتاب می‌کند.
  Future<String> translate(String text);

  /// آزادسازی منابع موتور (در صورت نیاز)
  Future<void> close();
}

/// موتور ترجمهٔ آفلاین مبتنی بر ML Kit گوگل.
/// روی دستگاه اجرا می‌شود و پس از دانلود مدل، به اینترنت نیاز ندارد.
class MlKitTranslateEngine implements TranslateEngine {
  @override
  String get engineId => 'mlkit';

  @override
  String get displayName => 'آفلاین (ML Kit)';

  @override
  bool get isAvailable => true;

  @override
  String get unavailableReason => '';

  // مترجم تنبل ساخته می‌شود تا تا قبل از اولین ترجمه، منبعی اشغال نشود
  OnDeviceTranslator? _translator;

  // نگه‌داشتن دانلودِ در حال انجام تا فراخوانی‌های همزمان ترجمه،
  // دانلود مدل را چند بار تکرار نکنند
  Future<void>? _downloadInFlight;

  /// آیا مدل‌های موردنیاز (انگلیسی و فارسی) دانلود شده‌اند؟
  ///
  /// ترجمهٔ انگلیسی به فارسی به هر دو مدل نیاز دارد.
  /// این گتر فقط «وضعیت» را می‌سنجد و هیچ‌چیز دانلود نمی‌کند؛
  /// دانلود واقعی داخل [translate] انجام می‌شود.
  Future<bool> get isModelDownloaded async {
    final manager = OnDeviceTranslatorModelManager();
    for (final language
        in const [TranslateLanguage.english, TranslateLanguage.persian]) {
      if (!await manager.isModelDownloaded(language.bcpCode)) return false;
    }
    return true;
  }

  OnDeviceTranslator get _ensureTranslator {
    return _translator ??= OnDeviceTranslator(
      sourceLanguage: TranslateLanguage.english,
      targetLanguage: TranslateLanguage.persian,
    );
  }

  /// اطمینان از دانلود هر دو مدل انگلیسی و فارسی پیش از ترجمه.
  Future<void> _ensureModelsDownloaded() async {
    final inFlight = _downloadInFlight;
    if (inFlight != null) {
      await inFlight;
      return;
    }
    final future = _downloadMissingModels();
    _downloadInFlight = future;
    try {
      await future;
    } finally {
      _downloadInFlight = null;
    }
  }

  Future<void> _downloadMissingModels() async {
    final manager = OnDeviceTranslatorModelManager();
    for (final language
        in const [TranslateLanguage.english, TranslateLanguage.persian]) {
      final code = language.bcpCode;
      try {
        if (await manager.isModelDownloaded(code)) continue;
        // دانلود مدل نیازمند اینترنت است؛ با توجه به الگوی مستندات پکیج،
        // مقدار بازگشتی بولی نشان‌دهندهٔ موفقیت دانلود است
        final ok = await manager.downloadModel(code);
        if (!ok) {
          throw Exception('دانلود مدل زبان $code ناموفق بود');
        }
      } catch (e) {
        throw Exception('دانلود مدل ترجمه ($code) ناموفق بود: $e');
      }
    }
  }

  @override
  Future<String> translate(String text) async {
    if (text.trim().isEmpty) return '';
    await _ensureModelsDownloaded();
    try {
      return await _ensureTranslator.translateText(text);
    } catch (e) {
      throw Exception('ترجمهٔ متن ناموفق بود: $e');
    }
  }

  @override
  Future<void> close() async {
    final translator = _translator;
    _translator = null;
    if (translator != null) {
      // با Future.sync بسته می‌شود تا چه close() هم‌زمان (void) و چه ناهمزمان
      // (Future) باشد، بدون خطا آزاد شود
      await Future.sync(translator.close);
    }
  }
}

/// موتور ترجمهٔ آنلاین مبتنی بر Gemini (مرحلهٔ ۵).
///
/// قرارداد صداقت: این موتور هرگز ترجمهٔ جعلی برنمی‌گرداند.
/// [isAvailable] فقط وقتی درست است که کلید Gemini در تنظیمات ذخیره شده باشد؛
/// در غیر این صورت [translate] خطای فارسی پرتاب می‌کند.
class GeminiTranslateEngine implements TranslateEngine {
  @override
  String get engineId => 'gemini';

  @override
  String get displayName => 'آنلاین (Gemini)';

  @override
  bool get isAvailable => AiGate.hasKeyCached;

  @override
  String get unavailableReason =>
      'برای ترجمهٔ آنلاین، کلید Google AI Studio را در تنظیمات وارد کن';

  @override
  Future<String> translate(String text) async {
    final client = await AiGate.client();
    if (client == null) throw UnsupportedError(unavailableReason);
    try {
      final result = await client.generateContent(
        systemPrompt:
            'تو یک مترجم دقیق انگلیسی به فارسی هستی. فقط ترجمهٔ فارسی روان '
            'و طبیعی جمله را برگردان؛ هیچ توضیح اضافه‌ای نده.',
        userMessage: text,
      );
      return result.trim();
    } finally {
      client.close();
    }
  }

  @override
  Future<void> close() async {}
}
