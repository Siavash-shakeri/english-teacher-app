import 'dart:io';
import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'package:english_teacher/data/homework/local_homework_repository.dart';
import 'package:english_teacher/data/ocr/ocr_service.dart';
import 'package:english_teacher/data/scan/image_cleanup.dart';

/// تبدیل ارقام انگلیسی به فارسی برای نمایش تاریخ و شمارهٔ صفحه.
String _faDigits(String input) {
  const en = '0123456789';
  const fa = '۰۱۲۳۴۵۶۷۸۹';
  final buf = StringBuffer();
  for (final ch in input.split('')) {
    final i = en.indexOf(ch);
    buf.write(i < 0 ? ch : fa[i]);
  }
  return buf.toString();
}

/// یک صفحهٔ اسکن‌شده: مسیر فایل تصویر (تمیزکاری‌شده) و متن تشخیص‌داده‌شده.
class _ScanPage {
  _ScanPage({required this.imagePath, required this.text});

  String imagePath;
  String text;
}

/// صفحهٔ اسکن مشق — مرحلهٔ ۲ اپ «معلم انگلیسی من»:
/// انتخاب تصویر از دوربین/گالری ← برش ← تمیزکاری و OCR ← بازبینی و ذخیره.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  /// ۰: انتخاب منبع، ۱: برش، ۲: پردازش، ۳: بازبینی و ذخیره.
  int _step = 0;

  final CropController _cropController = CropController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _textController = TextEditingController();

  /// بایت‌های تصویر انتخاب‌شده برای نمایش در ویجت Crop.
  Uint8List? _pickedBytes;

  /// صفحه‌های اسکن‌شدهٔ انباشته‌شده در این نشست.
  final List<_ScanPage> _pages = [];

  /// فایل کراپ‌شدهٔ در حال پردازش (برای دکمهٔ «تلاش مجدد»).
  File? _pendingFile;

  /// خطای آخرین پردازش؛ null یعنی هنوز خطایی رخ نداده (در حال پردازش).
  String? _processingError;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final date =
        '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}';
    _titleController.text = 'مشق ${_faDigits(date)}';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// مرحلهٔ ۰: انتخاب تصویر از دوربین یا گالری.
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked = await ImagePicker().pickImage(source: source);
      if (!mounted) return;
      // کاربر انصراف داد — در همان مرحلهٔ ۰ می‌مانیم.
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/scan_picked_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await file.writeAsBytes(bytes);
      if (!mounted) return;
      setState(() {
        _pickedBytes = bytes;
        _pendingFile = null;
        _processingError = null;
        _step = 1;
      });
    } catch (_) {
      _showSnack('انتخاب تصویر ناموفق بود، دوباره تلاش کن');
    }
  }

  /// مرحلهٔ ۱: نتیجهٔ برش — ذخیرهٔ بایت‌ها در فایل موقت و شروع پردازش.
  Future<void> _onCropped(CropResult result) async {
    final cropped = switch (result) {
      CropSuccess(:final croppedImage) => croppedImage,
      CropFailure() => null,
    };
    if (cropped == null) {
      if (!mounted) return;
      setState(() {
        _processingError = 'برش تصویر ناموفق بود';
        _step = 2;
      });
      return;
    }
    try {
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/scan_cropped_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await file.writeAsBytes(cropped);
      if (!mounted) return;
      setState(() {
        _step = 2;
        _processingError = null;
        _pendingFile = file;
      });
      await _process(file);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _processingError = 'برش تصویر ناموفق بود';
        _step = 2;
      });
    }
  }

  /// مرحلهٔ ۲: تمیزکاری تصویر و تشخیص متن (آفلاین با ML Kit).
  Future<void> _process(File croppedFile) async {
    try {
      final cleanPath = await ImageCleanup.cleanUp(croppedFile);
      if (!mounted) return;
      final text = await MlKitOcrEngine().recognizeText(cleanPath);
      if (!mounted) return;
      final page = _ScanPage(imagePath: cleanPath, text: text.trim());
      setState(() {
        _pages.add(page);
        _processingError = null;
        _textController.text = page.text;
        _step = 3;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _processingError = 'تشخیص متن ناموفق بود، دوباره تلاش کن';
      });
    }
  }

  void _retryProcess() {
    final file = _pendingFile;
    if (file == null) {
      setState(() => _step = 0);
      return;
    }
    setState(() => _processingError = null);
    _process(file);
  }

  /// ذخیرهٔ ویرایش‌های متن فعلی در آخرین صفحه، بعد برگشت به مرحلهٔ ۰.
  void _addAnotherPage() {
    if (_pages.isNotEmpty) {
      _pages.last.text = _textController.text;
    }
    setState(() {
      _pickedBytes = null;
      _pendingFile = null;
      _processingError = null;
      _step = 0;
    });
  }

  /// مرحلهٔ ۳: ذخیرهٔ مشق با به‌هم‌چسباندن متن همهٔ صفحه‌ها.
  Future<void> _saveHomework() async {
    if (_pages.isNotEmpty) {
      _pages.last.text = _textController.text;
    }
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showSnack('عنوان مشق را وارد کن');
      return;
    }
    if (_pages.isEmpty) return;
    setState(() => _saving = true);
    try {
      final merged = StringBuffer();
      for (var i = 0; i < _pages.length; i++) {
        if (i > 0) {
          merged.write('\n\n--- صفحهٔ ${_faDigits('${i + 1}')} ---\n\n');
        }
        merged.write(_pages[i].text);
      }
      await LocalHomeworkRepository().createHomework(
        title: title,
        imagePaths: _pages.map((p) => p.imagePath).toList(),
        extractedText: merged.toString(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('مشق ذخیره شد ✅')),
      );
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showSnack('ذخیرهٔ مشق ناموفق بود، دوباره تلاش کن');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('اسکن مشق'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'بستن',
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_step) {
      case 0:
        return _buildPickSource();
      case 1:
        return _buildCrop();
      case 2:
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _buildEngineSelector(),
            ),
            const Divider(),
            Expanded(child: _buildProcessing()),
          ],
        );
      case 3:
        return _buildReview();
      default:
        return _buildPickSource();
    }
  }

  /// مرحلهٔ ۰: دو دکمهٔ بزرگ دوربین و گالری.
  Widget _buildPickSource() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.document_scanner, size: 80),
            const SizedBox(height: 24),
            const Text('عکس مشقت را بگیر یا از گالری انتخاب کن'),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _pickImage(ImageSource.camera),
                icon: const Icon(Icons.camera_alt),
                label:
                    const Text('📷 دوربین', style: TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library),
                label:
                    const Text('🖼️ گالری', style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// مرحلهٔ ۱: برش تصویر.
  Widget _buildCrop() {
    final bytes = _pickedBytes;
    if (bytes == null) {
      return const Center(child: Text('تصویری انتخاب نشده است'));
    }
    return Column(
      children: [
        Expanded(
          child: Crop(
            image: bytes,
            controller: _cropController,
            onCropped: _onCropped,
            maskColor: Colors.black54,
            cornerDotBuilder: (_, __) => const DotControl(
              color: Colors.white,
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() => _step = 0),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('↩️ انتخاب دوباره'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _cropController.crop(),
                    icon: const Icon(Icons.check),
                    label: const Text('✅ ادامه'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// انتخاب موتور OCR: آفلاین فعال، آنلاین غیرفعال (مرحلهٔ ۵).
  Widget _buildEngineSelector() {
    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text('موتور تشخیص متن:'),
        ChoiceChip(
          label: const Text('آفلاین (ML Kit)'),
          selected: true,
          onSelected: (_) {},
        ),
        Tooltip(
          message: 'مرحلهٔ ۵',
          child: GestureDetector(
            onTap: () => _showSnack(
              GeminiVisionOcrEngine().unavailableReason,
            ),
            child: const ChoiceChip(
              label: Text('آنلاین (Gemini Vision)'),
              selected: false,
              // غیرفعال: ضربه به‌جای انتخاب، دلیل را در SnackBar نشان می‌دهد.
              onSelected: null,
            ),
          ),
        ),
      ],
    );
  }

  /// مرحلهٔ ۲: اسپینر پردازش یا نمایش خطا با «تلاش مجدد» و «بازگشت».
  Widget _buildProcessing() {
    if (_processingError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(_processingError!, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _retryProcess,
                    icon: const Icon(Icons.refresh),
                    label: const Text('تلاش مجدد'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: () => setState(() => _step = 0),
                    child: const Text('بازگشت'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('در حال تمیزکاری و تشخیص متن…'),
        ],
      ),
    );
  }

  /// مرحلهٔ ۳: بازبینی — عنوان، بندانگشتی صفحه‌ها، متن قابل ویرایش صفحهٔ آخر.
  Widget _buildReview() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'عنوان مشق',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          if (_pages.isNotEmpty)
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _pages.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final page = _pages[i];
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(page.imagePath),
                          width: 56,
                          height: 72,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        bottom: 2,
                        right: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _faDigits('${i + 1}'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          const SizedBox(height: 8),
          const Text(
            'متن همهٔ صفحه‌ها موقع ذخیره به هم می‌چسبد',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TextField(
              controller: _textController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(
                labelText: 'متن صفحهٔ آخر (قابل ویرایش)',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : _addAnotherPage,
                  icon: const Icon(Icons.add),
                  label: const Text('➕ افزودن صفحهٔ دیگر'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _saveHomework,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child:
                              CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: const Text('💾 ذخیره مشق'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
