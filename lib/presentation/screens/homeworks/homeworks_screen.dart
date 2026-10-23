import 'package:flutter/material.dart';

import 'package:english_teacher/data/homework/local_homework_repository.dart';
import 'package:english_teacher/domain/models/homework.dart';
import 'package:english_teacher/presentation/screens/scan/scan_screen.dart';

import 'homework_detail_screen.dart';

/// صفحه‌ی «مشق‌ها»: فهرست مشق‌های اسکن‌شده‌ی حساب فعال.
///
/// دکمه‌ی «اسکن جدید»، [ScanScreen] را باز می‌کند؛ وقتی صفحه‌ی اسکن
/// با نتیجه‌ی `true` بسته شود، فهرست دوباره خوانده می‌شود.
class HomeworksScreen extends StatefulWidget {
  const HomeworksScreen({super.key});

  @override
  State<HomeworksScreen> createState() => _HomeworksScreenState();
}

class _HomeworksScreenState extends State<HomeworksScreen> {
  final LocalHomeworkRepository _repo = LocalHomeworkRepository();

  List<Homework> _homeworks = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// خواندن فهرست مشق‌ها از ریپازیتوری محلی.
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _repo.listHomeworks();
      if (!mounted) return;
      setState(() {
        _homeworks = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'خطا در خواندن مشق‌ها';
        _loading = false;
      });
    }
  }

  /// باز کردن صفحه‌ی اسکن؛ اگر مشق جدیدی ذخیره شد، فهرست را تازه می‌کند.
  Future<void> _openScan() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ScanScreen()),
    );
    if (created == true) {
      await _load();
    }
  }

  /// باز کردن صفحه‌ی جزئیات مشق.
  Future<void> _openDetail(Homework homework) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => HomeworkDetailScreen(homework: homework),
      ),
    );
    if (changed == true) {
      await _load();
    }
  }

  /// تأیید و حذف یک مشق.
  Future<void> _confirmDelete(Homework homework) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف مشق؟'),
        content: const Text('این مشق حذف می‌شود.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _repo.deleteHomework(homework.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('حذف شد')),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مشق‌ها')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openScan,
        icon: const Icon(Icons.document_scanner_outlined),
        label: const Text('اسکن جدید'),
      ),
      body: _buildBody(),
    );
  }

  /// بدنه بر اساس وضعیت: بارگذاری، خطا، خالی یا فهرست.
  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _load,
              child: const Text('تلاش دوباره'),
            ),
          ],
        ),
      );
    }
    if (_homeworks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.book_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'هنوز مشقی ثبت نشده',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'با «اسکن جدید» اولین مشقت را اضافه کن',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: _homeworks.length,
      itemBuilder: (context, index) {
        final hw = _homeworks[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            title: Text(hw.title),
            subtitle: Text('${_faDateTime(hw.createdAt)}\n${_snippet(hw)}'),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'حذف',
              onPressed: () => _confirmDelete(hw),
            ),
            onTap: () => _openDetail(hw),
          ),
        );
      },
    );
  }
}

/// خلاصه‌ی متن استخراج‌شده: حداکثر ۶۰ نویسه‌ی اول با «…».
String _snippet(Homework homework) {
  final text = homework.extractedText.trim();
  if (text.isEmpty) return '—';
  return text.length > 60 ? '${text.substring(0, 60)}…' : text;
}

/// تاریخ و ساعت میلادی با ارقام فارسی.
/// تبدیل شمسی در مرحله‌ی بعد اضافه می‌شود.
String _faDateTime(DateTime dt) {
  return '${_faDigitsOf(dt.year)}/${_faDigitsOf(dt.month)}/${_faDigitsOf(dt.day)}'
      '  ${_faDigitsOf(dt.hour)}:${_faDigitsOf(dt.minute)}';
}

/// تبدیل یک عدد به رشته با ارقام فارسی.
String _faDigitsOf(int n) => _faDigits(n.toString());

/// تبدیل ارقام لاتین به فارسی.
String _faDigits(String input) {
  const digits = '۰۱۲۳۴۵۶۷۸۹';
  return input.replaceAllMapped(
    RegExp(r'[0-9]'),
    (match) => digits[int.parse(match.group(0)!)],
  );
}
