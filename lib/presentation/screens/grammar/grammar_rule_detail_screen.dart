// lib/presentation/screens/grammar/grammar_rule_detail_screen.dart
//
// صفحهٔ جزئیات یک قاعدهٔ «قواعد من» (مرحلهٔ ۴ — قواعد).
//
// بخش‌ها: دسته و تاریخ اولین دیدن، توضیح کامل، فرمول، مثال‌ها،
// اشتباهات رایج، کلمات کلیدی (با دکمهٔ افزودن به فلش‌کارت)،
// دکمه‌های ستاره و حذف در AppBar.

import 'package:flutter/material.dart';

import 'package:english_teacher/data/grammar/local_grammar_repository.dart';
import 'package:english_teacher/data/vocabulary/local_vocabulary_repository.dart';
import 'package:english_teacher/domain/models/grammar_rule.dart';
import 'package:english_teacher/presentation/widgets/ask_ai_button.dart';
import 'package:english_teacher/presentation/widgets/fa_digits.dart';

/// صفحهٔ جزئیات یک قاعدهٔ گرامری.
/// در صورت تغییر (ستاره/حذف)، هنگام برگشت `true` برمی‌گرداند.
class GrammarRuleDetailScreen extends StatefulWidget {
  final GrammarRule rule;

  const GrammarRuleDetailScreen({super.key, required this.rule});

  @override
  State<GrammarRuleDetailScreen> createState() =>
      _GrammarRuleDetailScreenState();
}

class _GrammarRuleDetailScreenState extends State<GrammarRuleDetailScreen> {
  final _grammarRepo = LocalGrammarRepository();
  final _vocabRepo = LocalVocabularyRepository();

  late GrammarRule _rule;

  /// کلماتی که همین‌جا به فلش‌کارت اضافه شده‌اند (تا دکمه غیرفعال شود).
  final Set<String> _addedWords = {};

  /// کنترلر فیلد کلمهٔ کلیدی (فیلد حالت تا با rebuild متن پاک نشود).
  final _keyWordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _rule = widget.rule;
  }

  @override
  void dispose() {
    _keyWordController.dispose();
    super.dispose();
  }

  Future<void> _toggleStar() async {
    try {
      await _grammarRepo.setStarred(_rule.id, !_rule.isStarred);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تغییر ستاره ناموفق بود؛ دوباره تلاش کن.')),
      );
      return;
    }
    if (!mounted) return;
    setState(() {
      _rule = _rule.copyWith(isStarred: !_rule.isStarred);
    });
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف قاعده'),
        content: Text('«${_rule.title}» از «قواعد من» حذف شود؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _grammarRepo.deleteRule(_rule.id);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حذف ناموفق بود؛ دوباره تلاش کن.')),
      );
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  /// افزودن یک کلمهٔ کلیدی به فلش‌کارت‌ها.
  ///
  /// معنی را از خودِ قاعده برنمی‌داریم چون نداریم — کاربر باید معنی را
  /// ببیند؛ پس از او می‌خواهیم معنی را وارد کند. (ساده و صادقانه)
  Future<void> _addWord(String word) async {
    final meaningController = TextEditingController();
    final meaning = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('معنی «$word»'),
        content: TextField(
          controller: meaningController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'معنی فارسی کلمه را بنویس…',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(ctx).pop(meaningController.text.trim()),
            child: const Text('افزودن'),
          ),
        ],
      ),
    );
    if (meaning == null || meaning.isEmpty) return;
    try {
      await _vocabRepo.upsertWord(
        word: word,
        meaning: meaning,
        source: 'grammar',
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ذخیره ناموفق بود؛ دوباره تلاش کن.')),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _addedWords.add(word));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('به فلش‌کارت اضافه شد ✅')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_rule.title),
        actions: [
          // بپرس از هوش مصنوعی (مرحلهٔ ۵)
          IconButton(
            icon: const Icon(Icons.smart_toy_outlined),
            onPressed: () => AskAi.fromRule(context, _rule),
            tooltip: 'بپرس از هوش مصنوعی',
          ),
          IconButton(
            icon:
                Icon(_rule.isStarred ? Icons.star : Icons.star_border),
            onPressed: _toggleStar,
            tooltip: _rule.isStarred ? 'برداشتن ستاره' : 'ستاره‌دار کردن',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _delete,
            tooltip: 'حذف',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
            _buildMetaCard(),
            const SizedBox(height: 12),
            _buildSection(
              icon: Icons.description_outlined,
              title: 'توضیح',
              child: Text(
                _rule.explanation.isEmpty
                    ? 'توضیحی ثبت نشده است.'
                    : _rule.explanation,
              ),
            ),
            if (_rule.formula != null && _rule.formula!.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildSection(
                icon: Icons.functions_outlined,
                title: 'فرمول',
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _rule.formula!,
                      textAlign: TextAlign.left,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
            if (_rule.examples.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildSection(
                icon: Icons.format_list_bulleted,
                title: 'مثال‌ها',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final example in _rule.examples)
                      _buildExampleTile(example),
                  ],
                ),
              ),
            ],
            if (_rule.commonMistakes.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildSection(
                icon: Icons.warning_amber_outlined,
                title: 'اشتباهات رایج فارسی‌زبانان',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final mistake in _rule.commonMistakes)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('⚠️ '),
                            Expanded(child: Text(mistake)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            _buildKeyWordsCard(),
          ],
        ),
      );
    }

  Widget _buildMetaCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Chip(label: Text(_rule.category)),
            const Spacer(),
            Text(
              'اولین دیدن: ${faDate(_rule.firstSeenAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }

  /// مثال: ممکن است به شکل «متن — ترجمه» باشد.
  Widget _buildExampleTile(String example) {
    final parts = example.split(RegExp(r'\s*[—–-]\s*'));
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              parts.first.trim(),
              textAlign: TextAlign.left,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          if (parts.length > 1)
            Text(
              parts.sublist(1).join(' — ').trim(),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
        ],
      ),
    );
  }

  /// کارت کلمات کلیدی: از کاربر می‌خواهد کلمه را وارد کند چون
  /// کلمات کلیدی خودکار از مرحلهٔ ۵ (تحلیل Gemini) می‌آیند.
  Widget _buildKeyWordsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.key_outlined, size: 20),
                const SizedBox(width: 8),
                Text(
                  'کلمات کلیدی',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'کلمات کلیدی خودکار با تحلیل Gemini در مرحلهٔ ۵ اضافه می‌شوند؛ '
              'تا آن موقع می‌توانی دستی وارد کنی.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _keyWordController,
                    decoration: const InputDecoration(
                      hintText: 'کلمهٔ انگلیسی…',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: () {
                    final word = _keyWordController.text.trim();
                    if (word.isNotEmpty) {
                      _keyWordController.clear();
                      _addWord(word);
                    }
                  },
                  child: const Text('افزودن به فلش‌کارت'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
