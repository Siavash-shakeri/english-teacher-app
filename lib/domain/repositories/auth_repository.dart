// lib/domain/repositories/auth_repository.dart
//
// قرارداد لایهٔ دامنه برای احراز هویت و مدیریت حساب‌های محلی.
// همهٔ خطاها به صورت فارسی و از نوع [AuthException] گزارش می‌شوند.

import 'package:english_teacher/domain/models/account.dart';

/// خطای احراز هویت با پیام فارسی آمادهٔ نمایش به کاربر.
class AuthException implements Exception {
  /// پیام فارسی خطا
  final String message;

  const AuthException(this.message);

  @override
  String toString() => message;
}

/// قرارداد مخزن احراز هویت.
///
/// پیاده‌سازی‌ها (مثلاً نسخهٔ محلی SQLite یا نسخهٔ ابری در مرحلهٔ ۷)
/// باید همین رابط را رعایت کنند تا لایهٔ ارائه بی‌تغییر بماند.
abstract class AuthRepository {
  /// جریان حساب فعال؛ هر بار که حساب فعال عوض/ساخته/حذف شود
  /// مقدار تازه منتشر می‌شود (`null` یعنی هیچ حسابی فعال نیست).
  Stream<Account?> currentAccountStream();

  /// حساب فعال فعلی، یا `null` اگر کسی وارد نشده است.
  Future<Account?> currentAccount();

  /// همهٔ حساب‌های حذف‌نشده، مرتب بر اساس آخرین ورود (جدیدترین اول).
  Future<List<Account>> listAccounts();

  /// ساخت حساب جدید و فعال‌کردن آن.
  ///
  /// خطاهای فارسی: ایمیل نامعتبر، رمز کوتاه، نام خالی، ایمیل تکراری.
  Future<Account> signUp({
    required String name,
    required String email,
    required String password,
  });

  /// ورود با ایمیل و رمز.
  ///
  /// در صورت اشتباه بودن ایمیل یا رمز:
  /// [AuthException] با پیام «ایمیل یا رمز عبور اشتباه است».
  Future<Account> signIn({
    required String email,
    required String password,
  });

  /// خروج از حساب فعال؛ خود حساب‌ها باقی می‌مانند.
  Future<void> signOut();

  /// فعال‌کردن یک حساب موجود دیگر.
  Future<Account> switchAccount(String accountId);

  /// حذف نرم حساب (علامت‌گذاری) به‌همراه پاک‌سازی داده‌هایش.
  Future<void> deleteAccount(String accountId);

  /// درخواست بازیابی رمز عبور.
  ///
  /// فعلاً سرویس ایمیل نداریم؛ پیاده‌سازی محلی باید با [AuthException]
  /// اعلام کند که این قابلیت در مرحلهٔ ۷ (همگام‌سازی ابری) فعال می‌شود.
  Future<void> requestPasswordReset(String email);
}
