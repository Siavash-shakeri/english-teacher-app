// lib/presentation/screens/grammar/analysis_result_screen.dart
//
// صفحهٔ نمایش نتیجهٔ تحلیل خودکار گرامری (مرحلهٔ ۵):
// - تحلیل جمله‌به‌جمله (زمان/ساختار)
// - اصلاح اشتباه‌های کاربر با دلیل
// - قواعد پیشنهادی با دکمهٔ «ذخیره در قواعد من» (dedupe اعمال می‌شود)
// - کلمات کلیدی با دکمهٔ «افزودن به فلش‌کارت»

import 'package:flutter/material.dart';

import 'package:english_teacher/data/analysis/analysis_service.dart';
import 'package:english_teacher/data/grammar/local_grammar_repository.dart';
import 'package:english_teacher/data/vocabulary/local_vocabulary_repository.dart';

/// صفحهٔ نتیجهٔ تحلیل گرامری یک مشق.
class AnalysisResultScreen extends StatefulWidget {
  final GrammarAnalysisResult result;

  const AnalysisResultScreen({super.key, required this.result});

  @override
  State<AnalysisResultScreen> createState() => _AnalysisResultScreenState();
}

class _AnalysisResultScreenState extends State<AnalysisResultScreen> {
  final _grammarRepo = LocalGrammarRepository();
  final _vocabRepo = LocalVocabularyRepository();
  final Set<int> _savedRules = {};
  final Set<int> _savedWords = {};

  Future<void> _saveRule(int index) async {
    final draft = widget.result.ruleDrafts[index];
    await _grammarRepo.upsertRule(
      category: draft.category,
      title: draft.title,
      explanation: draft.explanation,
      formula: draft.formula,
      examples: draft.examples,
      commonMistakes: draft.commonMistakes,
    );
    if (mounted) {
      setState(() => _savedRules.add(index));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('در «قواعد من» ذخیره شد ✅')),
      );
    }
  }

  Future<void> _saveWord(int index) async {
    final kw = widget.result.keyWords[index];
    await _vocabRepo.upsertWord(
      word: kw.word,
      meaning: kw.meaning,
      example: kw.example,
      source: 'grammar',
    );
    if (mounted) {
      setState(() => _savedWords.add(index));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('به فلش‌کارت اضافه شد ✅')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    return Scaffold(
      appBar: AppBar(title: const Text('تحلیل قواعد')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (r.sentences.isNotEmpty) ...[
            _sectionTitle(context, 'تحلیل جمله‌ها', Icons.notes_outlined),
            for (final s in r.sentences) _sentenceCard(s),
            const SizedBox(height: 16),
          ],
          if (r.corrections.isNotEmpty) ...[
            _sectionTitle(context, 'اصلاح اشتباه‌ها', Icons.edit_outlined),
            for (final c in r.corrections) _correctionCard(c),
            const SizedBox(height: 16),
          ],
          if (r.ruleDrafts.isNotEmpty) ...[
            _sectionTitle(
                context, 'قواعد پیشنهادی', Icons.menu_book_outlined),
            for (var i = 0; i < r.ruleDrafts.length; i++)
              _ruleDraftCard(r.ruleDrafts[i], i),
            const SizedBox(height: 16),
          ],
          if (r.keyWords.isNotEmpty) ...[
            _sectionTitle(
                context, 'کلمات کلیدی', Icons.style_outlined),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < r.keyWords.length; i++)
                  _keywordChip(r.keyWords[i], i),
              ],
            ),
          ],
          if (r.sentences.isEmpty &&
              r.corrections.isEmpty &&
              r.ruleDrafts.isEmpty &&
              r.keyWords.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'تحلیل خالی برگشت؛ دوباره تلاش کن.',
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }

  Widget _sentenceCard(SentenceAnalysis s) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                s.sentence,
                textAlign: TextAlign.left,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 6),
            Text('⏱ زمان/ساختار: ${s.tense}'),
            if (s.structure.isNotEmpty) Text('📐 فرمول: ${s.structure}'),
            if (s.note != null && s.note!.isNotEmpty)
              Text('💡 ${s.note!}'),
          ],
        ),
      ),
    );
  }

  Widget _correctionCard(Correction c) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                '❌ ${c.original}',
                textAlign: TextAlign.left,
              ),
            ),
            const SizedBox(height: 4),
            Text('✅ ${c.correctPart}'),
            const SizedBox(height: 4),
            Text('چرا؟ ${c.reason}'),
          ],
        ),
      ),
    );
  }

  Widget _ruleDraftCard(RuleDraft draft, int index) {
    final saved = _savedRules.contains(index);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '[${draft.category}] ${draft.title}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(draft.explanation),
            if (draft.formula != null && draft.formula!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('📐 ${draft.formula!}'),
              ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              icon: Icon(saved ? Icons.check : Icons.bookmark_add_outlined),
              label: Text(saved ? 'ذخیره شد ✅' : 'ذخیره در «قواعد من»'),
              onPressed: saved ? null : () => _saveRule(index),
            ),
          ],
        ),
      ),
    );
  }

  Widget _keywordChip(AnalysisKeyWord kw, int index) {
    final saved = _savedWords.contains(index);
    return ActionChip(
      avatar: Icon(
        saved ? Icons.check : Icons.add,
        size: 16,
      ),
      label: Text('${kw.word} — ${kw.meaning}'),
      onPressed: saved ? null : () => _saveWord(index),
    );
  }
}
