// lib/presentation/widgets/fa_digits.dart
//
// ابزارهای کوچک نمایش تاریخ و ارقام فارسی.
//
// صفحات مرحله‌های ۲ و ۳ همین توابع را به صورت محلی (private) کپی کرده‌اند؛
// فایل‌های آن‌ها دست‌نخورده باقی مانده‌اند. صفحات مرحلهٔ ۴ از همین
// ویجت مشترک استفاده می‌کنند.

/// تبدیل ارقام لاتین یک رشته به ارقام فارسی.
String toFaDigits(String input) {
  const digits = '۰۱۲۳۴۵۶۷۸۹';
  return input.replaceAllMapped(
    RegExp(r'[0-9]'),
    (match) => digits[int.parse(match.group(0)!)],
  );
}

/// نمایش کوتاه تاریخ و ساعت (میلادی) با ارقام فارسی.
/// تبدیل شمسی فعلاً پیاده‌سازی نشده (مثل صفحه‌های قبلی).
String faDateTime(DateTime dt) {
  return '${toFaDigits('${dt.year}')}/${toFaDigits('${dt.month}')}/'
      '${toFaDigits('${dt.day}')}  ${toFaDigits('${dt.hour}')}:'
      '${toFaDigits('${dt.minute}')}';
}

/// نمایش کوتاه فقط تاریخ (میلادی) با ارقام فارسی.
String faDate(DateTime dt) {
  return '${toFaDigits('${dt.year}')}/${toFaDigits('${dt.month}')}/'
      '${toFaDigits('${dt.day}')}';
}
