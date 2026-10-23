// lib/presentation/screens/auth/login_screen.dart
//
// صفحهٔ ورود: ایمیل + رمز عبور.
// در صورت موفقیت به '/home' می‌رود؛ خطاها با SnackBar نمایش داده می‌شوند.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:english_teacher/presentation/providers/auth_state.dart';
import 'package:english_teacher/presentation/screens/settings/sync_section.dart';

/// صفحهٔ ورود به حساب کاربری.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // مشغول‌بودن درخواست ورود (جدا از isLoading اولیهٔ AuthState)
  bool _busy = false;
  // نمایش/مخفی‌کردن رمز
  bool _obscure = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// تلاش برای ورود؛ موفق → '/home'، ناموفق → SnackBar فارسی
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final auth = context.read<AuthState>();
    final ok = await auth.signIn(
      email: _emailController.text,
      password: _passwordController.text,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      // گوشی جدید؟ اگر در ابر داده هست و اینجا خالی است، پیشنهاد بازیابی
      await SyncRestorePrompt.maybeShow(context);
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      _showError(auth);
    }
  }

  void _showError(AuthState auth) {
    final msg = auth.error;
    if (msg == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
    auth.clearError();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ورود')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // لوگوی متنی اپ
                Text(
                  'معلم انگلیسی من',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 32),
                // فیلد ایمیل
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
                ),
                const SizedBox(height: 16),
                // فیلد رمز عبور
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscure,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: 'رمز عبور',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () =>
                          setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'رمز عبور را وارد کنید';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 24),
                // دکمهٔ ورود
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('ورود'),
                ),
                const SizedBox(height: 8),
                // فراموشی رمز
                TextButton(
                  onPressed: _busy
                      ? null
                      : () =>
                          Navigator.pushNamed(context, '/forgot'),
                  child: const Text('رمز را فراموش کردم'),
                ),
                const Divider(height: 32),
                // رفتن به ثبت‌نام
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('حساب ندارم؟'),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => Navigator.pushReplacementNamed(
                                context,
                                '/signup',
                              ),
                      child: const Text('ثبت‌نام'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
