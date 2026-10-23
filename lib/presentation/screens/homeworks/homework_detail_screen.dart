import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:english_teacher/data/analysis/analysis_service.dart';
import 'package:english_teacher/data/ai/gemini_client.dart';
import 'package:english_teacher/data/translate/sentence_splitter.dart';
import 'package:english_teacher/data/translate/translate_service.dart';
import 'package:english_teacher/data/vocabulary/local_vocabulary_repository.dart';
import 'package:english_teacher/domain/models/homework.dart';
import 'package:english_teacher/presentation/screens/grammar/analysis_result_screen.dart';
import 'package:english_teacher/presentation/screens/grammar/manual_rule_sheet.dart';
import 'package:english_teacher/presentation/screens/exercises/quiz_setup_screen.dart';
import 'package:english_teacher/presentation/widgets/ask_ai_button.dart';
import 'package:english_teacher/presentation/widgets/tappable_text.dart';

/// صفحه‌ی جزئیات یک مشق: تصاویر صفحه‌ها، جمله‌ها با ترجمه، و تاریخ ثبت.
class HomeworkDetailScreen extends StatefulWidget {
  /// مشقی که باید نمایش داده شود.
  final Homework homework;

  const HomeworkDetailScreen({super.key, required this.homework});

  @override
  State<HomeworkDetailScreen> createState() => _HomeworkDetailScreenState();
}

class _HomeworkDetailScreenState extends State<HomeworkDetailScreen> {
  /// موتور ترجمه‌ی آفلاین (ML Kit) — یک نمونه برای کل صفحه.
  late final MlKitTranslateEngine _engine;

  /// دلیل غیرفعال بودن موتور ابری Gemini (نمایش در تول‌تیپ).
  late final String _geminiUnavailableReason;

  /// جمله‌های متن استخراج‌شده.
  late final List<String> _sentences;

  /// ترجمه‌های کش‌شده به تفکیک شماره‌ی جمله (تا rebuild دوباره ترجمه نکند).
  final Map<int, String> _translations = {};

  /// شماره‌ی جمله‌هایی که الان در حال ترجمه‌اند.
  final Set<int> _translating = {};

  /// شماره‌ی جمله‌هایی که الان در حال دانلود مدل ترجمه‌اند.
  final Set<int> _downloadingModel = {};

  /// خطای ترجمه به تفکیک شماره‌ی جمله.
  final Map<int, String> _errors = {};

  @override
  void initState() {
    super.initState();
    _engine = MlKitTranslateEngine();
    // موتور ابری فقط برای خواندن دلیل غیرفعال بودنش ساخته می‌شود؛
    // واقعی‌اش در مرحله‌ی ۵ وصل می‌شود.
    final gemini = GeminiTranslateEngine();
    final reason = gemini.unavailableReason;
    _geminiUnavailableReason =
        reason.trim().isEmpty ? 'در مرحله ۵ فعال می‌شود' : reason;
    unawaited(gemini.close());
    _sentences = SentenceSplitter.split(widget.homework.extractedText.trim());
  }

  @override
  void dispose() {
    unawaited(_engine.close());
    super.dispose();
  }

  /// ترجمه‌ی یک جمله؛ نتیجه کش می‌شود تا rebuild دوباره ترجمه نکند.
  Future<void> _translateSentence(int index) async {
    if (_translations.containsKey(index) || _translating.contains(index)) {
      return;
    }
    setState(() {
      _translating.add(index);
      _errors.remove(index);
    });
    String? result;
    String? error;
    try {
      // اگر مدل ترجمه هنوز دانلود نشده، اول پیام «دانلود مدل» نشان بده.
      final downloaded = await _engine.isModelDownloaded;
      if (!downloaded && mounted) {
        setState(() => _downloadingModel.add(index));
      }
      result = await _engine.translate(_sentences[index]);
    } catch (_) {
      error = 'ترجمه ناموفق بود؛ اتصال را بررسی کن و دوباره تلاش کن.';
    }
    if (!mounted) return;
    setState(() {
      _translating.remove(index);
      _downloadingModel.remove(index);
      if (result != null) {
        _translations[index] = result;
      } else {
        _errors[index] = error ?? 'خطای نامشخصی رخ داد.';
      }
    });
  }

