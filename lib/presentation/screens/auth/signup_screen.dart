// lib/presentation/screens/auth/signup_screen.dart
//
// صفحهٔ ثبت‌نام: نام + ایمیل + رمز عبور + تکرار رمز.
// در صورت موفقیت به '/home' می‌رود؛ خطاها با SnackBar نمایش داده می‌شوند.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:english_teacher/presentation/providers/auth_state.dart';

/// صفحهٔ ساخت حساب کاربری جدید.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _busy = false;
  bool _obscure = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  /// تلاش برای ثبت‌نام؛ موفق → '/home'، ناموفق → SnackBar فارسی
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final auth = context.read<AuthState>();
    final ok = await auth.signUp(
      name: _nameController.text,
      email: _emailController.text,
      password: _passwordController.text,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      final msg = auth.error;
      if (msg != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
        auth.clearError();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ثبت‌نام')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'ساخت حساب جدید',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 32),
                // نام
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'نام',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'نام را وارد کنید';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // ایمیل
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
                // رمز عبور
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscure,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: 'رمز عبور (حداقل ۶ کاراکتر)',
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
                    if (v.length < 6) {
                      return 'رمز عبور باید حداقل ۶ کاراکتر باشد';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // تکرار رمز عبور
                TextFormField(
                  controller: _confirmController,
                  obscureText: _obscureConfirm,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: 'تکرار رمز عبور',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setState(
                        () => _obscureConfirm = !_obscureConfirm,
                      ),
                    ),
                  ),
                  validator: (v) {
                    if (v != _passwordController.text) {
                      return 'تکرار رمز با رمز عبور یکسان نیست';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 24),
                // دکمهٔ ثبت‌نام
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('ثبت‌نام'),
                ),
                const Divider(height: 32),
                // بازگشت به ورود
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('حساب دارم؟'),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => Navigator.pushReplacementNamed(
                                context,
                                '/login',
                              ),
                      child: const Text('ورود'),
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
