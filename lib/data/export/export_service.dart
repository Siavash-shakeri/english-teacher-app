// lib/data/export/export_service.dart
//
// سرویس خروجی مرحلهٔ ۷: PDF فارسی (راست‌به‌چپ) و JSON.
//
// خواستهٔ صریح کاربر (۲۰۲۶-۱۰-۲۲): «بعدش بتونم هم pdf بگیرن»
// خروجی شامل: مشق‌ها (+ متن استخراج‌شده)، «قواعد من»، واژگان/فلش‌کارت‌ها.
//
// فونت: وزیرمتن از PdfGoogleFonts (اولین بار به اینترنت نیاز دارد و
// بعد در حافظهٔ نهان می‌ماند). بدون اینترنت، خطای فارسی می‌دهیم و
// چیزی جعلی تولید نمی‌کنیم.

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:english_teacher/data/auth/local_auth_repository.dart';
import 'package:english_teacher/data/local/database_helper.dart';
import 'package:english_teacher/presentation/widgets/fa_digits.dart';

/// خطای فارسی قابل نمایش برای مشکلات خروجی.
class ExportException implements Exception {
  final String message;
  const ExportException(this.message);
  @override
  String toString() => message;
}

/// سرویس خروجی PDF و JSON برای حساب فعال.
class ExportService {
  ExportService._();

  static final ExportService instance = ExportService._();

  // ───────────────────────── PDF ─────────────────────────

  /// ساخت PDF فارسی و برگرداندن فایل آن.
  Future<File> exportPdf() async {
    final font = await _loadPersianFont();
    final bold = await _loadPersianFont(bold: true);

    final data = await _collectData();
    final doc = pw.Document();

    final baseStyle = pw.TextStyle(
      font: font,
      fontSize: 11,
    );
    final titleStyle = pw.TextStyle(
      font: bold,
      fontSize: 16,
    );
    final sectionStyle = pw.TextStyle(
      font: bold,
      fontSize: 13,
    );

    doc.addPage(
      pw.MultiPage(
        textDirection: pw.TextDirection.rtl,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (ctx) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(bottom: 12),
          child: pw.Text(
            'معلم انگلیسی من — خروجی ${toFaDigits(_today())}',
            style: titleStyle,
            textDirection: pw.TextDirection.rtl,
          ),
        ),
        build: (ctx) => [
          _pdfSection('مشق‌ها', sectionStyle, baseStyle,
              (data['homeworks'] as List).map((h) {
            final m = h as Map<String, Object?>;
            return '«${m['title']}»\n${m['extracted_text'] ?? ''}';
          }).toList()),
          _pdfSection('قواعد من', sectionStyle, baseStyle,
              (data['rules'] as List).map((r) {
            final m = r as Map<String, Object?>;
            final formula =
                (m['formula'] as String?)?.isNotEmpty == true
                    ? '\nفرمول: ${m['formula']}'
                    : '';
            return '«${m['title']}» (${m['category']})\n${m['explanation']}$formula';
          }).toList()),
          _pdfSection('واژگان', sectionStyle, baseStyle,
              (data['words'] as List).map((w) {
            final m = w as Map<String, Object?>;
            final example = (m['example'] as String?)?.isNotEmpty == true
                ? ' — مثال: ${m['example']}'
                : '';
            return '${m['word']} = ${m['meaning']}$example';
          }).toList()),
        ],
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}/english-teacher-${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await doc.save());
    return file;
  }

  pw.Widget _pdfSection(
    String title,
    pw.TextStyle sectionStyle,
    pw.TextStyle baseStyle,
    List<String> items,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.SizedBox(height: 10),
        pw.Text(title, style: sectionStyle, textDirection: pw.TextDirection.rtl),
        pw.Divider(),
        if (items.isEmpty)
          pw.Text('— خالی —', style: baseStyle, textDirection: pw.TextDirection.rtl)
        else
          for (final item in items) ...[
            pw.Text(item, style: baseStyle, textAlign: pw.TextAlign.right, textDirection: pw.TextDirection.rtl),
            pw.SizedBox(height: 6),
          ],
      ],
    );
  }

  /// بارگذاری فونت وزیرمتن (با پیام فارسی صادقانه در صورت نبود اینترنت).
  Future<pw.Font> _loadPersianFont({bool bold = false}) async {
    try {
      final data = bold
          ? await PdfGoogleFonts.vazirmatnBold()
          : await PdfGoogleFonts.vazirmatnRegular();
      return data;
    } catch (_) {
      throw const ExportException(
        'برای ساخت PDF فارسی، اولین بار به اینترنت نیاز است '
        '(دانلود فونت وزیرمتن).',
      );
    }
  }

  // ───────────────────────── JSON ─────────────────────────

  /// ساخت فایل JSON از همهٔ داده‌های حساب فعال.
  Future<File> exportJson() async {
    final data = await _collectData();
    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}/english-teacher-${DateTime.now().millisecondsSinceEpoch}.json');
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'app': 'english-teacher',
        'exported_at': DateTime.now().toIso8601String(),
        ...data,
      }),
    );
    return file;
  }

  // ───────────────────────── اشتراک‌گذاری ─────────────────────────

  /// باز کردن شیت اشتراک‌گذاری سیستم برای یک فایل.
  Future<void> shareFile(File file, {String? text}) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: text ?? 'خروجی «معلم انگلیسی من»',
      ),
    );
  }

  // ───────────────────────── جمع‌آوری داده ─────────────────────────

  Future<Map<String, List<Map<String, Object?>>>> _collectData() async {
    final db = await DatabaseHelper.instance.database;
    final accountId = await _activeAccountId();
    Future<List<Map<String, Object?>>> rows(String table, String cols) =>
        db.query(
          table,
          columns: cols.split(','),
          where: 'account_id = ? AND is_deleted = 0',
          whereArgs: [accountId],
          orderBy: 'created_at DESC',
        );

    return {
      'homeworks': await rows('homeworks', 'title,extracted_text,created_at'),
      'rules': await rows(
          'grammar_rules', 'category,title,explanation,formula,first_seen_at'),
      'words': await rows('words', 'word,meaning,example,created_at'),
    };
  }

  Future<String> _activeAccountId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(LocalAuthRepository.activeAccountKey);
    if (id == null || id.isEmpty) {
      throw const ExportException('حساب فعالی انتخاب نشده است.');
    }
    return id;
  }

  String _today() {
    final n = DateTime.now();
    return '${n.year}/${n.month}/${n.day}';
  }
}
