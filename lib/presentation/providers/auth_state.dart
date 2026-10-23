// lib/presentation/providers/auth_state.dart
//
// وضعیت احراز هویت در لایهٔ ارائه.
// بین [AuthRepository] و ویجت‌ها می‌نشیند و تغییرات حساب فعال را
// از طریق جریان مخزن دنبال می‌کند.

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:english_teacher/domain/models/account.dart';
import 'package:english_teacher/domain/repositories/auth_repository.dart';
import 'package:english_teacher/data/sync/firebase_service.dart';

/// نگه‌دارندهٔ وضعیت حساب‌ها برای رابط کاربری.
///
/// - در ساخت، روی [AuthRepository.currentAccountStream] مشترک می‌شود
/// - خطاهای [AuthException] را به صورت پیام فارسی در [error] نگه می‌دارد
class AuthState extends ChangeNotifier {
  final AuthRepository _repo;
  StreamSubscription<Account?>? _sub;

  /// حساب فعال فعلی؛ `null` یعنی کسی وارد نشده است
  Account? currentAccount;

  /// فهرست همهٔ حساب‌های حذف‌نشده
  List<Account> accounts = [];

  /// در حال بارگذاری اولیه است؟
  bool isLoading = true;

  /// آخرین پیام خطای فارسی برای نمایش؛ با [clearError] پاک می‌شود
  String? error;

  AuthState(this._repo) {
    init();
  }

  /// اشتراک روی جریان حساب فعال + بارگذاری اولیهٔ فهرست
  ///
  /// ضدگیر: هر خطا یا هنگ در خواندن دیتابیس/تنظیمات نباید اپ را روی
  /// صفحهٔ لودینگ نگه دارد؛ در هر حالت [isLoading] خاموش می‌شود تا
  /// کاربر دست‌کم به صفحهٔ ورود برسد.
  Future<void> init() async {
    try {
      _sub = _repo.currentAccountStream().listen((account) {
        currentAccount = account;
        notifyListeners();
      });
      await refreshAccounts().timeout(const Duration(seconds: 10));
      currentAccount ??=
          await _repo.currentAccount().timeout(const Duration(seconds: 10));
    } catch (_) {
      // دیتابیس/تنظیمات در دسترس نیست — ورود به‌صورت مهمانِ واردنشده
      accounts = [];
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// تازه‌سازی فهرست حساب‌ها از مخزن
  Future<void> refreshAccounts() async {
    try {
      accounts = await _repo.listAccounts();
    } catch (_) {
      accounts = [];
    }
    notifyListeners();
  }

  /// ثبت‌نام؛ در صورت موفقیت `true` و در صورت خطا `false`
  /// (پیام خطا در [error] قرار می‌گیرد)
  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final account =
          await _repo.signUp(name: name, email: email, password: password);
      currentAccount = account;
      await refreshAccounts();
      error = null;
      return true;
    } on AuthException catch (e) {
      error = e.message;
      notifyListeners();
      return false;
    }
  }

  /// ورود؛ در صورت موفقیت `true` و در صورت خطا `false`
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final account = await _repo.signIn(email: email, password: password);
      currentAccount = account;
      await refreshAccounts();
      error = null;
      return true;
    } on AuthException catch (e) {
      error = e.message;
      notifyListeners();
      return false;
    }
  }

  /// خروج از حساب فعال (حساب‌ها حفظ می‌شوند)
  Future<void> signOut() async {
    await _repo.signOut();
    currentAccount = null;
    await refreshAccounts();
  }

  /// جابه‌جایی به حساب دیگر؛ موفق/ناموفق بودن را برمی‌گرداند
  Future<bool> switchAccount(String accountId) async {
    try {
      currentAccount = await _repo.switchAccount(accountId);
      await refreshAccounts();
      error = null;
      return true;
    } on AuthException catch (e) {
      error = e.message;
      notifyListeners();
      return false;
    }
  }

  /// حذف حساب (نرم) به‌همراه داده‌هایش
  Future<void> deleteAccount(String accountId) async {
    await _repo.deleteAccount(accountId);
    currentAccount = await _repo.currentAccount();
    await refreshAccounts();
  }

  /// درخواست بازیابی رمز عبور.
  ///
  /// مرحلهٔ ۷: اگر Firebase پیکربندی شده باشد، ایمیل واقعی ارسال
  /// می‌شود؛ وگرنه همان پیام صادقانهٔ قبلی نمایش داده می‌شود.
  Future<bool> requestPasswordReset(String email) async {
    try {
      if (FirebaseService.instance.isConfigured) {
        await FirebaseService.instance
            .sendPasswordResetEmail(email.trim());
        error = null;
        return true;
      }
      await _repo.requestPasswordReset(email);
      error = null;
      return true;
    } on AuthException catch (e) {
      error = e.message;
      notifyListeners();
      return false;
    } on FirebaseNotConfiguredException catch (e) {
      error = e.message;
      notifyListeners();
      return false;
    }
  }

  /// پاک‌کردن پیام خطا پس از نمایش
  void clearError() {
    error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
