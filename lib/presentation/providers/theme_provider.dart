import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// نگه‌دارنده‌ی حالت تم (روشن / تیره / سیستمی).
/// انتخاب کاربر در SharedPreferences با کلید 'theme_mode' ذخیره می‌شود.
class ThemeProvider extends ChangeNotifier {
  /// حالت پیش‌فرض: دنبال‌کردن تنظیم سیستم
  ThemeMode mode = ThemeMode.system;

  static const _key = 'theme_mode';

  ThemeProvider() {
    _load();
  }

  /// خواندن انتخاب قبلی کاربر از حافظه
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key);
    mode = switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    notifyListeners();
  }

  /// تغییر حالت تم؛ مقدار باید یکی از 'system' | 'light' | 'dark' باشد
  Future<void> setMode(String value) async {
    mode = switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, value);
    notifyListeners();
  }
}
