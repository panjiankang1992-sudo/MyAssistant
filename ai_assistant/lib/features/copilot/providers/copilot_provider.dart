import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../../core/providers/core_providers.dart';
import '../../ai_settings/ai_model_provider.dart';
import '../../profile/profile_provider.dart';
import '../services/copilot_agent_service.dart';

enum ChatRole { user, assistant }

enum ChatMessageType { thinking, toolCall, result, error, text }

class ChatMessage {
  final String id;
  final ChatRole role;
  final String content;
  final ChatMessageType type;
  final DateTime timestamp;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.type,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'role': role.name,
    'content': content,
    'type': type.name,
    'timestamp': timestamp.toIso8601String(),
  };

  static ChatMessage fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return ChatMessage(
      id: json['id'] as String? ?? const Uuid().v4(),
      role: ChatRole.values.firstWhere(
        (item) => item.name == json['role'],
        orElse: () => ChatRole.assistant,
      ),
      content: json['content'] as String? ?? '',
      type: ChatMessageType.values.firstWhere(
        (item) => item.name == json['type'],
        orElse: () => ChatMessageType.text,
      ),
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? now
          : now,
    );
  }
}

class CopilotSession {
  final String id;
  final String title;
  final List<ChatMessage> messages;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CopilotSession({
    required this.id,
    required this.title,
    required this.messages,
    required this.createdAt,
    required this.updatedAt,
  });

  CopilotSession copyWith({
    String? title,
    List<ChatMessage>? messages,
    DateTime? updatedAt,
  }) {
    return CopilotSession(
      id: id,
      title: title ?? this.title,
      messages: messages ?? this.messages,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'messages': messages.map((item) => item.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  static CopilotSession fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    final messages = (json['messages'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ChatMessage.fromJson)
        .toList();
    return CopilotSession(
      id: json['id'] as String? ?? const Uuid().v4(),
      title: json['title'] as String? ?? '未命名会话',
      messages: messages,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? now
          : now,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String) ?? now
          : now,
    );
  }
}

class CopilotState {
  final List<ChatMessage> messages;
  final List<CopilotSession> sessions;
  final String? currentSessionId;
  final bool isRunning;
  final bool loading;

  const CopilotState({
    this.messages = const [],
    this.sessions = const [],
    this.currentSessionId,
    this.isRunning = false,
    this.loading = false,
  });

  CopilotState copyWith({
    List<ChatMessage>? messages,
    List<CopilotSession>? sessions,
    String? currentSessionId,
    bool clearCurrentSessionId = false,
    bool? isRunning,
    bool? loading,
  }) {
    return CopilotState(
      messages: messages ?? this.messages,
      sessions: sessions ?? this.sessions,
      currentSessionId: clearCurrentSessionId
          ? null
          : currentSessionId ?? this.currentSessionId,
      isRunning: isRunning ?? this.isRunning,
      loading: loading ?? this.loading,
    );
  }
}

class CopilotNotifier extends Notifier<CopilotState> {
  @override
  CopilotState build() {
    Future.microtask(loadSessions);
    return const CopilotState(loading: true);
  }

  Future<void> loadSessions() async {
    final sessions = await _readSessions();
    sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final current = sessions.isNotEmpty ? sessions.first : null;
    state = state.copyWith(
      sessions: sessions,
      messages: current?.messages ?? const [],
      currentSessionId: current?.id,
      loading: false,
    );
  }

  Future<void> newSession() async {
    state = state.copyWith(messages: const [], clearCurrentSessionId: true);
  }

  Future<void> selectSession(String id) async {
    final session = state.sessions.where((item) => item.id == id).firstOrNull;
    if (session == null) return;
    state = state.copyWith(
      messages: session.messages,
      currentSessionId: session.id,
    );
  }

  Future<void> deleteSession(String id) async {
    final sessions = state.sessions.where((item) => item.id != id).toList();
    await _writeSessions(sessions);
    final wasCurrent = state.currentSessionId == id;
    state = state.copyWith(
      sessions: sessions,
      messages: wasCurrent ? const [] : state.messages,
      clearCurrentSessionId: wasCurrent,
    );
  }

  Future<void> sendMessage(String text) async {
    if (state.isRunning) return;
    final userMessage = ChatMessage(
      id: const Uuid().v4(),
      role: ChatRole.user,
      content: text,
      type: ChatMessageType.text,
      timestamp: DateTime.now(),
    );
    final history = state.messages;
    state = state.copyWith(
      messages: [...history, userMessage],
      isRunning: true,
    );
    try {
      final agent = CopilotAgentService(
        datasource: ref.read(datasourceProvider),
        profile: ref.read(profileProvider),
        aiModels: ref.read(aiModelProvider).configs,
      );
      final reply = await agent.run(
        input: text,
        config: ref.read(aiModelProvider).selected,
        history: history,
      );
      state = state.copyWith(
        messages: [
          ...state.messages,
          ChatMessage(
            id: const Uuid().v4(),
            role: ChatRole.assistant,
            content: reply.isEmpty ? '模型没有返回内容。' : reply,
            type: ChatMessageType.text,
            timestamp: DateTime.now(),
          ),
        ],
        isRunning: false,
      );
      await _saveCurrentSession(titleSeed: text);
    } catch (e) {
      state = state.copyWith(
        messages: [
          ...state.messages,
          ChatMessage(
            id: const Uuid().v4(),
            role: ChatRole.assistant,
            content: '调用失败：$e',
            type: ChatMessageType.error,
            timestamp: DateTime.now(),
          ),
        ],
        isRunning: false,
      );
      await _saveCurrentSession(titleSeed: text);
    }
  }

  Future<void> _saveCurrentSession({required String titleSeed}) async {
    if (state.messages.isEmpty) return;
    final now = DateTime.now();
    final id = state.currentSessionId ?? const Uuid().v4();
    final existingIndex = state.sessions.indexWhere((item) => item.id == id);
    final title = existingIndex >= 0
        ? state.sessions[existingIndex].title
        : _titleFrom(titleSeed);
    final session = CopilotSession(
      id: id,
      title: title,
      messages: state.messages,
      createdAt: existingIndex >= 0
          ? state.sessions[existingIndex].createdAt
          : now,
      updatedAt: now,
    );
    final sessions = [...state.sessions];
    if (existingIndex >= 0) {
      sessions[existingIndex] = session;
    } else {
      sessions.add(session);
    }
    sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await _writeSessions(sessions);
    state = state.copyWith(sessions: sessions, currentSessionId: id);
  }

  String _titleFrom(String text) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) return '未命名会话';
    return normalized.length <= 18
        ? normalized
        : '${normalized.substring(0, 18)}...';
  }

  Future<File> _sessionsFile() async {
    final dir = await getApplicationSupportDirectory();
    final aiDir = Directory('${dir.path}/ai');
    if (!await aiDir.exists()) {
      await aiDir.create(recursive: true);
    }
    return File('${aiDir.path}/copilot_sessions.json');
  }

  Future<List<CopilotSession>> _readSessions() async {
    try {
      final file = await _sessionsFile();
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      if (content.trim().isEmpty) return [];
      final json = jsonDecode(content) as Map<String, dynamic>;
      return (json['sessions'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(CopilotSession.fromJson)
          .where((item) => item.messages.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeSessions(List<CopilotSession> sessions) async {
    final file = await _sessionsFile();
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'sessions': sessions.take(50).map((item) => item.toJson()).toList(),
      }),
    );
  }
}

final copilotNotifierProvider = NotifierProvider<CopilotNotifier, CopilotState>(
  CopilotNotifier.new,
);
