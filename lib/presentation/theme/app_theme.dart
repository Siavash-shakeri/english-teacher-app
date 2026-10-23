import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// تم‌های روشن و تیره اپ (Material 3 با فونت وزیرمتن).
class AppTheme {
  AppTheme._();

  static const _seedColor = Colors.teal;

  /// طرح رنگ روشن — ساخته‌شده از یک رنگ پایه (teal)
  static final ColorScheme _lightScheme =
      ColorScheme.fromSeed(seedColor: _seedColor);

  /// طرح رنگ تیره — همان رنگ پایه ولی با روشنایی تیره
  static final ColorScheme _darkScheme = ColorScheme.fromSeed(
    seedColor: _seedColor,
    brightness: Brightness.dark,
  );

  /// تم متنی با فونت وزیرمتن
  static TextTheme _vazir(TextTheme base) =>
      GoogleFonts.vazirmatnTextTheme(base);

  /// حاشیه‌ی گرد مشترک برای فیلدهای متنی
  static InputDecorationTheme _inputTheme(ColorScheme scheme) =>
      InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: _lightScheme,
    textTheme: _vazir(ThemeData.light().textTheme),
    // عنوان اپ‌بار همیشه وسط‌چین (مناسب راست‌به‌چپ)
    appBarTheme: const AppBarTheme(centerTitle: true),
    inputDecorationTheme: _inputTheme(_lightScheme),
  );

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: _darkScheme,
    textTheme: _vazir(ThemeData.dark().textTheme),
    appBarTheme: const AppBarTheme(centerTitle: true),
    inputDecorationTheme: _inputTheme(_darkScheme),
  );
}
