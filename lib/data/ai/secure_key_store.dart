// lib/data/ai/secure_key_store.dart
//
// ذخیره‌سازی رمزنگاری‌شدهٔ کلید Google AI Studio.
// از flutter_secure_storage استفاده می‌شود (Android: Keystore + AES-GCM).
// کلید در سطح دستگاه نگه‌داری می‌شود (تک‌کلیدی) ولی تاریخچهٔ گفت‌وگو
// جداگانه برای هر حساب ذخیره می‌شود. کلید خام هیچ‌وقت در UI نمایش
// داده نمی‌شود — فقط نسخهٔ ماسک‌شده (مثل «AIza•••x9Q2»).

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// مخزن امن کلید Gemini.
class SecureKeyStore {
  static const String _keyName = 'gemini_api_key';

  final FlutterSecureStorage _storage;

  SecureKeyStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(),
            );

  /// خواندن کلید؛ null یعنی کاربر هنوز کلیدی وارد نکرده است.
  Future<String?> readKey() => _storage.read(key: _keyName);

  /// ذخیرهٔ کلید (رمزنگاری‌شده در سطح سیستم‌عامل).
  Future<void> saveKey(String key) =>
      _storage.write(key: _keyName, value: key.trim());

  /// حذف کلید.
  Future<void> deleteKey() => _storage.delete(key: _keyName);

  /// آیا کلیدی ذخیره شده است؟
  Future<bool> hasKey() => _storage.containsKey(key: _keyName);

  /// نسخهٔ ماسک‌شده برای نمایش در تنظیمات — کلید خام برنمی‌گردد.
  static String mask(String key) {
    final k = key.trim();
    if (k.length <= 8) return '••••';
    return '${k.substring(0, 4)}•••${k.substring(k.length - 4)}';
  }
}
