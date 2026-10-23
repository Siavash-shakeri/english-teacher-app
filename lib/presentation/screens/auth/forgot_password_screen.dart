// lib/presentation/screens/auth/forgot_password_screen.dart
//
// صفحهٔ فراموشی رمز عبور.
//
// فعلاً سرویس ایمیل/بازیابی وجود ندارد (مرحلهٔ ۷)؛ بنابراین
// فراخوانی requestPasswordReset همیشه [AuthException] با پیام فارسی
// «بازیابی رمز با ایمیل در مرحلهٔ ۷ (همگام‌سازی ابری) فعال می‌شود»
// می‌دهد و ما همان را صادقانه در SnackBar نشان می‌دهیم.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:english_teacher/presentation/providers/auth_state.dart';

/// صفحهٔ درخواست بازیابی رمز عبور.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _busy = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  /// ارسال درخواست بازیابی؛ در مرحلهٔ ۱ همیشه پیام مرحلهٔ ۷ را نشان می‌دهد
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final auth = context.read<AuthState>();
    final ok =
        await auth.requestPasswordReset(_emailController.text);
    if (!mounted) return;
    setState(() => _busy = false);
    final msg = auth.error;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لینک بازیابی ارسال شد')),
      );
      Navigator.pop(context);
    } else if (msg != null) {
      // پیام صادقانهٔ مرحلهٔ ۷
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
      auth.clearError();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('فراموشی رمز عبور')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'ایمیل حسابتان را وارد کنید تا لینک بازیابی برایتان ارسال شود.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'ایمیل',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'ایمیل را وارد کنید';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('ارسال لینک بازیابی'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
