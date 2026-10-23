// lib/presentation/screens/grammar/manual_rule_sheet.dart
//
// برگهٔ «افزودن قاعدهٔ دستی» (مرحلهٔ ۴ — قواعد).
//
// تا وقتی تحلیل خودکار Gemini در مرحلهٔ ۵ فعال شود، کاربر می‌تواند
// قاعده‌ها را دستی وارد «قواعد من» کند. ذخیره از طریق
// [LocalGrammarRepository.upsertRule] انجام می‌شود، پس اگر همان
// دسته+عنوان قبلاً ثبت شده باشد، فقط به‌روز می‌شود (تکراری ساخته نمی‌شود).

import 'package:flutter/material.dart';

import 'package:english_teacher/data/grammar/local_grammar_repository.dart';
import 'package:english_teacher/presentation/screens/grammar/grammar_screen.dart'
    show kSuggestedCategories;

/// برگهٔ پایین‌رونده برای افزودن/به‌روزرسانی دستی یک قاعدهٔ گرامری.
/// در صورت ذخیرهٔ موفق، `true` برمی‌گرداند.
class ManualRuleSheet extends StatefulWidget {
  const ManualRuleSheet({super.key});

  @override
  State<ManualRuleSheet> createState() => _ManualRuleSheetState();
}

class _ManualRuleSheetState extends State<ManualRuleSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _categoryController = TextEditingController();
  final _explanationController = TextEditingController();
  final _formulaController = TextEditingController();
  final _examplesController = TextEditingController();
  final _mistakesController = TextEditingController();

  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _categoryController.dispose();
    _explanationController.dispose();
    _formulaController.dispose();
    _examplesController.dispose();
    _mistakesController.dispose();
    super.dispose();
  }

  /// انتخاب دسته از فهرست پیشنهادی.
  Future<void> _pickCategory() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('انتخاب دسته'),
        children: [
          for (final category in kSuggestedCategories)
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(category),
              child: Text(category),
            ),
        ],
      ),
    );
    if (selected != null) {
      _categoryController.text = selected;
    }
  }

  /// تقسیم متن چندخطی به لیست موارد (هر خط یک مورد).
  List<String> _splitLines(String text) => text
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await LocalGrammarRepository().upsertRule(
        category: _categoryController.text,
        title: _titleController.text,
        explanation: _explanationController.text,
        formula: _formulaController.text,
        examples: _splitLines(_examplesController.text),
        commonMistakes: _splitLines(_mistakesController.text),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('ذخیره ناموفق بود؛ دوباره تلاش کن.')),
      );
      return;
    }
    if (!mounted) return;
    messenger.showSnackBar(
      const SnackBar(content: Text('قاعده به «قواعد من» اضافه شد ✅')),
    );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottom),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'قاعدهٔ جدید',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'عنوان قاعده *',
                    hintText: 'مثلاً: گذشتهٔ ساده',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'عنوان را بنویس' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _categoryController,
                  readOnly: true,
                  onTap: _pickCategory,
                  decoration: const InputDecoration(
                    labelText: 'دسته *',
                    hintText: 'مثلاً: زمان‌ها',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.arrow_drop_down),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'دسته را انتخاب کن' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _explanationController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'توضیح کامل',
                    hintText: 'قاعده را با دلیل و منطقش به فارسی بنویس…',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: TextFormField(
                    controller: _formulaController,
                    textAlign: TextAlign.left,
                    decoration: const InputDecoration(
                      labelText: 'فرمول (انگلیسی)',
                      hintText: 'Subject + V2 + ...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _examplesController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'مثال‌ها (هر خط یک مثال)',
                    hintText: 'I went home — من به خانه رفتم',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _mistakesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'اشتباهات رایج (هر خط یک مورد)',
                    hintText: 'مثلاً: استفاده از did همراه فعل گذشته',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('ذخیره در «قواعد من»'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
