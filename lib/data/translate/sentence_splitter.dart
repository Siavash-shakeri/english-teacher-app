// lib/data/translate/sentence_splitter.dart
//
// جدا کردن متن انگلیسی به جمله‌ها (مرحلهٔ ۳ — ترجمه).
// جمله‌ها برای ترجمهٔ جداگانه و نمایش ترجمهٔ زیر هر جمله لازم‌اند.

/// جداکنندهٔ متن انگلیسی به جمله بر اساس علائم نگارشی.
///
/// هر جمله با همان جداکنندهٔ پایانی (`.` / `!` / `؟`) نگه داشته می‌شود،
/// فاصله‌های اضافی حذف و جمله‌های خالی کنار گذاشته می‌شوند.
///
/// محدودیت‌های آگاهانه (قابل قبول برای متن تکلیف دست‌نویس):
/// - اختصارهایی مثل "Mr." یا "e.g." به اشتباه جمله شکسته می‌شوند؛
/// - اعداد اعشاری مثل "3.14" نیز دو جملهٔ جدا به شمار می‌روند؛
/// - علامت‌های نگارشی داخل گیومه به صورت جداگانه پردازش می‌شوند.
///
/// اگر دقت بالاتری لازم شد، جایگزینی با شناسایی موجودیت زبانی
/// (مثلاً google_mlkit_language_id + منطق سفارشی) پیشنهاد می‌شود.
class SentenceSplitter {
  /// یک یا چند کاراکتر غیرنگارشی به‌همراه جداکنندهٔ پایانی‌شان.
  static final RegExp _sentencePattern = RegExp(r'[^.!?]+[.!?]+');

  /// متن ورودی را به فهرستی از جمله‌ها تبدیل می‌کند.
  ///
  /// اگر متن هیچ جداکننده‌ای نداشته باشد، کل متنِ تمیز شده به عنوان
  /// یک جمله برمی‌گردد؛ برای ورودی خالی، فهرست خالی برمی‌گردد.
  static List<String> split(String text) {
    final sentences = <String>[];
    var lastEnd = 0;
    for (final match in _sentencePattern.allMatches(text)) {
      final sentence = match.group(0)!.trim();
      if (sentence.isNotEmpty) sentences.add(sentence);
      lastEnd = match.end;
    }
    // بخش پایانی متن که جداکنندهٔ نگارشی ندارد
    final tail = text.substring(lastEnd).trim();
    if (tail.isNotEmpty) sentences.add(tail);
    return sentences;
  }
}
