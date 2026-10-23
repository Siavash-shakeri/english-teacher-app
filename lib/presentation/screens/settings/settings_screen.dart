// lib/presentation/screens/settings/settings_screen.dart
//
// صفحهٔ تنظیمات اپ:
// (الف) حساب کاربری — کارت حساب فعال، جابه‌جایی/خروج/حذف
// (ب) معلم هوش مصنوعی — کلید Google AI Studio و انتخاب مدل (مرحلهٔ ۵)
// (پ) ظاهر — انتخاب تم روشن/تیره/سیستمی
// (ت) پشتیبان‌گیری — فعلاً غیرفعال (مرحلهٔ ۷)
// (ث) درباره — نام اپ و نسخه

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:english_teacher/presentation/providers/auth_state.dart';
import 'package:english_teacher/presentation/providers/theme_provider.dart';
import 'package:english_teacher/presentation/screens/settings/ai_key_section.dart';
import 'package:english_teacher/presentation/screens/settings/sync_section.dart';
import 'package:english_teacher/presentation/widgets/account_switcher_sheet.dart';

/// صفحهٔ تنظیمات.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  /// دیالوگ تأیید حذف حساب فعال
  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final auth = context.read<AuthState>();
    final account = auth.currentAccount;
    if (account == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('حذف حساب'),
        content: Text(
          'حساب «${account.name}» به‌همراه همهٔ داده‌هایش برای همیشه حذف شود؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('انصراف'),
          ),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('حذف برای همیشه'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await auth.deleteAccount(account.id);
      if (context.mounted) {
        // اگر هیچ حسابی نماند، به صفحهٔ ورود برگرد
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/login',
          (_) => false,
        );
      }
    }
  }

  /// خروج از حساب فعال و رفتن به صفحهٔ ورود
  Future<void> _signOut(BuildContext context) async {
    await context.read<AuthState>().signOut();
    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/login',
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final theme = context.watch<ThemeProvider>();
    final account = auth.currentAccount;

    return Scaffold(
      appBar: AppBar(title: const Text('تنظیمات')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ───────── (الف) حساب کاربری ─────────
          Text(
            'حساب کاربری',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (account != null) ...[
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          child: Text(
                            account.name.isNotEmpty
                                ? account.name.characters.first
                                : '؟',
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                account.name,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium,
                              ),
                              Text(
                                account.email,
                                textDirection: TextDirection.ltr,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                  ],
                  // جابه‌جایی حساب
                  OutlinedButton.icon(
                    icon: const Icon(Icons.switch_account_outlined),
                    label: const Text('جابه‌جایی حساب'),
                    onPressed: () =>
                        AccountSwitcherSheet.show(context),
                  ),
                  const SizedBox(height: 8),
                  // خروج
                  OutlinedButton.icon(
                    icon: const Icon(Icons.logout_outlined),
                    label: const Text('خروج از حساب'),
                    onPressed: () => _signOut(context),
                  ),
                  const SizedBox(height: 8),
                  // حذف (خطرناک)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.delete_forever_outlined),
                    label: const Text('حذف حساب'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor:
                          Theme.of(context).colorScheme.error,
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    onPressed: () =>
                        _confirmDeleteAccount(context),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ───────── (ب) معلم هوش مصنوعی ─────────
          Text(
            'معلم هوش مصنوعی',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          const AiKeySection(),
          const SizedBox(height: 24),

          // ───────── (پ) ظاهر ─────────
          Text(
            'ظاهر',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Card(
            child: RadioGroup<ThemeMode>(
              groupValue: theme.mode,
              onChanged: (ThemeMode? v) {
                if (v != null) theme.setMode(v.name);
              },
              child: const Column(
                children: [
                  RadioListTile<ThemeMode>(
                    title: Text('روشن'),
                    value: ThemeMode.light,
                  ),
                  RadioListTile<ThemeMode>(
                    title: Text('تیره'),
                    value: ThemeMode.dark,
                  ),
                  RadioListTile<ThemeMode>(
                    title: Text('سیستم'),
                    value: ThemeMode.system,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ───────── (ت) پشتیبان‌گیری و خروجی — مرحلهٔ ۷ ─────────
          const SyncSection(),
          const SizedBox(height: 24),

          // ───────── (ث) درباره ─────────
          Text(
            'درباره',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          const Card(
            child: ListTile(
              leading: Icon(Icons.school_outlined),
              title: Text('معلم انگلیسی من'),
              subtitle: Text('نسخه 1.0.0 — مرحله ۷'),
            ),
          ),
        ],
      ),
    );
  }
}
