// lib/presentation/screens/exercises/review_screen.dart
//
// صفحهٔ «مرور امروز» (مرحلهٔ ۶): فلش‌کارت‌های سررسیده با
// زمان‌بندی تکرار فاصله‌دار.

import 'package:flutter/material.dart';

import 'package:english_teacher/data/review/spaced_repetition.dart';
import 'package:english_teacher/presentation/widgets/fa_digits.dart';

/// مرور روزانه: نمایش روی کارت → نمایش پاسخ → «بلدم / بلد نیستم».
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final _scheduler = SpacedRepetition();
  List<ReviewItem> _items = [];
  int _index = 0;
  int _known = 0;
  bool _revealed = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await _scheduler.dueReviews();
      if (mounted) {
        setState(() {
          _items = items;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _answer(bool known) async {
    final item = _items[_index];
    if (known) _known++;
    try {
      await _scheduler.review(
          table: item.table, id: item.id, correct: known);
    } catch (_) {
      // ثبت مرور شکست خورد؛ باز هم به آیتم بعد می‌رویم
    }
    if (!mounted) return;
    setState(() {
      _index++;
      _revealed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مرور امروز 📚')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _index >= _items.length
              ? _buildDone()
              : _buildCard(),
    );
  }

  Widget _buildCard() {
    final item = _items[_index];
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearProgressIndicator(
            value: _items.isEmpty ? 0 : (_index + 1) / _items.length,
          ),
          const SizedBox(height: 8),
          Text(
            'کارت ${toFaDigits('${_index + 1}')} از ${toFaDigits('${_items.length}')}'
            ' • ${item.tableFaName}',
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.front,
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),
                    if (_revealed) ...[
                      const Divider(),
                      const SizedBox(height: 8),
                      Text(
                        item.back,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 20, height: 1.8),
                      ),
                    ] else
                      OutlinedButton(
                        onPressed: () =>
                            setState(() => _revealed = true),
                        child: const Text('نمایش پاسخ'),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_revealed)
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () => _answer(false),
                    icon: const Icon(Icons.close),
                    label: const Text('بلد نیستم'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _answer(true),
                    icon: const Icon(Icons.check),
                    label: const Text('بلدم'),
                  ),
                ),
              ],
            )
          else
            const SizedBox(
              height: 48,
              child: Center(
                child: Text('اول پاسخ را ببین، بعد خودت را ارزیابی کن 🙂',
                    style: TextStyle(fontSize: 12)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDone() {
    final total = _items.length;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 12),
            Text(
              total == 0
                  ? 'چیزی برای مرور نیست!'
                  : 'مرور امروز تمام شد!',
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              total == 0
                  ? 'کلمه‌ای به دفتر واژگان اضافه کن تا اینجا برای مرور بیاید.'
                  : '${toFaDigits('$_known')} از ${toFaDigits('$total')} را بلد بودی 👏',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('بازگشت'),
            ),
          ],
        ),
      ),
    );
  }
}
