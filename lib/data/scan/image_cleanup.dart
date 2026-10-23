import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

/// تمیزکاری حداقلی و بهترین‌تلاش برای عکس‌های مشق دست‌نویس.
///
/// محدودیت صادقانه: اصلاح واقعی پرسپکتیو چهارنقطه‌ای (perspective warp)
/// پیاده‌سازی نشده است؛ کادربندی تصویر با رابط کاربری crop انجام می‌شود.
/// این تابع فقط این کارها را می‌کند:
/// ۱. کوچک‌نمایی تا حداکثر عرض ۱۶۰۰ پیکسل (کاهش مصرف حافظه و زمان OCR)
/// ۲. خاکستری کردن (grayscale) برای کاهش نویز رنگ
/// ۳. افزایش کنتراست (contrast stretch) برای مقابله با سایه و نور ناهموار
///
/// خروجی: مسیر فایل جدید با پسوند ‎`_clean.jpg` در همان پوشهٔ تصویر اصلی.
/// در صورت هرگونه خطا، مسیر فایل اصلی برگردانده می‌شود تا جریان کار متوقف نشود.
class ImageCleanup {
  static Future<String> cleanUp(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return imageFile.path;

      var work = decoded;
      // کوچک‌نمایی فقط در صورت بزرگ بودن تصویر؛ تصویر کوچک‌تر دست‌نخورده می‌ماند
      if (work.width > 1600) {
        work = img.copyResize(work, width: 1600);
      }
      work = img.grayscale(work);
      work = img.adjustColor(work, contrast: 1.6);

      final out = img.encodeJpg(work, quality: 88);
      final dir = p.dirname(imageFile.path);
      final base = p.basenameWithoutExtension(imageFile.path);
      final outFile = File(p.join(dir, '${base}_clean.jpg'));
      await outFile.writeAsBytes(out);
      return outFile.path;
    } catch (_) {
      // در صورت هر خطا، برگرداندن تصویر اصلی بهتر از شکست کل جریان اسکن است
      return imageFile.path;
    }
  }
}
