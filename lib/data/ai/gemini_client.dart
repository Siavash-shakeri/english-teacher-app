// lib/data/ai/gemini_client.dart
//
// کلاینت مشترک Gemini (REST v1beta) برای مرحلهٔ ۵.
// بدون هیچ وابستگی به SDK رسمی — فقط package:http.
// کلید از سازنده گرفته می‌شود و هیچ‌وقت لاگ یا در خطا چاپ نمی‌شود.
//
// مدل‌های پیش‌فرض بر اساس وضعیت اکتبر ۲۰۲۶:
// - gemini-2.0-flash در ژوئن ۲۰۲۶ خاموش شد؛ استفاده نکنید
// - gemini-2.5-flash برای پروژه‌های جدید محدود است (404 برمی‌گرداند)
// پس پیش‌فرض امن: gemini-3.8-flash و جایگزین‌ها gemini-3.7/3.6-flash.

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// خطای فارسیِ قابل نمایش به کاربر.
class GeminiException implements Exception {
  final String persianMessage;
  final int? statusCode;
  const GeminiException(this.persianMessage, {this.statusCode});

  @override
  String toString() => persianMessage;
}

/// نقش‌های پیام در تاریخچهٔ گفت‌وگو.
enum GeminiRole { user, model }

/// یک پیام برای ساختن history در generateContent.
class GeminiMessage {
  final GeminiRole role;
  final String text;
  const GeminiMessage(this.role, this.text);
}

/// کلاینت مشترک Gemini — ساختنی با کلید کاربر.
class GeminiClient {
  static const String baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  /// مدل‌های Flash معتبر (اکتبر ۲۰۲۶)؛ اولی پیش‌فرض است.
  static const List<String> flashModels = [
    'gemini-3.8-flash',
    'gemini-3.7-flash',
    'gemini-3.6-flash',
    'gemini-3.5-flash',
  ];

  final String apiKey;
  final String model;
  final http.Client _http;

  GeminiClient({
    required this.apiKey,
    this.model = 'gemini-3.8-flash',
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'x-goog-api-key': apiKey,
      };

  /// تولید متن غیراستریمینگ.
  ///
  /// [systemPrompt] دستور سیستمی فارسی، [history] تاریخچهٔ کوتاه،
  /// [userMessage] پیام جاری.
  Future<String> generateContent({
    required String systemPrompt,
    required String userMessage,
    List<GeminiMessage> history = const [],
  }) async {
    final body = _buildBody(
      systemPrompt: systemPrompt,
      history: history,
      userMessage: userMessage,
    );
    http.Response res;
    try {
      res = await _http
          .post(
            Uri.parse('$baseUrl/$model:generateContent'),
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 60));
    } on TimeoutException {
      throw const GeminiException(
        'زمان پاسخ‌گویی تمام شد؛ اینترنت را بررسی کن و دوباره تلاش کن',
      );
    } catch (_) {
      throw const GeminiException(
        'اتصال به اینترنت برقرار نشد؛ اینترنت را بررسی کن',
      );
    }
    if (res.statusCode != 200) {
      throw GeminiException(_persianError(res.statusCode, res.body),
          statusCode: res.statusCode);
    }
    return _extractText(res.body);
  }

  /// تولید متن استریمینگ — هر chunk متن تازه را yield می‌کند.
  Stream<String> generateContentStream({
    required String systemPrompt,
    required String userMessage,
    List<GeminiMessage> history = const [],
  }) async* {
    final body = _buildBody(
      systemPrompt: systemPrompt,
      history: history,
      userMessage: userMessage,
    );
    http.StreamedResponse res;
    try {
      final req = http.Request(
        'POST',
        Uri.parse('$baseUrl/$model:streamGenerateContent?alt=sse'),
      );
      req.headers.addAll(_headers);
      req.body = jsonEncode(body);
      res = await _http.send(req).timeout(const Duration(seconds: 60));
    } on TimeoutException {
      throw const GeminiException(
        'زمان پاسخ‌گویی تمام شد؛ اینترنت را بررسی کن و دوباره تلاش کن',
      );
    } catch (_) {
      throw const GeminiException(
        'اتصال به اینترنت برقرار نشد؛ اینترنت را بررسی کن',
      );
    }
    if (res.statusCode != 200) {
      final errBody = await res.stream.bytesToString();
      throw GeminiException(_persianError(res.statusCode, errBody),
          statusCode: res.statusCode);
    }
    // پاسخ SSE: خط‌هایی مثل `data: {...}`
    await for (final line in res.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      final trimmed = line.trim();
      if (!trimmed.startsWith('data:')) continue;
      final payload = trimmed.substring(5).trim();
      if (payload == '[DONE]') break;
      try {
        final chunk = _extractText(payload);
        if (chunk.isNotEmpty) yield chunk;
      } catch (_) {
        // chunk ناقص؛ نادیده بگیر
      }
    }
  }

