// lib/presentation/screens/ai_tutor/ai_tutor_screen.dart
//
// صفحهٔ معلم هوش مصنوعی — چت با Gemini (مرحلهٔ ۵):
// - تاریخچهٔ گفت‌وگو برای هر حساب جداگانه (جدول chat_messages)
// - پاسخ استریمینگ با نشانگر «در حال فکر کردن…»
// - تزریق بافت: قواعد «قواعد من» + مشق‌های اخیر در دستور سیستمی
// - بدون کلید: کارت راهنمای ورود کلید در تنظیمات
// - پارامتر [initialPrompt] برای دکمه‌های «بپرس از هوش مصنوعی»

import 'package:flutter/material.dart';

import 'package:english_teacher/data/ai/ai_gate.dart';
import 'package:english_teacher/data/ai/context_builder.dart';
import 'package:english_teacher/data/ai/gemini_client.dart';
import 'package:english_teacher/data/ai/local_chat_repository.dart';
import 'package:english_teacher/domain/models/chat_message.dart';

/// صفحهٔ چت با معلم هوش مصنوعی.
class AiTutorScreen extends StatefulWidget {
  /// پیام اولیه (از دکمهٔ «بپرس از هوش مصنوعی») — اختیاری.
  final String? initialPrompt;

  const AiTutorScreen({super.key, this.initialPrompt});

  @override
  State<AiTutorScreen> createState() => _AiTutorScreenState();
}

class _AiTutorScreenState extends State<AiTutorScreen> {
  final _chatRepo = LocalChatRepository();
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  List<ChatMessage> _messages = [];
  bool _loading = true;
  bool _sending = false;
  bool _hasKey = false;
  String? _error;
  String? _failedPrompt;

  static const List<String> _quickPrompts = [
    'این جمله رو تصحیح کن',
    'این قاعده رو توضیح بده',
    '۵ مثال با ترجمه بزن',
    'اشتباهات رایج فارسی‌زبان‌ها چیه؟',
  ];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final has = await AiGate.client().then((c) {
      c?.close();
      return c != null;
    }).catchError((_) => false);
    if (!mounted) return;
    setState(() => _hasKey = has);
    if (has) {
      await _loadHistory();
    } else {
      setState(() => _loading = false);
    }
    // پیام اولیه از دکمهٔ «بپرس از هوش مصنوعی»
    final initial = widget.initialPrompt;
    if (initial != null && initial.isNotEmpty && mounted && has) {
      await _send(initial);
    }
  }

  Future<void> _loadHistory() async {
    try {
      final messages = await _chatRepo.listMessages();
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _loading = false;
      });
      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send([String? overrideText]) async {
    final text = (overrideText ?? _textController.text).trim();
    if (text.isEmpty || _sending) return;
    _textController.clear();
    setState(() {
      _sending = true;
      _error = null;
      _failedPrompt = null;
    });

    try {
      final client = await AiGate.client();
      if (client == null) {
        if (!mounted) return;
        setState(() {
          _hasKey = false;
          _sending = false;
        });
        return;
      }
      // ذخیرهٔ پیام کاربر
      final userMsg = await _chatRepo.addMessage(role: 'user', content: text);
      // پیام خالی مدل برای استریم
      var modelMsg = await _chatRepo.addMessage(role: 'model', content: '');
      if (!mounted) {
        client.close();
        return;
      }
      setState(() {
        _messages = [..._messages, userMsg, modelMsg];
      });
      _scrollToBottom();

      final systemPrompt = await ContextBuilder().buildSystemPrompt();
      final prior = _messages
          .where((m) => m.id != userMsg.id && m.id != modelMsg.id)
          .toList();
      final history = prior
          .sublist(prior.length > 10 ? prior.length - 10 : 0)
          .map((m) => GeminiMessage(
                m.isUser ? GeminiRole.user : GeminiRole.model,
                m.content,
              ))
          .toList();

      final buffer = StringBuffer();
      await for (final chunk in client.generateContentStream(
        systemPrompt: systemPrompt,
        userMessage: text,
        history: history,
      )) {
        buffer.write(chunk);
        if (!mounted) break;
        final updated = modelMsg.copyWith(
          content: buffer.toString(),
          updatedAt: DateTime.now(),
        );
        setState(() {
          _messages = [
            for (final m in _messages)
              if (m.id == modelMsg.id) updated else m,
          ];
        });
        modelMsg = updated;
        _scrollToBottom();
      }
      await _chatRepo.updateMessage(modelMsg.id, buffer.toString());
      client.close();
    } on GeminiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.persianMessage;
        _failedPrompt = text;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'خطای ناشناخته رخ داد؛ دوباره تلاش کن';
        _failedPrompt = text;
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _retry() async {
    final prompt = _failedPrompt;
    if (prompt == null) return;
    setState(() {
      _error = null;
      _failedPrompt = null;
    });
    await _send(prompt);
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('گفت‌وگوی جدید'),
        content: const Text('تاریخچهٔ گفت‌وگو با معلم پاک شود؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('انصراف'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('پاک کن'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _chatRepo.clearHistory();
      if (mounted) {
        setState(() {
          _messages = [];
          _error = null;
          _failedPrompt = null;
        });
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('معلم هوش مصنوعی'),
        actions: [
          IconButton(
            tooltip: 'گفت‌وگوی جدید',
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: _sending ? null : _clearHistory,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !_hasKey
              ? _buildNoKeyCard()
              : Column(
                  children: [
                    Expanded(
                      child: _messages.isEmpty
                          ? _buildEmptyState()
                          : ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.all(12),
                              itemCount: _messages.length,
                              itemBuilder: (ctx, i) =>
                                  _buildBubble(_messages[i]),
                            ),
                    ),
                    if (_error != null) _buildErrorBar(),
                    _buildQuickChips(),
                    _buildInputBar(),
                  ],
                ),
    );
  }

  /// کارت راهنمای ورود کلید وقتی کلیدی ذخیره نشده است.
  Widget _buildNoKeyCard() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.smart_toy_outlined, size: 56),
                const SizedBox(height: 16),
                const Text(
                  'برای صحبت با معلم هوش مصنوعی، اول کلید Google AI Studio را وارد کن',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'از نوار پایین، تب «تنظیمات» را بزن و در بخش «کلید Google AI Studio» کلیدت را ذخیره کن.',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.smart_toy_outlined, size: 56),
            const SizedBox(height: 12),
            const Text(
              'سلام! من معلم انگلیسی توام 🙂\nهر سوالی داری بپرس: معنی، گرامر، تصحیح جمله…',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'من به مشق‌ها و «قواعد من» تو دسترسی دارم',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBubble(ChatMessage message) {
    final isUser = message.isUser;
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        decoration: BoxDecoration(
          color:
              isUser ? scheme.primaryContainer : scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
        ),
        child: message.content.isEmpty && !isUser
            ? const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text('در حال فکر کردن…'),
                ],
              )
            : SelectableText(message.content),
      ),
    );
  }

  Widget _buildErrorBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(child: Text(_error ?? '')),
          TextButton(
            onPressed: _retry,
            child: const Text('تلاش دوباره'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          for (final prompt in _quickPrompts)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: ActionChip(
                label: Text(prompt),
                onPressed: _sending ? null : () => _send(prompt),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _textController,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: const InputDecoration(
                  hintText: 'سوالت را بپرس…',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(24)),
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: 'ارسال',
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send),
              onPressed: _sending ? null : () => _send(),
            ),
          ],
        ),
      ),
    );
  }
}
