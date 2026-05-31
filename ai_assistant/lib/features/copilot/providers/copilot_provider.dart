import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/database.dart' hide CopilotSession;
import '../../../core/providers/core_providers.dart';
import '../../../data/datasources/local_datasource.dart';
import '../../ai_settings/ai_model_provider.dart';
import '../copilot_settings.dart';
import '../copilot_memory.dart';
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
  final List<String> attachmentIds;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.type,
    required this.timestamp,
    this.attachmentIds = const [],
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'role': role.name,
    'content': content,
    'type': type.name,
    'timestamp': timestamp.toIso8601String(),
    'attachmentIds': attachmentIds,
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
      attachmentIds: (json['attachmentIds'] as List? ?? const [])
          .whereType<String>()
          .toList(),
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
  static const _sessionsStoreName = 'copilot_sessions_json';

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
        settings: ref.read(copilotSettingsProvider),
        memory: ref.read(copilotMemoryProvider),
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
      await ref
          .read(copilotMemoryProvider.notifier)
          .rememberInteraction(userText: text, assistantText: reply);
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

  Future<List<CopilotSession>> _readSessions() async {
    if (LocalDatasource.usesFileFallback) {
      final raw = await ref
          .read(datasourceProvider)
          .readLocalStoreText(_sessionsStoreName);
      if (raw == null || raw.trim().isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((item) => CopilotSession.fromJson(item.cast<String, dynamic>()))
          .where((item) => item.messages.isNotEmpty)
          .toList();
    }
    final db = ref.read(databaseProvider);
    final rows = await (db.select(
      db.copilotSessions,
    )..where((t) => t.isDeleted.equals(false))).get();
    return rows
        .map(
          (row) => CopilotSession.fromJson({
            'id': row.id,
            'title': row.title,
            'messages': jsonDecode(row.messages),
            'createdAt': row.createdAt.toIso8601String(),
            'updatedAt': row.updatedAt.toIso8601String(),
          }),
        )
        .where((item) => item.messages.isNotEmpty)
        .toList();
  }

  Future<void> _writeSessions(List<CopilotSession> sessions) async {
    if (LocalDatasource.usesFileFallback) {
      await ref
          .read(datasourceProvider)
          .writeLocalStoreText(
            _sessionsStoreName,
            jsonEncode(sessions.take(50).map((item) => item.toJson()).toList()),
          );
      return;
    }
    final db = ref.read(databaseProvider);
    final current = await db.select(db.copilotSessions).get();
    final ids = sessions.map((item) => item.id).toSet();
    for (final session in sessions.take(50)) {
      final old = current.where((row) => row.id == session.id).firstOrNull;
      await db
          .into(db.copilotSessions)
          .insertOnConflictUpdate(
            CopilotSessionsCompanion(
              id: Value(session.id),
              title: Value(session.title),
              messages: Value(
                jsonEncode(
                  session.messages.map((item) => item.toJson()).toList(),
                ),
              ),
              createdAt: Value(session.createdAt),
              updatedAt: Value(session.updatedAt),
              version: Value((old?.version ?? 0) + 1),
              archived: const Value(false),
              isDeleted: const Value(false),
            ),
          );
    }
    for (final row in current) {
      if (!ids.contains(row.id) && !row.isDeleted) {
        await (db.update(
          db.copilotSessions,
        )..where((t) => t.id.equals(row.id))).write(
          CopilotSessionsCompanion(
            updatedAt: Value(DateTime.now()),
            version: Value(row.version + 1),
            isDeleted: const Value(true),
          ),
        );
      }
    }
  }
}

final copilotNotifierProvider = NotifierProvider<CopilotNotifier, CopilotState>(
  CopilotNotifier.new,
);
