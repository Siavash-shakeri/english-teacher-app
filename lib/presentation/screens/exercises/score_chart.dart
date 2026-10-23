// lib/presentation/screens/exercises/score_chart.dart
//
// نمودار میله‌ای سادهٔ پیشرفت نمره‌ها (مرحلهٔ ۶).
// عمداً با CustomPainter رسم شده تا وابستگی جدید (مثل fl_chart)
// به پروژه اضافه نشود.

import 'package:flutter/material.dart';

import 'package:english_teacher/domain/models/exercise.dart';
import 'package:english_teacher/presentation/widgets/fa_digits.dart';

/// نمودار میله‌ای درصد نمره‌های اخیر (قدیمی‌ترین سمت چپ).
class ScoreChart extends StatelessWidget {
  /// نمره‌ها از جدیدترین به قدیمی‌ترین؛ حداکثر ۱۲ تای آخر رسم می‌شود.
  final List<ScoreRecord> scores;

  const ScoreChart({super.key, required this.scores});

  @override
  Widget build(BuildContext context) {
    final data = scores.reversed.take(12).toList();
    if (data.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('هنوز آزمونی ثبت نشده؛ نمودار بعد از اولین آزمون اینجا می‌آید 📊',
            textAlign: TextAlign.center),
      );
    }
    return SizedBox(
      height: 180,
      child: CustomPaint(
        painter: _ScoreChartPainter(
          values: data.map((s) => s.percent).toList(),
          labels: data.map((s) => toFaDigits('${s.takenAt.day}')).toList(),
          barColor: Theme.of(context).colorScheme.primary,
          gridColor:
              Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
          textColor: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _ScoreChartPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final Color barColor;
  final Color gridColor;
  final Color textColor;

  _ScoreChartPainter({
    required this.values,
    required this.labels,
    required this.barColor,
    required this.gridColor,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const bottomPad = 22.0;
    const topPad = 8.0;
    final chartH = size.height - bottomPad - topPad;
    final n = values.length;
    if (n == 0 || chartH <= 0) return;

    // خطوط راهنمای ۰٪، ۵۰٪، ۱۰۰٪
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (final frac in [0.0, 0.5, 1.0]) {
      final y = topPad + chartH * (1 - frac);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final slot = size.width / n;
    final barW = (slot * 0.55).clamp(8.0, 36.0);
    final barPaint = Paint()..color = barColor;
    final textPainter = TextPainter(textDirection: TextDirection.rtl);

    for (var i = 0; i < n; i++) {
      final h = chartH * (values[i] / 100).clamp(0.02, 1.0);
      final x = slot * i + (slot - barW) / 2;
      final y = topPad + chartH - h;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y, barW, h), const Radius.circular(4)),
        barPaint,
      );
      // برچسب روز زیر هر میله
      textPainter.text = TextSpan(
        text: labels[i],
        style: TextStyle(color: textColor, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(slot * i + (slot - textPainter.width) / 2,
            topPad + chartH + 6),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ScoreChartPainter old) =>
      old.values != values;
}
