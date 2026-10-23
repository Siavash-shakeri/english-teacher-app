import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'package:english_teacher/presentation/theme/app_theme.dart';
import 'package:english_teacher/presentation/providers/theme_provider.dart';
import 'package:english_teacher/presentation/screens/home/home_screen.dart';

// فایل‌های زیر را همکار دیگری می‌نویسد؛ اینجا فقط ایمپورت می‌شوند:
import 'package:english_teacher/data/auth/local_auth_repository.dart';
import 'package:english_teacher/presentation/providers/auth_state.dart';
// صفحه‌های ورود / ثبت‌نام / فراموشی رمز هم از همین قرار:
import 'package:english_teacher/presentation/screens/auth/login_screen.dart';
import 'package:english_teacher/presentation/screens/auth/signup_screen.dart';
import 'package:english_teacher/presentation/screens/auth/forgot_password_screen.dart';

import 'package:english_teacher/data/ai/ai_gate.dart';
import 'package:english_teacher/data/sync/firebase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // کش حضور کلید Gemini برای موتورهای آنلاین (isAvailable همگام)
  AiGate.refreshKeyPresence();
  // مقداردهی Firebase؛ اگر google-services.json نباشد، اپ آفلاین می‌ماند
  await FirebaseService.instance.initialize();
  runApp(const EnglishTeacherApp());
}

/// ریشه‌ی اپ: تزریق Providerها و MaterialApp با بومی‌سازی فارسی.
class EnglishTeacherApp extends StatelessWidget {
  const EnglishTeacherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(
          create: (_) => AuthState(LocalAuthRepository()),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, theme, _) {
          return MaterialApp(
            title: 'معلم انگلیسی من',
            debugShowCheckedModeBanner: false,
            locale: const Locale('fa'),
            supportedLocales: const [Locale('fa'), Locale('en')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: theme.mode,
            home: Consumer<AuthState>(
              builder: (context, auth, _) {
                // در حال بارگذاری وضعیت ورود؟
                if (auth.isLoading) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                // وارد نشده؟ صفحه‌ی ورود
                if (auth.currentAccount == null) {
                  return const LoginScreen();
                }
                // وارد شده؟ صفحه‌ی اصلی
                return const HomeScreen();
              },
            ),
            routes: {
              '/login': (_) => const LoginScreen(),
              '/signup': (_) => const SignUpScreen(),
              '/forgot': (_) => const ForgotPasswordScreen(),
              '/home': (_) => const HomeScreen(),
            },
          );
        },
      ),
    );
  }
}
