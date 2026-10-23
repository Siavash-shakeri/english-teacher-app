import 'package:flutter/material.dart';

import '../ai_tutor/ai_tutor_screen.dart';
import '../exercises/exercises_screen.dart';
import '../grammar/grammar_screen.dart';
import '../homeworks/homeworks_screen.dart';
// صفحه‌ی تنظیمات را همکار دیگری می‌سازد:
// lib/presentation/screens/settings/settings_screen.dart
import '../settings/settings_screen.dart';

/// صفحه‌ی اصلی اپ — ۵ تب پایین صفحه با IndexedStack.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  static const _pages = <Widget>[
    HomeworksScreen(),
    GrammarScreen(),
    ExercisesScreen(),
    AiTutorScreen(),
    SettingsScreen(),
  ];

  static const _labels = [
    'مشق‌ها',
    'قواعد',
    'تمرین',
    'معلم هوش مصنوعی',
    'تنظیمات',
  ];

  static const _icons = [
    Icons.book_outlined,
    Icons.menu_book_outlined,
    Icons.quiz_outlined,
    Icons.smart_toy_outlined,
    Icons.settings_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: List.generate(
          _pages.length,
          (i) => BottomNavigationBarItem(
            icon: Icon(_icons[i]),
            label: _labels[i],
          ),
        ),
      ),
    );
  }
}
