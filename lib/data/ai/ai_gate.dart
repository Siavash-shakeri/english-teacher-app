// lib/data/ai/ai_gate.dart
//
// دروازهٔ دسترسی به Gemini: اگر کلید ذخیره شده باشد، یک [GeminiClient]
// آماده با مدل انتخاب‌شده برمی‌گرداند؛ در غیر این صورت null.
// UIها با null همان رفتار صادقانهٔ «کلید وارد نشده» را نشان می‌دهند.

import 'package:shared_preferences/shared_preferences.dart';

import 'package:english_teacher/data/ai/gemini_client.dart';
import 'package:english_teacher/data/ai/secure_key_store.dart';

/// دروازهٔ ساخت کلاینت Gemini از روی کلید ذخیره‌شده.
class AiGate {
  static const String modelPrefKey = 'gemini_model';

  /// کش همگامِ «کلید وجود دارد؟» برای موتورهایی که isAvailable همگام دارند.
  /// با [refreshKeyPresence] تازه می‌شود (در main و بعد از ذخیره/حذف کلید).
  static bool _keyCached = false;
  static bool get hasKeyCached => _keyCached;

  /// تازه‌سازی کش حضور کلید.
  static Future<void> refreshKeyPresence() async {
    try {
      _keyCached = await SecureKeyStore().hasKey();
    } catch (_) {
      _keyCached = false;
    }
  }

  /// کلاینت آماده یا null (کلید وارد نشده).
  static Future<GeminiClient?> client() async {
    final key = await SecureKeyStore().readKey();
    if (key == null || key.trim().isEmpty) {
      _keyCached = false;
      return null;
    }
    _keyCached = true;
    final prefs = await SharedPreferences.getInstance();
    final model =
        prefs.getString(modelPrefKey) ?? GeminiClient.flashModels.first;
    return GeminiClient(apiKey: key, model: model);
  }

  /// خواندن مدل انتخاب‌شده (برای نمایش در تنظیمات).
  static Future<String> currentModel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(modelPrefKey) ?? GeminiClient.flashModels.first;
  }

  /// ذخیرهٔ مدل انتخاب‌شده.
  static Future<void> setModel(String model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(modelPrefKey, model);
  }
}
