// lib/presentation/screens/settings/sync_section.dart
//
// بخش «همگام‌سازی ابری» و «خروجی» در صفحهٔ تنظیمات (مرحلهٔ ۷).
//
// - اگر Firebase پیکربندی نشده باشد، وضعیت صادقانه نشان داده می‌شود و
//   دکمه‌ها خطای فارسی می‌دهند؛ اپ کاملاً آفلاین کار می‌کند.
// - «بازیابی» مخرب است: دیالوگ تأیید با توضیح روشن دارد.

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import 'package:english_teacher/data/export/export_service.dart';
import 'package:english_teacher/data/sync/firebase_service.dart';
import 'package:english_teacher/data/sync/sync_engine.dart';
import 'package:english_teacher/presentation/widgets/fa_digits.dart';

/// بخش همگام‌سازی ابری + خروجی در تنظیمات.
class SyncSection extends StatefulWidget {
  const SyncSection({super.key});

  @override
  State<SyncSection> createState() => _SyncSectionState();
}

class _SyncSectionState extends State<SyncSection> {
  final _engine = SyncEngine.instance;
  final _fb = FirebaseService.instance;
  final _export = ExportService.instance;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  bool _busy = false;
  double _progress = 0;
  String? _message;
  bool _messageIsError = false;
  bool _autoSync = true;
  int? _lastSyncAt;

  @override
  void initState() {
    super.initState();
    _loadState();
    // همگام‌سازی خودکار وقتی اینترنت برمی‌گردد
    _connectivitySub = Connectivity()
        .onConnectivityChanged
        .listen((results) async {
      if (results.any((r) => r != ConnectivityResult.none)) {
        final ok = await _engine.autoSyncIfNeeded();
        if (ok && mounted) {
          _loadState();
          _say('همگام‌سازی خودکار انجام شد ✅');
        }
      }
    });
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  Future<void> _loadState() async {
    final auto = await _engine.autoSyncEnabled;
    final last = await _engine.lastSyncAt;
    if (!mounted) return;
    setState(() {
      _autoSync = auto;
      _lastSyncAt = last;
    });
  }

  void _say(String message, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _message = message;
      _messageIsError = isError;
    });
  }

  Future<void> _runBackup() async {
    setState(() {
      _busy = true;
      _progress = 0;
      _message = null;
    });
    try {
      final result = await _engine.backupNow(
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      await _loadState();
      _say(result.message);
    } on FirebaseNotConfiguredException catch (e) {
      _say(e.message, isError: true);
    } catch (_) {
      _say('پشتیبان‌گیری ناموفق بود؛ اتصال اینترنت را بررسی کنید.',
          isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runRestore() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('بازیابی از ابر'),
        content: const Text(
          'داده‌های ابری با داده‌های این گوشی ادغام می‌شوند.\n'
          'قانون: نسخهٔ جدیدتر می‌ماند و نسخهٔ قبلی در لاگ تعارض نگه‌داری می‌شود.\n'
          'ادامه می‌دهید؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('بازیابی'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _busy = true;
      _progress = 0;
      _message = null;
    });
    try {
      final result = await _engine.restoreFromCloud(
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      await _loadState();
      _say(result.message);
    } on FirebaseNotConfiguredException catch (e) {
      _say(e.message, isError: true);
    } catch (_) {
      _say('بازیابی ناموفق بود؛ اتصال اینترنت را بررسی کنید.',
          isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runExport({required bool pdf}) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final file = pdf
          ? await _export.exportPdf()
          : await _export.exportJson();
      if (!mounted) return;
      setState(() => _busy = false);
      await _export.shareFile(file);
      _say(pdf ? 'فایل PDF ساخته شد ✅' : 'فایل JSON ساخته شد ✅');
    } on ExportException catch (e) {
      _say(e.message, isError: true);
      if (mounted) setState(() => _busy = false);
    } catch (_) {
      _say('ساخت خروجی ناموفق بود.', isError: true);
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final configured = _fb.isConfigured;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'همگام‌سازی ابری',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      configured
                          ? Icons.cloud_done_outlined
                          : Icons.cloud_off_outlined,
                      color: configured ? Colors.green : scheme.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        configured
                            ? 'متصل به Firebase ✅'
                            : 'Firebase پیکربندی نشده است',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                  ],
                ),
                if (!configured)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'برای فعال‌سازی، راهنمای docs/firebase-setup-fa.md را ببینید. بدون آن، اپ کاملاً آفلاین کار می‌کند.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  _lastSyncAt == null
                      ? 'آخرین همگام‌سازی: هرگز'
                      : 'آخرین همگام‌سازی: ${faDateTime(DateTime.fromMillisecondsSinceEpoch(_lastSyncAt!))}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                SwitchListTile(
                  title: const Text('همگام‌سازی خودکار با اینترنت'),
                  value: _autoSync,
                  onChanged: _busy
                      ? null
                      : (v) async {
                          await _engine.setAutoSyncEnabled(v);
                          if (mounted) setState(() => _autoSync = v);
                        },
                ),
                if (_busy) ...[
                  LinearProgressIndicator(value: _progress),
                  const SizedBox(height: 8),
                ],
                if (_message != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _message!,
                      style: TextStyle(
                        color: _messageIsError
                            ? scheme.error
                            : Colors.green,
                      ),
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.cloud_upload_outlined),
                        label: const Text('پشتیبان‌گیری الان'),
                        onPressed: _busy ? null : _runBackup,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.cloud_download_outlined),
                        label: const Text('بازیابی'),
                        onPressed: _busy ? null : _runRestore,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'خروجی',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('خروجی PDF'),
                    onPressed: _busy ? null : () => _runExport(pdf: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.data_object_outlined),
                    label: const Text('خروجی JSON'),
                    onPressed: _busy ? null : () => _runExport(pdf: false),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// دیالوگ «بازیابی از ابر» برای گوشی جدید (بعد از ورود موفق).
class SyncRestorePrompt {
  /// اگر ابر داده دارد و گوشی خالی است، پیشنهاد بازیابی می‌دهد.
  /// خروجی: true یعنی بازیابی انجام شد.
  static Future<bool> maybeShow(BuildContext context) async {
    final engine = SyncEngine.instance;
    try {
      if (!await engine.cloudHasData()) return false;
      if (!await engine.localIsEmpty()) return false;
    } catch (_) {
      return false;
    }
    if (!context.mounted) return false;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('بازیابی از ابر'),
        content: const Text(
          'در حساب ابری شما داده وجود دارد ولی این گوشی خالی است.\n'
          'می‌خواهید داده‌ها بازیابی شوند؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('فعلاً نه'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('بازیابی'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return false;
    try {
      await engine.restoreFromCloud();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('بازیابی از ابر کامل شد ✅')),
        );
      }
      return true;
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('بازیابی ناموفق بود؛ بعداً از تنظیمات تلاش کنید.')),
        );
      }
      return false;
    }
  }
}
