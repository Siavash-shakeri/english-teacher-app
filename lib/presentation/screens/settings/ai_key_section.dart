// lib/presentation/screens/settings/ai_key_section.dart
//
// بخش «کلید Google AI Studio» در تنظیمات:
// - نمایش وضعیت کلید (ماسک‌شده) + وارد/حذف کردن
// - انتخاب مدل (پیش‌فرض Flash، قابل تغییر)
// کلید فقط در حافظهٔ رمزنگاری‌شده ذخیره می‌شود و هیچ‌وقت کامل نمایش
// داده نمی‌شود.

import 'package:flutter/material.dart';

import 'package:english_teacher/data/ai/ai_gate.dart';
import 'package:english_teacher/data/ai/gemini_client.dart';
import 'package:english_teacher/data/ai/secure_key_store.dart';

/// کارت تنظیمات کلید و مدل Gemini.
class AiKeySection extends StatefulWidget {
  const AiKeySection({super.key});

  @override
  State<AiKeySection> createState() => _AiKeySectionState();
}

class _AiKeySectionState extends State<AiKeySection> {
  final _store = SecureKeyStore();
  final _keyController = TextEditingController();
  String? _maskedKey;
  String _model = GeminiClient.flashModels.first;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final key = await _store.readKey();
    final model = await AiGate.currentModel();
    if (!mounted) return;
    setState(() {
      _maskedKey =
          (key == null || key.isEmpty) ? null : SecureKeyStore.mask(key);
      _model = model;
      _loading = false;
    });
  }

  Future<void> _saveKey() async {
    final value = _keyController.text.trim();
    if (value.isEmpty) {
      _snack('اول کلید را وارد کن');
      return;
    }
    setState(() => _saving = true);
    await _store.saveKey(value);
    await AiGate.refreshKeyPresence();
    _keyController.clear();
    await _reload();
    if (!mounted) return;
    setState(() => _saving = false);
    _snack('کلید با موفقیت ذخیره شد ✅');
  }

  Future<void> _deleteKey() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('حذف کلید'),
        content: const Text(
          'کلید Gemini حذف شود؟ بدون کلید، بخش‌های آنلاین (چت، تحلیل خودکار، ترجمهٔ آنلاین) کار نمی‌کنند.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('انصراف'),
          ),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _store.deleteKey();
      await AiGate.refreshKeyPresence();
      await _reload();
      if (mounted) _snack('کلید حذف شد');
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.key_outlined),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'کلید Google AI Studio',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _maskedKey == null
                        ? Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                        : Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _maskedKey == null ? 'وارد نشده' : 'فعال ✅',
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_maskedKey != null) ...[
              Text(
                'کلید فعلی: $_maskedKey',
                textDirection: TextDirection.ltr,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _keyController,
              obscureText: true,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                labelText: 'کلید جدید',
                hintText: 'کلید را اینجا بچسبان',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.vpn_key_outlined),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: const Text('ذخیرهٔ کلید'),
                    onPressed: _saving ? null : _saveKey,
                  ),
                ),
                if (_maskedKey != null) ...[
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('حذف'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor:
                          Theme.of(context).colorScheme.error,
                    ),
                    onPressed: _deleteKey,
                  ),
                ],
              ],
            ),
            const Divider(height: 24),
            // انتخاب مدل
            const Text('مدل هوش مصنوعی'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _model,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.smart_toy_outlined),
              ),
              items: [
                for (final m in GeminiClient.flashModels)
                  DropdownMenuItem(
                    value: m,
                    child: Text(
                      m,
                      textDirection: TextDirection.ltr,
                    ),
                  ),
              ],
              onChanged: (v) async {
                if (v == null) return;
                await AiGate.setModel(v);
                if (mounted) {
                  setState(() => _model = v);
                  _snack('مدل «$v» انتخاب شد');
                }
              },
            ),
            const SizedBox(height: 12),
            const Text(
              'کلید را از Google AI Studio می‌گیری (رایگان). راهنمای قدم‌به‌قدم در فایل docs/ai-studio-key-fa.md هست. کلید فقط در حافظهٔ امن گوشی ذخیره می‌شود و هیچ‌وقت در کد یا اینترنت لو نمی‌رود.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
