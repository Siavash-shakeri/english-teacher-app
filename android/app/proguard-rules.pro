# قوانین نگه‌داری (ProGuard) برای بیلد انتشار

# sqflite — کانال‌های متد بومی نباید حذف/تغییرنام شوند
-keep class com.tekartik.sqflite.** { *; }

# cryptography — پیاده‌سازی‌های بومی/چارچوبی حفظ شوند
-keep class com.iwebpp.crypto.** { *; }
-keep class com.github.** { *; }

# فلاتر — پلاگین‌ها از طریق رفلکشن ثبت می‌شوند
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }

# قوانین خودکار R8 برای کلاس‌های اختیاری (Play Core / ML Kit) — missing_rules.txt
-dontwarn com.google.android.play.core.**
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
