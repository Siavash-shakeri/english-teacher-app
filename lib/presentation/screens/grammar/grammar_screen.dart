// lib/presentation/screens/grammar/grammar_screen.dart
//
// صفحهٔ اصلی «قواعد من» (مرحلهٔ ۴ — قواعد).
//
// - قواعد حساب فعال، گروه‌بندی‌شده بر اساس دسته
// - جست‌وجو در عنوان/دسته/توضیح
// - فیلتر «فقط ستاره‌دارها»
// - ستاره‌دار کردن و حذف (با تأیید) هر قاعده
// - دکمهٔ شناور برای «افزودن قاعدهٔ دستی»
// - حالت خالی با راهنمای فارسی؛ بارگذاری اسکلتی (skeleton)

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:english_teacher/data/grammar/local_grammar_repository.dart';
import 'package:english_teacher/domain/models/grammar_rule.dart';
import 'package:english_teacher/presentation/screens/grammar/grammar_rule_detail_screen.dart';
import 'package:english_teacher/presentation/screens/grammar/manual_rule_sheet.dart';
import 'package:english_teacher/presentation/widgets/fa_digits.dart';

/// دسته‌های پیشنهادی برای قاعدهٔ جدید (قابل تایپ دستی هم هست).
const List<String> kSuggestedCategories = [
  'زمان‌ها',
  'حروف اضافه',
  'جملات شرطی',
  'افعال کمکی',
  'حروف تعریف',
  'صفت و قید',
  'جملهٔ مجهول',
  'سایر',
];

/// صفحهٔ «قواعد من»: فهرست قواعد گرامری حساب فعال.
class GrammarScreen extends StatefulWidget {
  const GrammarScreen({super.key});

  @override
  State<GrammarScreen> createState() => _GrammarScreenState();
}

class _GrammarScreenState extends State<GrammarScreen> {
  final _repo = LocalGrammarRepository();
  final _searchController = TextEditingController();

