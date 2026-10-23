// lib/presentation/widgets/account_switcher_sheet.dart
//
// برگهٔ پایینی جابه‌جایی بین حساب‌ها.
// فهرست حساب‌ها را نشان می‌دهد؛ با لمس هر حساب، آن حساب فعال می‌شود.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:english_teacher/presentation/providers/auth_state.dart';

/// برگهٔ مودال جابه‌جایی حساب.
class AccountSwitcherSheet extends StatelessWidget {
  const AccountSwitcherSheet({super.key});

  /// نمایش برگه به صورت مودال پایین‌صفحه
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const AccountSwitcherSheet(),
    );
  }

  /// دیالوگ تأیید حذف حساب
  Future<void> _confirmDelete(
    BuildContext context,
    String name,
    String accountId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('حذف حساب'),
        content: Text(
          'حساب «$name» به‌همراه همهٔ داده‌هایش حذف شود؟\nاین کار قابل بازگشت نیست.',
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
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<AuthState>().deleteAccount(accountId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final currentId = auth.currentAccount?.id;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'جابه‌جایی حساب',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (auth.accounts.isEmpty)
              // حالت خالی: هیچ حسابی نیست
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'هنوز حسابی ساخته نشده است.',
                  textAlign: TextAlign.center,
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: auth.accounts.length,
                  itemBuilder: (context, index) {
                    final account = auth.accounts[index];
                    final isCurrent = account.id == currentId;
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          account.name.isNotEmpty
                              ? account.name.characters.first
                              : '؟',
                        ),
                      ),
                      title: Text(account.name),
                      subtitle: Text(
                        account.email,
                        textDirection: TextDirection.ltr,
                      ),
                      // تیک روی حساب فعال
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isCurrent)
                            const Icon(Icons.check_circle,
                                color: Colors.green)
                          else
                            // حذف فقط برای حساب غیرفعال مجاز است
                            IconButton(
                              tooltip: 'حذف حساب',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _confirmDelete(
                                context,
                                account.name,
                                account.id,
                              ),
                            ),
                        ],
                      ),
                      enabled: !isCurrent,
                      onTap: isCurrent
                          ? null
                          : () async {
                              Navigator.pop(context);
                              await context
                                  .read<AuthState>()
                                  .switchAccount(account.id);
                            },
                    );
                  },
                ),
              ),
            const SizedBox(height: 8),
            // افزودن حساب جدید
            OutlinedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('افزودن حساب'),
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/login');
              },
            ),
          ],
        ),
      ),
    );
  }
}
