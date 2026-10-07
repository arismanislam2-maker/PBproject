import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../shared/providers/user_provider.dart';
import '../../data/openrouter_service.dart';

class AiAccountChatPage extends StatefulWidget {
  const AiAccountChatPage({super.key});

  @override
  State<AiAccountChatPage> createState() => _AiAccountChatPageState();
}

class _ChatSession {
  _ChatSession({
    required this.id,
    required this.title,
    List<Map<String, String>>? messages,
    DateTime? updatedAt,
  })  : messages = messages ?? [],
        updatedAt = updatedAt ?? DateTime.now();

  final String id;
  final String title;
  final List<Map<String, String>> messages;
  DateTime updatedAt;

  factory _ChatSession.fromJson(Map<dynamic, dynamic> json) {
    final messages = (json['messages'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((item) => <String, String>{
              'role': item['role']?.toString() ?? '',
              'content': item['content']?.toString() ?? '',
            })
        .where((item) => item['role'] == 'user' || item['role'] == 'assistant')
        .toList();
    return _ChatSession(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'แชท',
      messages: messages,
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'updatedAt': updatedAt.toIso8601String(),
      };
}

class _AiAccountChatPageState extends State<AiAccountChatPage> {
  static const brown = Color(0xFF5A3A28);
  static const cream = Color(0xFFF8F4EE);
  final _questionController = TextEditingController();
  final _scrollController = ScrollController();
  final _service = OpenRouterService();
  final List<_ChatSession> _sessions = [];
  List<Map<String, String>> _messages = [];
  _ChatSession? _activeSession;
  bool _sending = false;
  bool _loadingHistory = true;
  int? _userId;
  int _resetRevision = -1;
  int _nextChatNumber = 1;
  static const _selectedModelId = OpenRouterService.defaultModel;

  String? get _sessionsKey => _userId == null ? null : 'ai_chat_sessions_$_userId';
  String? get _counterKey => _userId == null ? null : 'ai_chat_counter_$_userId';
  String? get _activeKey => _userId == null ? null : 'ai_active_chat_$_userId';
  String _messagesKey(String sessionId) => 'ai_chat_messages_${_userId}_$sessionId';

  @override
  void initState() {
    super.initState();
    final userProvider = context.read<UserProvider>();
    _userId = userProvider.user?.id;
    _resetRevision = userProvider.resetRevision;
    _restoreSessions();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final revision = context.watch<UserProvider>().resetRevision;
    if (revision != _resetRevision) {
      _resetRevision = revision;
      _sessions.clear();
      _nextChatNumber = 1;
      _activate(_createSession());
      _saveSessions();
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  _ChatSession _createSession() {
    final session = _ChatSession(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: 'แชท $_nextChatNumber',
    );
    _nextChatNumber++;
    _sessions.insert(0, session);
    return session;
  }

  void _activate(_ChatSession session) {
    _activeSession = session;
    _messages = session.messages;
  }

  Future<void> _restoreSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _sessionsKey;
    if (key != null) {
      final encoded = prefs.getString(key);
      if (encoded != null) {
        try {
          final decoded = jsonDecode(encoded) as List<dynamic>;
          _sessions
            ..clear()
            ..addAll(decoded
                .whereType<Map>()
                .map(_ChatSession.fromJson)
                .where((session) => session.id.isNotEmpty));
          await Future.wait(_sessions.map((session) async {
            final messageJson = prefs.getString(_messagesKey(session.id));
            if (messageJson == null) return;
            try {
              final messageList = jsonDecode(messageJson) as List<dynamic>;
              session.messages.addAll(messageList
                  .whereType<Map>()
                  .map((item) => <String, String>{
                        'role': item['role']?.toString() ?? '',
                        'content': item['content']?.toString() ?? '',
                      })
                  .where((item) => item['role'] == 'user' || item['role'] == 'assistant'));
              if (session.messages.length > 20) {
                session.messages.removeRange(0, session.messages.length - 20);
              }
            } catch (_) {
              await prefs.remove(_messagesKey(session.id));
            }
          }));
        } catch (_) {
          await prefs.remove(key);
        }
      }
      _nextChatNumber = prefs.getInt(_counterKey!) ??
          _sessions.fold<int>(1, (max, session) {
            final match = RegExp(r'\d+').firstMatch(session.title);
            final number = int.tryParse(match?.group(0) ?? '') ?? 0;
            return number >= max ? number + 1 : max;
          });
      final activeId = prefs.getString(_activeKey!);
      _ChatSession? active;
      for (final session in _sessions) {
        if (session.id == activeId) {
          active = session;
          break;
        }
      }
      active ??= _sessions.isEmpty ? null : _sessions.first;
      if (active != null) {
        _activate(active);
      } else {
        final session = _createSession();
        _activate(session);
        final legacy = prefs.getString('ai_chat_history_$_userId');
        if (legacy != null) {
          try {
            final oldMessages = jsonDecode(legacy) as List<dynamic>;
            session.messages.addAll(oldMessages
                .whereType<Map>()
                .map((item) => <String, String>{
                      'role': item['role']?.toString() ?? '',
                      'content': item['content']?.toString() ?? '',
                    })
                .where((item) => item['role'] == 'user' || item['role'] == 'assistant'));
            if (session.messages.length > 20) {
              session.messages.removeRange(0, session.messages.length - 20);
            }
          } catch (_) {}
          await prefs.remove('ai_chat_history_$_userId');
        }
      }
      await _saveSessions();
    }
    if (!mounted) return;
    setState(() => _loadingHistory = false);
    _scrollToBottom();
  }

  Future<void> _saveSessions() async {
    final prefs = await SharedPreferences.getInstance();
    if (_sessionsKey == null) return;
    _sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await prefs.setString(
      _sessionsKey!,
      jsonEncode(_sessions.map((session) => session.toJson()).toList()),
    );
    if (_activeSession != null) {
      final messages = _activeSession!.messages;
      await prefs.setString(
        _messagesKey(_activeSession!.id),
        jsonEncode(messages.length > 20 ? messages.sublist(messages.length - 20) : messages),
      );
    }
    await prefs.setInt(_counterKey!, _nextChatNumber);
    final activeId = _activeSession?.id;
    if (activeId != null) await prefs.setString(_activeKey!, activeId);
  }

  Future<void> _newChat() async {
    if (_sending) return;
    setState(() => _activate(_createSession()));
    await _saveSessions();
    _scrollToBottom();
  }

  Future<void> _selectChat(_ChatSession session) async {
    if (_sending) return;
    setState(() {
      _activate(session);
      session.updatedAt = DateTime.now();
    });
    await _saveSessions();
    _scrollToBottom();
  }

  Future<bool> _confirmDelete(_ChatSession session) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text('ลบ${session.title}?'),
            content: const Text('ลบข้อความทั้งหมดในแชทนี้อย่างถาวร'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('ยกเลิก'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('ลบแชท'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _deleteChat(_ChatSession session) async {
    if (_sending) return;
    if (!await _confirmDelete(session) || !mounted) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_messagesKey(session.id));
    setState(() {
      _sessions.removeWhere((item) => item.id == session.id);
      if (_activeSession?.id == session.id) {
        _activate(_sessions.isEmpty ? _createSession() : _sessions.first);
      }
    });
    await _saveSessions();
  }

  Future<void> _showChatHistory() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cream,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .72,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text('ประวัติแชท', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
                    IconButton(
                      tooltip: 'เริ่มแชทใหม่',
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _newChat();
                      },
                      icon: const Icon(Icons.add_comment_outlined),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StatefulBuilder(
                  builder: (context, setSheetState) => ListView.builder(
                    itemCount: _sessions.length,
                    itemBuilder: (context, index) {
                      final session = _sessions[index];
                      final selected = session.id == _activeSession?.id;
                      return ListTile(
                        selected: selected,
                        leading: const Icon(Icons.chat_bubble_outline),
                        title: Text(session.title),
                        subtitle: Text('${session.messages.where((m) => m['role'] == 'user').length} ข้อความ'),
                        onTap: _sending
                            ? null
                            : () {
                                Navigator.pop(sheetContext);
                                _selectChat(session);
                              },
                        trailing: IconButton(
                          tooltip: 'ลบ ${session.title}',
                          onPressed: _sending
                              ? null
                              : () async {
                                  await _deleteChat(session);
                                  if (mounted) setSheetState(() {});
                                },
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitQuestion() async {
    final question = _questionController.text.trim();
    if (question.isEmpty || _sending) return;
    final userId = _userId;
    if (userId == null || _activeSession == null) {
      _showError('กรุณาเข้าสู่ระบบก่อนใช้งาน AI');
      return;
    }

    setState(() {
      _messages.add({'role': 'user', 'content': question});
      _messages.add({'role': 'assistant', 'content': ''});
      _activeSession!.updatedAt = DateTime.now();
      _questionController.clear();
      _sending = true;
    });
    _scrollToBottom();
    try {
      final conversation = _messages
          .take(_messages.length - 1)
          .map((message) => Map<String, String>.from(message))
          .toList();
      await for (final chunk in _service.answerStream(
        userId: userId,
        conversation: conversation,
        selectedModel: _selectedModelId,
      )) {
        if (!mounted) return;
        setState(() {
          _messages.last['content'] = (_messages.last['content'] ?? '') + chunk;
        });
        _scrollToBottom();
      }
      await _saveSessions();
    } catch (error) {
      if (!mounted) return;
      final message = error.toString()
          .replaceFirst('Bad state: ', '')
          .replaceFirst('FormatException: ', '')
          .replaceFirst('HttpException: ', '')
          .replaceFirst('Exception: ', '');
      setState(() {
        if (_messages.last['content']!.isEmpty) {
          _messages.last['content'] = 'ขออภัย: $message';
        } else {
          _messages.add({'role': 'assistant', 'content': 'ขออภัย การตอบกลับถูกขัดจังหวะ'});
        }
      });
      await _saveSessions();
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        _scrollToBottom();
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _askQuickQuestion(String question) {
    if (_sending || _loadingHistory) return;
    _questionController.text = question;
    _submitQuestion();
  }

  Widget _buildQuickChip(String label, [String? query]) {
    final text = query ?? label.replaceFirst(RegExp(r'^[^\s]+\s+'), '');
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(label, style: const TextStyle(fontSize: 12.5, color: brown, fontWeight: FontWeight.w500)),
        backgroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFFE0D7CE)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        onPressed: _sending || _loadingHistory ? null : () => _askQuickQuestion(text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        backgroundColor: brown,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        title: Text(
          _activeSession?.title ?? 'ผู้ช่วยการเงิน MyFinance',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _loadingHistory || _sending ? null : _showChatHistory,
            tooltip: 'ประวัติแชท',
            icon: const Icon(Icons.forum_outlined),
          ),
          IconButton(
            onPressed: _loadingHistory || _sending ? null : _newChat,
            tooltip: 'เริ่มแชทใหม่',
            icon: const Icon(Icons.add_comment_outlined),
          ),
          IconButton(
            onPressed: _loadingHistory || _sending || _activeSession == null
                ? null
                : () => _deleteChat(_activeSession!),
            tooltip: 'ลบแชทนี้',
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loadingHistory
                ? const Center(child: CircularProgressIndicator(color: brown))
                : _messages.isEmpty
                    ? Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: const BoxDecoration(
                                  color: Color(0x1F5A3A28),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.savings_outlined, size: 40, color: brown),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'ผู้ช่วยการเงิน MyFinance',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: brown),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'วิเคราะห์รายรับ-รายจ่าย ตรวจสอบยอดเงิน และวางแผนการเงินจากข้อมูลจริงในแอปของคุณ',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.black54, height: 1.5, fontSize: 13.5),
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                'แตะเพื่อถามข้อมูลด่วน',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: brown),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                alignment: WrapAlignment.center,
                                children: [
                                  _buildQuickChip('💰 ยอดเงินคงเหลือ'),
                                  _buildQuickChip('📊 สรุปรายรับ-รายจ่าย'),
                                  _buildQuickChip('💸 หมวดหมู่จ่ายเยอะสุด'),
                                  _buildQuickChip('🎯 เป้าหมายการออม'),
                                  _buildQuickChip('💡 แบ่งเงินสูตร 50/30/20'),
                                  _buildQuickChip('📝 รายการล่าสุด'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length + (_sending ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (_sending && index == _messages.length) {
                            return const Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: brown),
                                ),
                              ),
                            );
                          }
                          final message = _messages[index];
                          final isUser = message['role'] == 'user';
                          return Align(
                            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                              constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .82),
                              decoration: BoxDecoration(
                                color: isUser ? brown : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: isUser
                                    ? null
                                    : const [
                                        BoxShadow(
                                          color: Color(0x0A000000),
                                          blurRadius: 4,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                              ),
                              child: SelectableText(
                                message['content'] ?? '',
                                style: TextStyle(color: isUser ? Colors.white : Colors.black87, height: 1.4),
                              ),
                            ),
                          );
                        },
                      ),
          ),
          if (_messages.isNotEmpty)
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _buildQuickChip('💰 ยอดเงินคงเหลือ'),
                  _buildQuickChip('📊 สรุปเดือนนี้', 'สรุปรายรับ-รายจ่าย'),
                  _buildQuickChip('💸 จ่ายอะไรเยอะสุด', 'หมวดหมู่จ่ายเยอะสุด'),
                  _buildQuickChip('🎯 เป้าหมายการออม'),
                  _buildQuickChip('💡 สูตร 50/30/20', 'แบ่งเงินสูตร 50/30/20'),
                  _buildQuickChip('📝 รายการล่าสุด'),
                ],
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _questionController,
                      onSubmitted: (_) => _submitQuestion(),
                      textInputAction: TextInputAction.send,
                      decoration: InputDecoration(
                        hintText: 'ถามเรื่องเงิน เช่น ยอดเงินเหลือเท่าไหร่…',
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending || _loadingHistory ? null : _submitQuestion,
                    style: IconButton.styleFrom(backgroundColor: brown, foregroundColor: Colors.white),
                    icon: const Icon(Icons.send_rounded),
                    tooltip: 'ส่งคำถาม',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

