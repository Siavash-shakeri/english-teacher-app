// lib/presentation/widgets/tappable_text.dart
//
// ویجت متن انگلیسی با واژه‌های قابل‌لمس برای قابلیت «ترجمه با لمس واژه».
// متن روی فاصله‌ها شکسته می‌شود؛ هر واژه با لمس، تمیزشده به شنونده تحویل داده می‌شود.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// متن انگلیسی که واژه‌هایش با لمس قابل انتخاب‌اند.
///
/// متن ورودی روی فاصله‌ها (whitespace) به تکه‌ها تقسیم می‌شود. هر تکه‌ای که
/// دست‌کم یک حرف یا رقم داشته باشد قابل‌لمس است؛ با لمس آن، واژهٔ تمیزشده
/// (حذف نقطه‌گذاری ابتدا و انتها، مثل `"Hello,"` ← `Hello`؛ آپاستروف میانی
/// مثل `"don't"` حفظ می‌شود) به [onWordTap] فرستاده می‌شود. تکه‌های خالصِ
/// نقطه‌گذاری (مثل `...`) قابل‌لمس نیستند و ساده نمایش داده می‌شوند.
class TappableText extends StatefulWidget {
  /// جملهٔ انگلیسی نمایشی.
  final String text;

  /// فراخوانی هنگام لمس یک واژه؛ واژهٔ تمیزشده را تحویل می‌گیرد.
  final void Function(String word) onWordTap;

  /// استایل پایهٔ متن؛ پیش‌فرض استایل پیش‌فرض متن زمینه.
  final TextStyle? style;

  /// استایل واژه‌های قابل‌لمس؛ پیش‌فرض همان [style]. خط زیر و رنگ اصلی
  /// تم (primary) روی آن اعمال می‌شود.
  final TextStyle? wordStyle;

  const TappableText({
    super.key,
    required this.text,
    required this.onWordTap,
    this.style,
    this.wordStyle,
  });

  @override
  State<TappableText> createState() => _TappableTextState();
}

class _TappableTextState extends State<TappableText> {
  /// نقطه‌گذاری ابتدا/انتها: هر چیزی به‌جز حرف، رقم و آپاستروف.
  static final RegExp _leadingPunct =
      RegExp(r'^[^\p{L}\p{N}\u0027]+', unicode: true);
  static final RegExp _trailingPunct =
      RegExp(r'[^\p{L}\p{N}\u0027]+$', unicode: true);

  /// آیا تکه دست‌کم یک حرف یا رقم دارد؟
  static final RegExp _hasWordChar = RegExp(r'[\p{L}\p{N}]', unicode: true);

  /// تشخیص‌دهنده‌های لمس، هم‌اندیس با تکه‌های متن؛ برای تکه‌های غیرقابل‌لمس null.
  ///
  /// فقط در [initState] و [didUpdateWidget] ساخته و در [dispose] آزاد می‌شوند؛
  /// هرگز داخل [build] ساخته نمی‌شوند.
  List<TapGestureRecognizer?> _recognizers = [];

  /// تمیزشدن تکه: حذف نقطه‌گذاری ابتدا و انتها؛ آپاستروف میانی حفظ می‌شود.
  static String cleanToken(String token) =>
      token.replaceAll(_leadingPunct, '').replaceAll(_trailingPunct, '');

  /// تکه‌ها: متن روی فاصله‌ها شکسته می‌شود؛ فاصله‌های تکراری ادغام می‌شوند.
  List<String> _tokens() {
    final trimmed = widget.text.trim();
    if (trimmed.isEmpty) return const [];
    return trimmed.split(RegExp(r'\s+'));
  }

  @override
  void initState() {
    super.initState();
    _rebuildRecognizers();
  }

  @override
  void didUpdateWidget(TappableText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _rebuildRecognizers();
    }
  }

  /// ساخت مجدد تشخیص‌دهنده‌ها به‌ازای واژه‌های قابل‌لمس متن جدید.
  void _rebuildRecognizers() {
    _disposeRecognizers();
    final tokens = _tokens();
    _recognizers = List<TapGestureRecognizer?>.generate(tokens.length, (i) {
      final token = tokens[i];
      if (!_hasWordChar.hasMatch(token)) return null;
      final cleaned = cleanToken(token);
      if (cleaned.isEmpty) return null;
      return TapGestureRecognizer()
        ..onTap = () => widget.onWordTap(cleaned);
    });
  }

  /// آزادسازی همهٔ تشخیص‌دهنده‌ها.
  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer?.dispose();
    }
    _recognizers = const [];
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = _tokens();
    // متن خالی: نشان‌گر خط تیره
    if (tokens.isEmpty) {
      return const Text('—');
    }

    final baseStyle = widget.style ?? DefaultTextStyle.of(context).style;
    final tappableStyle = (widget.wordStyle ?? baseStyle).copyWith(
      decoration: TextDecoration.underline,
      color: Theme.of(context).colorScheme.primary,
    );

    final children = <TextSpan>[];
    for (var i = 0; i < tokens.length; i++) {
      // حفظ یک فاصلهٔ تکی بین تکه‌ها
      if (i > 0) children.add(const TextSpan(text: ' '));
      final recognizer = _recognizers[i];
      children.add(TextSpan(
        text: tokens[i],
        style: recognizer == null ? baseStyle : tappableStyle,
        recognizer: recognizer,
      ));
    }

    // متن انگلیسی داخل چیدمان راست‌به‌چپ: جهت داخلی همیشه چپ‌به‌راست.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: RichText(
        textAlign: TextAlign.start,
        text: TextSpan(style: baseStyle, children: children),
      ),
    );
  }
}