  bool _loading = true;
  String? _loadError;
  List<GrammarRule> _rules = [];
  bool _starredOnly = false;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  /// بارگذاری مجدد قواعد از دیتابیس محلی.
  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final rules = await _repo.listRules();
      if (!mounted) return;
      setState(() {
        _rules = rules;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError = 'بارگذاری قواعد ناموفق بود؛ دوباره تلاش کن.';
        _loading = false;
      });
    }
  }

  /// جست‌وجو با کمی تأخیر تا با هر حرف، کوئری به دیتابیس نزنیم.
  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () async {
      final query = value.trim();
      try {
        final rules =
            query.isEmpty ? await _repo.listRules() : await _repo.searchRules(query);
        if (!mounted) return;
        setState(() => _rules = rules);
      } catch (_) {
        // خطای جست‌وجو را ساکت رد می‌کنیم؛ فهرست قبلی می‌ماند
      }
    });
  }

  /// قواعد قابل‌نمایش پس از اعمال فیلتر ستاره.
  List<GrammarRule> get _visibleRules =>
      _starredOnly ? _rules.where((r) => r.isStarred).toList() : _rules;

  /// گروه‌بندی قواعد بر اساس دسته (مرتب).
  Map<String, List<GrammarRule>> get _grouped {
    final map = <String, List<GrammarRule>>{};
    for (final rule in _visibleRules) {
      map.putIfAbsent(rule.category, () => []).add(rule);
    }
    return Map.fromEntries(
      map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
  }

  /// باز کردن برگهٔ افزودن قاعدهٔ دستی.
  Future<void> _openManualAdd() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const ManualRuleSheet(),
    );
    if (saved == true && mounted) {
      await _reload();
    }
  }

  /// رفتن به صفحهٔ جزئیات قاعده؛ بعد از برگشت فهرست تازه می‌شود.
  Future<void> _openDetail(GrammarRule rule) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GrammarRuleDetailScreen(rule: rule),
      ),
    );
    if (mounted) {
      await _reload();
    }
  }

  /// تغییر وضعیت ستارهٔ یک قاعده.
  Future<void> _toggleStar(GrammarRule rule) async {
    try {
      await _repo.setStarred(rule.id, !rule.isStarred);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تغییر ستاره ناموفق بود؛ دوباره تلاش کن.')),
      );
      return;
    }
    await _reload();
  }

  /// حذف قاعده با گرفتن تأیید.
  Future<void> _deleteRule(GrammarRule rule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف قاعده'),
        content: Text('«${rule.title}» از «قواعد من» حذف شود؟'),
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
      await _repo.deleteRule(rule.id);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حذف ناموفق بود؛ دوباره تلاش کن.')),
      );
      return;
    }
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('قواعد من')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'جست‌وجو در قواعد…',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('⭐ فقط ستاره‌دارها'),
                  selected: _starredOnly,
                  onSelected: (v) => setState(() => _starredOnly = v),
                ),
                const Spacer(),
                if (!_loading && _loadError == null)
                  Text(
                    '${toFaDigits('${_visibleRules.length}')} قاعده',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          const Divider(height: 8),
          Expanded(child: _buildBody()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openManualAdd,
        icon: const Icon(Icons.add),
        label: const Text('قاعدهٔ دستی'),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return _buildSkeleton();
    if (_loadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_loadError!),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _reload,
              child: const Text('تلاش دوباره'),
            ),
          ],
        ),
      );
    }
    final grouped = _grouped;
    if (grouped.isEmpty) return _buildEmptyState();
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
        children: [
          for (final entry in grouped.entries) ...[
            _buildCategoryHeader(entry.key, entry.value.length),
            const SizedBox(height: 4),
            for (final rule in entry.value) _buildRuleTile(rule),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  /// حالت خالی: راهنمای فارسی برای شروع.
  Widget _buildEmptyState() {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_outlined,
                size: 72, color: colorScheme.primary),
            const SizedBox(height: 16),
            const Text(
              'هنوز قاعده‌ای ثبت نشده',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            const Text(
              'بعد از تحلیل خودکار هر مشق (از مرحلهٔ ۵)، قواعدش اینجا '
              'دسته‌بندی و ذخیره می‌شوند — و هیچ‌وقت تکراری ثبت نمی‌شوند.\n'
              'تا آن موقع، با دکمهٔ «قاعدهٔ دستی» خودت اضافه کن.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// اسکلت بارگذاری: کارت‌های خاکستری چشمک‌زن.
  Widget _buildSkeleton() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: List.generate(
        6,
        (_) => const _SkeletonCard(),
      ),
    );
  }

  Widget _buildCategoryHeader(String category, int count) {
    return Row(
      children: [
        Text(
          category,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            toFaDigits('$count'),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSecondaryContainer,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRuleTile(GrammarRule rule) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        title: Text(rule.title),
        subtitle: rule.formula == null || rule.formula!.isEmpty
            ? null
            : Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  rule.formula!,
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.left,
                ),
              ),
        leading: IconButton(
          icon: Icon(
            rule.isStarred ? Icons.star : Icons.star_border,
            color: rule.isStarred
                ? Theme.of(context).colorScheme.primary
                : null,
          ),
          onPressed: () => _toggleStar(rule),
          tooltip: rule.isStarred ? 'برداشتن ستاره' : 'ستاره‌دار کردن',
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _deleteRule(rule),
          tooltip: 'حذف',
        ),
        onTap: () => _openDetail(rule),
      ),
    );
  }
}

/// کارت اسکلتی چشمک‌زن برای حالت بارگذاری.
class _SkeletonCard extends StatefulWidget {
  const _SkeletonCard();

  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Opacity(
          opacity: 0.25 + 0.35 * _controller.value,
          child: Container(
            height: 64,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      },
    );
  }
}
