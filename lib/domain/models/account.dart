// lib/domain/models/account.dart
//
// مدل دامنهٔ «حساب کاربری».
// این کلاس فقط دادهٔ خواندنی حساب را نگه می‌دارد؛ هیچ رمز یا هش رمزی در آن نیست.

/// نمایندهٔ یک حساب کاربری در لایهٔ دامنه.
///
/// ستون‌های جدول `accounts` را می‌خواند؛ زمان‌ها به صورت
/// epoch-milliseconds ذخیره شده‌اند و اینجا به [DateTime] تبدیل می‌شوند.
class Account {
  /// شناسهٔ یکتای حساب (UUID نسخهٔ ۴)
  final String id;

  /// ایمیل حساب — همیشه با حروف کوچک ذخیره و خوانده می‌شود
  final String email;

  /// نام نمایشی صاحب حساب
  final String name;

  /// زمان ساخت حساب
  final DateTime createdAt;

  /// آخرین زمان ورود موفق (ممکن است هنوز وارد نشده باشد)
  final DateTime? lastLoginAt;

  const Account({
    required this.id,
    required this.email,
    required this.name,
    required this.createdAt,
    this.lastLoginAt,
  });

  /// ساخت از یک ردیف جدول `accounts`.
  ///
  /// مقادیر مورد انتظار:
  /// - `id`, `email`, `name`: رشته
  /// - `created_at`: عدد صحیح (epoch ms)
  /// - `last_login_at`: عدد صحیح یا null
  factory Account.fromMap(Map<String, Object?> m) {
    final lastLoginRaw = m['last_login_at'];
    return Account(
      id: m['id'] as String,
      email: m['email'] as String,
      name: m['name'] as String,
      createdAt:
          DateTime.fromMillisecondsSinceEpoch((m['created_at'] as num).toInt()),
      lastLoginAt: lastLoginRaw == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              (lastLoginRaw as num).toInt()),
    );
  }

  @override
  String toString() => 'Account(id: $id, email: $email, name: $name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Account &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