  /// برگهٔ تحلیل قواعد: اجرای خودکار با Gemini (اگر کلید هست) یا
  /// نمایش وضعیت صادقانه + افزودن دستی.
  ///
  /// در مرحلهٔ ۵ موتور Gemini با کلید API کاربر در تنظیمات سیم‌کشی شد؛
  /// بدون کلید هیچ تحلیل جعلی نشان داده نمی‌شود.
  Future<void> _showAnalysisSheet() async {
    final engine = GeminiAnalysisEngine();
    if (!engine.isAvailable) {
      _showAnalysisUnavailable(engine.unavailableReason);
      unawaited(engine.close());
      return;
    }
    // اجرای تحلیل با دیالوگ «در حال تحلیل…»
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (c) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Expanded(child: Text('در حال تحلیل قواعد…')),
          ],
        ),
      ),
    );
    GrammarAnalysisResult? result;
    String? error;
    try {
      result = await engine.analyzeHomework(widget.homework.extractedText);
    } on GeminiException catch (e) {
      error = e.persianMessage;
    } catch (e) {
      error = e is UnsupportedError
          ? e.message ?? 'تحلیل در دسترس نیست'
          : 'خطا در تحلیل: $e';
    } finally {
      await engine.close();
    }
    if (!mounted) return;
    Navigator.of(context).pop(); // بستن دیالوگ لودینگ
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }
    if (result != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AnalysisResultScreen(result: result!),
        ),
      );
    }
  }

  /// برگهٔ وضعیت صادقانه وقتی کلیدی وارد نشده + افزودن دستی.
  void _showAnalysisUnavailable(String reason) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'تحلیل قواعد این مشق',
                  textAlign: TextAlign.center,
                  style: Theme.of(ctx)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Card(
                  color: Theme.of(ctx).colorScheme.surfaceVariant,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(reason),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    final saved = await showModalBottomSheet<bool>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => const ManualRuleSheet(),
                    );
                    if (saved == true && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'قاعده در «قواعد من» ذخیره شد — از تب قواعد ببینش ✅'),
                        ),
                      );
                    }
                  },
                  child: const Text('➕ افزودن قاعده دستی'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// باز کردن پنجره‌ی معنی کلمه با تپ روی آن.
  void _showWordSheet(String word, String sentence) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _WordBottomSheet(
        engine: _engine,
        word: word,
        sentence: sentence,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hw = widget.homework;
    return Scaffold(
      appBar: AppBar(
        title: Text(hw.title),
        actions: [
          // تمرین (مرحله ۶): ساخت آزمون سریع فقط از همین مشق
          IconButton(
            tooltip: 'تمرین بساز',
            icon: const Text('📝', style: TextStyle(fontSize: 20)),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => QuizSetupScreen(homework: hw),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // تصاویر صفحه‌های مشق با نشانگر «صفحهٔ X از N»
          if (hw.imagePaths.isNotEmpty) ...[
            _ImagePages(imagePaths: hw.imagePaths),
            const SizedBox(height: 16),
          ],
          // بخش جمله‌ها با ترجمه
          Text(
            'جمله‌ها با ترجمه',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          _buildEngineRow(),
          const SizedBox(height: 8),
          if (_sentences.isEmpty)
            const Text('متنی برای ترجمه نیست')
          else
            for (var i = 0; i < _sentences.length; i++) _buildSentenceCard(i),
          const SizedBox(height: 16),
          // تحلیل قواعد (مرحله ۴): موتور خودکار Gemini در مرحله ۵ وصل می‌شود؛
          // تا آن موقع افزودن دستی قاعده در دسترس است.
          Text(
            'تحلیل قواعد',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'تحلیل خودکار هر مشق (زمان و ساختار هر جمله، توضیح کامل '
                    'قاعده با دلیل، فرمول، مثال‌ها و اشتباهات رایج) با کلید '
                    'Gemini در مرحلهٔ ۵ فعال می‌شود.',
                  ),
                  const SizedBox(height: 8),
                  FilledButton.tonal(
                    onPressed: _showAnalysisSheet,
                    child: const Text('📚 تحلیل قواعد این مشق'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // تاریخ ثبت
          Text(
            'تاریخ ثبت: ${_faDateTime(hw.createdAt)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  /// ردیف نمایش موتورهای ترجمه: آفلاین فعال، ابری غیرفعال.
  Widget _buildEngineRow() {
    final colorScheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'موتور ترجمه:',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Chip(
          avatar: const Icon(Icons.check, size: 16),
          label: const Text('آفلاین (ML Kit)'),
          backgroundColor: colorScheme.primaryContainer,
          labelStyle: TextStyle(color: colorScheme.onPrimaryContainer),
        ),
        Tooltip(
          message: _geminiUnavailableReason,
          child: const Opacity(
            opacity: 0.6,
            child: Chip(label: Text('آنلاین (Gemini)')),
          ),
        ),
      ],
    );
  }

  /// کارت یک جمله: متن انگلیسی قابل‌تپ + ناحیه‌ی ترجمه.
  Widget _buildSentenceCard(int index) {
    final sentence = _sentences[index];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // جمله‌ی انگلیسی؛ تپ روی هر کلمه پنجره‌ی معنی را باز می‌کند.
            Directionality(
              textDirection: TextDirection.ltr,
              child: TappableText(
                text: sentence,
                onWordTap: (word) => _showWordSheet(word, sentence),
              ),
            ),
            const SizedBox(height: 8),
            _buildTranslationArea(index),
            const SizedBox(height: 4),
            // دکمهٔ «بپرس از هوش مصنوعی» (مرحلهٔ ۵)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.smart_toy_outlined, size: 18),
                label: const Text('بپرس از هوش مصنوعی'),
                onPressed: () => AskAi.fromSentence(context, sentence),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ناحیه‌ی ترجمه‌ی یک جمله با سه حالت: نشده / در حال انجام / شده.
  Widget _buildTranslationArea(int index) {
    // ترجمه‌شده: متن فارسی راست‌به‌چپ.
    if (_translations.containsKey(index)) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Text(
          _translations[index]!,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    }
    // در حال ترجمه (یا دانلود مدل).
    if (_translating.contains(index)) {
      final downloading = _downloadingModel.contains(index);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const LinearProgressIndicator(),
          const SizedBox(height: 4),
          Text(
            downloading ? 'دانلود مدل ترجمه…' : 'در حال ترجمه…',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      );
    }
    // خطا: متن خطا + دکمه‌ی تلاش دوباره.
    if (_errors.containsKey(index)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _errors[index]!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => _translateSentence(index),
            child: const Text('تلاش دوباره'),
          ),
        ],
      );
    }
    // هنوز ترجمه نشده: دکمه‌ی نمایش ترجمه.
    return OutlinedButton(
      onPressed: () => _translateSentence(index),
      child: const Text('نمایش ترجمه'),
    );
  }
}

/// پنجره‌ی معنی کلمه: خود کلمه، معنی فارسی، جمله‌ی نمونه و دکمه‌ی فلش‌کارت.
class _WordBottomSheet extends StatefulWidget {
  final TranslateEngine engine;
  final String word;
  final String sentence;

  const _WordBottomSheet({
    required this.engine,
    required this.word,
    required this.sentence,
  });

  @override
  State<_WordBottomSheet> createState() => _WordBottomSheetState();
}

class _WordBottomSheetState extends State<_WordBottomSheet> {
  String? _meaning;
  String? _error;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadMeaning();
  }

  /// ترجمه‌ی تک‌کلمه با همان موتور ترجمه‌ی صفحه.
  Future<void> _loadMeaning() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final meaning = await widget.engine.translate(widget.word);
      if (!mounted) return;
      setState(() {
        _meaning = meaning;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'ترجمه ناموفق بود؛ اتصال را بررسی کن و دوباره تلاش کن.';
        _loading = false;
      });
    }
  }

  /// افزودن کلمه به فلش‌کارت‌ها (ذخیره‌ی محلی، جداگانه برای هر حساب).
  Future<void> _addToFlashcards() async {
    final meaning = _meaning;
    if (meaning == null || _saving) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await LocalVocabularyRepository().upsertWord(
        word: widget.word,
        meaning: meaning,
        example: widget.sentence,
        source: 'homework',
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
    Navigator.of(context).pop();
    messenger.showSnackBar(
      const SnackBar(content: Text('به فلش‌کارت اضافه شد ✅')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // خود کلمه (انگلیسی، چپ‌به‌راست)
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                widget.word,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            if (_loading) ...[
              const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              const SizedBox(height: 4),
              const Center(child: Text('در حال ترجمه…')),
            ] else if (_error != null) ...[
              Center(
                child: Text(
                  _error!,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
              TextButton(
                onPressed: _loadMeaning,
                child: const Text('تلاش دوباره'),
              ),
            ] else ...[
              Directionality(
                textDirection: TextDirection.rtl,
                child: Text(
                  _meaning!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'مثال:',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                widget.sentence,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: (_meaning == null || _saving) ? null : _addToFlashcards,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('افزودن به فلش‌کارت'),
            ),
            const SizedBox(height: 8),
            Text(
              'تلفظ و نقش دستوری کلمه با هوش مصنوعی در مرحله ۵ کامل می‌شود.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// نمایش تصاویر چند صفحه‌ای با نشانگر «صفحهٔ X از N».
class _ImagePages extends StatefulWidget {
  final List<String> imagePaths;

  const _ImagePages({required this.imagePaths});

  @override
  State<_ImagePages> createState() => _ImagePagesState();
}

class _ImagePagesState extends State<_ImagePages> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 220,
          child: PageView.builder(
            itemCount: widget.imagePaths.length,
            onPageChanged: (index) => setState(() => _page = index),
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Image.file(
                  File(widget.imagePaths[index]),
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) =>
                      const Center(child: Text('تصویر پیدا نشد')),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'صفحهٔ ${_faDigits('${_page + 1}')} از '
          '${_faDigits('${widget.imagePaths.length}')}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// تاریخ و ساعت میلادی با ارقام فارسی.
/// تبدیل شمسی در مرحله‌ی بعد اضافه می‌شود.
String _faDateTime(DateTime dt) {
  return '${_faDigits('${dt.year}')}/${_faDigits('${dt.month}')}/'
      '${_faDigits('${dt.day}')}  ${_faDigits('${dt.hour}')}:'
      '${_faDigits('${dt.minute}')}';
}

/// تبدیل ارقام لاتین به فارسی.
String _faDigits(String input) {
  const digits = '۰۱۲۳۴۵۶۷۸۹';
  return input.replaceAllMapped(
    RegExp(r'[0-9]'),
    (match) => digits[int.parse(match.group(0)!)],
  );
}
