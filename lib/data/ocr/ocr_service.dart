import 'dart:convert';
import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'package:english_teacher/data/ai/ai_gate.dart';
import 'package:english_teacher/data/ai/gemini_client.dart';

/// رابط مشترک موتورهای OCR.
/// در مرحلهٔ ۲، موتور ML Kit (آفلاین) پیاده‌سازی شده است؛
/// پیاده‌سازی واقعی موتور Gemini Vision در مرحلهٔ ۵ (معلم هوش مصنوعی) اضافه می‌شود.
abstract class OcrEngine {
  /// شناسهٔ یکتای موتور: 'mlkit' یا 'gemini'
  String get engineId;

  /// نام نمایشی فارسی برای نمایش در رابط کاربری
  String get displayName;

  /// آیا موتور در حال حاضر قابل استفاده است؟
  bool get isAvailable;

  /// دلیل فارسی در دسترس نبودن؛ فقط وقتی معنا دارد که [isAvailable] نادرست باشد
  String get unavailableReason;

  /// استخراج متن انگلیسی از تصویرِ مسیر داده‌شده.
  /// در صورت ناموفق بودن، خطا پرتاب می‌کند.
  Future<String> recognizeText(String imagePath);
}

/// موتور OCR آفلاین مبتنی بر ML Kit گوگل.
/// روی دستگاه اجرا می‌شود و به اینترنت نیاز ندارد.
class MlKitOcrEngine implements OcrEngine {
  @override
  String get engineId => 'mlkit';

  @override
  String get displayName => 'آفلاین (ML Kit)';

  @override
  bool get isAvailable => true;

  @override
  String get unavailableReason => '';

  @override
  Future<String> recognizeText(String imagePath) async {
    // اسکریپت لاتین برای تشخیص حروف انگلیسی؛
    // برای بهبود تشخیص، تصویر باید از قبل تمیز شده باشد (ImageCleanup).
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final input = InputImage.fromFilePath(imagePath);
      final result = await recognizer.processImage(input);
      return result.text.trim();
    } finally {
      // بستن موتور برای آزادسازی حافظهٔ بومی (native)
      await recognizer.close();
    }
  }
}

/// موتور OCR آنلاین مبتنی بر Gemini Vision (مرحلهٔ ۵).
///
/// قرارداد صداقت: این موتور هرگز نتیجهٔ جعلی برنمی‌گرداند.
/// [isAvailable] فقط وقتی درست است که کلید Gemini در تنظیمات ذخیره شده باشد
/// (کش [AiGate.hasKeyCached])؛ در غیر این صورت [recognizeText] خطای فارسی
/// پرتاب می‌کند.
class GeminiVisionOcrEngine implements OcrEngine {
  @override
  String get engineId => 'gemini';

  @override
  String get displayName => 'آنلاین (Gemini Vision)';

  @override
  bool get isAvailable => AiGate.hasKeyCached;

  @override
  String get unavailableReason =>
      'برای استفاده از Gemini Vision، کلید Google AI Studio را در تنظیمات وارد کن';

  @override
  Future<String> recognizeText(String imagePath) async {
    final client = await AiGate.client();
    if (client == null) throw UnsupportedError(unavailableReason);
    try {
      final bytes = await File(imagePath).readAsBytes();
      final mime = imagePath.toLowerCase().endsWith('.png')
          ? 'image/png'
          : 'image/jpeg';
      final text = await client.generateContentWithImage(
        prompt: 'تو یک OCR دقیق هستی. فقط متن دست‌نویس تصویر را به انگلیسی '
            'تایپ کن؛ هیچ توضیح اضافه‌ای نده. اگر متنی نمی‌بینی، خالی برگردان.',
        imageBase64: base64Encode(bytes),
        mimeType: mime,
      );
      return text.trim();
    } on GeminiException {
      rethrow;
    } finally {
      client.close();
    }
  }
}