  /// تولید متن از تصویر (برای Gemini Vision در اسکن) — base64 تصویر JPEG/PNG.
  Future<String> generateContentWithImage({
    required String prompt,
    required String imageBase64,
    required String mimeType,
  }) async {
    final body = {
      'system_instruction': {
        'parts': [
          {'text': prompt}
        ]
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {
              'inline_data': {'mime_type': mimeType, 'data': imageBase64}
            },
            {'text': 'متن دست‌نویس این تصویر را دقیق و تمیز تایپ کن.'}
          ]
        }
      ],
      'generationConfig': {'temperature': 0.2, 'maxOutputTokens': 4096},
    };
    http.Response res;
    try {
      res = await _http
          .post(
            Uri.parse('$baseUrl/$model:generateContent'),
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(minutes: 2));
    } on TimeoutException {
      throw const GeminiException(
        'زمان پاسخ‌گویی تمام شد؛ اینترنت را بررسی کن و دوباره تلاش کن',
      );
    } catch (_) {
      throw const GeminiException(
        'اتصال به اینترنت برقرار نشد؛ اینترنت را بررسی کن',
      );
    }
    if (res.statusCode != 200) {
      throw GeminiException(_persianError(res.statusCode, res.body),
          statusCode: res.statusCode);
    }
    return _extractText(res.body);
  }

  Map<String, Object?> _buildBody({
    required String systemPrompt,
    required List<GeminiMessage> history,
    required String userMessage,
  }) {
    return {
      'system_instruction': {
        'parts': [
          {'text': systemPrompt}
        ]
      },
      'contents': [
        for (final m in history)
          {
            'role': m.role == GeminiRole.user ? 'user' : 'model',
            'parts': [
              {'text': m.text}
            ],
          },
        {
          'role': 'user',
          'parts': [
            {'text': userMessage}
          ],
        },
      ],
      'generationConfig': {'temperature': 0.7, 'maxOutputTokens': 2048},
    };
  }

  /// استخراج متن از پاسخ JSON (غیراستریمینگ یا یک chunk).
  static String _extractText(String jsonBody) {
    final decoded = jsonDecode(jsonBody) as Map<String, dynamic>;
    final candidates = decoded['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) return '';
    final content = candidates.first['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>?;
    if (parts == null) return '';
    final buffer = StringBuffer();
    for (final p in parts) {
      final t = (p as Map<String, dynamic>)['text'];
      if (t is String) buffer.write(t);
    }
    return buffer.toString();
  }

  /// نگاشت کد خطا به پیام فارسی — بدون افشای کلید یا جزئیات فنی.
  static String _persianError(int code, String body) {
    if (code == 400) {
      if (body.contains('API key not valid') ||
          body.contains('API_KEY_INVALID')) {
        return 'کلید API معتبر نیست؛ کلید را در تنظیمات بررسی کن';
      }
      return 'درخواست نامعتبر بود؛ دوباره تلاش کن';
    }
    if (code == 401 || code == 403) {
      return 'کلید API پذیرفته نشد؛ کلید را در تنظیمات بررسی و جایگزین کن';
    }
    if (code == 404) {
      return 'مدل انتخاب‌شده در دسترس نیست؛ مدل دیگری را در تنظیمات انتخاب کن';
    }
    if (code == 429) {
      return 'سهمیهٔ امروز تمام شده؛ کمی بعد دوباره تلاش کن';
    }
    if (code >= 500) {
      return 'سرور گوگل موقتاً مشکل دارد؛ کمی بعد دوباره تلاش کن';
    }
    return 'خطای ناشناخته رخ داد (کد $code)؛ دوباره تلاش کن';
  }

  void close() => _http.close();
}
