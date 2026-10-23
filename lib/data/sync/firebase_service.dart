// lib/data/sync/firebase_service.dart
//
// لایهٔ اتصال به Firebase برای مرحلهٔ ۷ (همگام‌سازی ابری).
//
// اصل صداقت: اگر Firebase پیکربندی نشده باشد (google-services.json
// در پروژه نیست یا initializeApp شکست خورده)، همهٔ متدها به‌جای
// رفتار جعلی، خطای فارسی «Firebase هنوز پیکربندی نشده» می‌دهند و
// [isConfigured] نادرست است. رابط کاربری همین وضعیت را نشان می‌دهد.
//
// هیچ کلید، توکن یا رمزی در کد نگه‌داری نمی‌شود؛ پیکربندی فقط از
// فایل google-services.json (طبق راهنمای docs/firebase-setup-fa.md)
// خوانده می‌شود.

import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// خطای فارسی قابل نمایش برای مشکلات Firebase.
class FirebaseNotConfiguredException implements Exception {
  final String message;
  const FirebaseNotConfiguredException([this.message = _defaultMessage]);

  static const String _defaultMessage =
      'Firebase هنوز پیکربندی نشده است. راهنمای docs/firebase-setup-fa.md را ببینید.';

  @override
  String toString() => message;
}

/// سرویس تکی اتصال به Firebase.
class FirebaseService {
  FirebaseService._();

  static final FirebaseService instance = FirebaseService._();

  bool _configured = false;

  /// آیا Firebase با موفقیت مقداردهی اولیه شده است؟
  bool get isConfigured => _configured;

  final FlutterSecureStorage _secure = const FlutterSecureStorage();

  /// تلاش برای مقداردهی اولیه؛ شکست = حالت «پیکربندی‌نشده»، بدون کرش.
  ///
  /// باید بعد از WidgetsFlutterBinding.ensureInitialized صدا زده شود.
  Future<void> initialize() async {
    try {
      // Timeout: اگر google-services.json نباشد، initializeApp ممکن است هنگ کند.
      // با تایم‌اوت ۵ ثانیه‌ای، اپ آفلاین ادامه می‌دهد.
      await Firebase.initializeApp().timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw const FirebaseNotConfiguredException(),
      );
      _configured = true;
    } catch (_) {
      // google-services.json نیست یا Firebase در دسترس نیست —
      // اپ کاملاً آفلاین کار می‌کند.
      _configured = false;
    }
  }

  void _requireConfigured() {
    if (!_configured) throw const FirebaseNotConfiguredException();
  }

  FirebaseFirestore get firestore {
    _requireConfigured();
    return FirebaseFirestore.instance;
  }

  FirebaseStorage get storage {
    _requireConfigured();
    return FirebaseStorage.instance;
  }

  /// شناسهٔ کاربر فعلی Firebase (در صورت ورود).
  String? get uid {
    if (!_configured) return null;
    return FirebaseAuth.instance.currentUser?.uid;
  }

  /// تضمین وجود کاربر Firebase برای ایمیل حساب محلی.
  ///
  /// چون رمز محلی فقط به‌صورت هش نگه‌داری می‌شود، برای Firebase یک
  /// رمز تصادفی قوی ساخته و در حافظهٔ رمزنگاری‌شدهٔ دستگاه نگه می‌داریم.
  /// خروجی: uid کاربر Firebase.
  Future<String> ensureFirebaseUser(String email) async {
    _requireConfigured();
    final auth = FirebaseAuth.instance;
    if (auth.currentUser != null) return auth.currentUser!.uid;

    final key = 'firebase_pw_${email.toLowerCase()}';
    var password = await _secure.read(key: key);
    if (password == null) {
      password = _randomPassword();
      await _secure.write(key: key, value: password);
    }
    try {
      final cred = await auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return cred.user!.uid;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        final cred = await auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        return cred.user!.uid;
      }
      rethrow;
    }
  }

  /// ارسال ایمیل بازیابی رمز (مرحلهٔ ۱ این را استاب کرده بود).
  Future<void> sendPasswordResetEmail(String email) async {
    _requireConfigured();
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw FirebaseNotConfiguredException(_persianAuthError(e.code));
    }
  }

  /// خروج از حساب Firebase.
  Future<void> signOut() async {
    if (!_configured) return;
    await FirebaseAuth.instance.signOut();
  }

  String _randomPassword() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#';
    final rnd = Random.secure();
    return List.generate(32, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  String _persianAuthError(String code) {
    switch (code) {
      case 'user-not-found':
      case 'invalid-email':
        return 'این ایمیل در Firebase ثبت نشده است.';
      case 'too-many-requests':
        return 'درخواست‌های زیاد؛ کمی بعد دوباره تلاش کنید.';
      case 'network-request-failed':
        return 'به اینترنت وصل نیستید.';
      default:
        return 'خطای Firebase ($code)؛ دوباره تلاش کنید.';
    }
  }
}
