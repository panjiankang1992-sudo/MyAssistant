import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/api/api_client.dart';

enum CopilotMemoryType { shortTerm, longTerm }

class CopilotMemoryItem {
  final String id;
  final CopilotMemoryType type;
  final String title;
  final String content;
  final List<String> tags;
  final int importance;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CopilotMemoryItem({
    required this.id,
    required this.type,
    required this.title,
    required this.content,
    this.tags = const [],
    this.importance = 2,
    required this.createdAt,
    required this.updatedAt,
  });

  CopilotMemoryItem copyWith({
    CopilotMemoryType? type,
    String? title,
    String? content,
    List<String>? tags,
    int? importance,
    DateTime? updatedAt,
  }) {
    return CopilotMemoryItem(
      id: id,
      type: type ?? this.type,
      title: title ?? this.title,
      content: content ?? this.content,
      tags: tags ?? this.tags,
      importance: importance ?? this.importance,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'title': title,
    'content': content,
    'tags': tags,
    'importance': importance,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory CopilotMemoryItem.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return CopilotMemoryItem(
      id: json['id'] as String? ?? const Uuid().v4(),
      type: CopilotMemoryType.values.firstWhere(
        (item) => item.name == json['type'],
        orElse: () => CopilotMemoryType.longTerm,
      ),
      title: json['title'] as String? ?? '未命名记忆',
      content: json['content'] as String? ?? '',
      tags: (json['tags'] as List? ?? const []).whereType<String>().toList(),
      importance: (json['importance'] as int? ?? 2).clamp(1, 5),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? now,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? now,
    );
  }
}

class CopilotMemoryState {
  final List<CopilotMemoryItem> items;

  const CopilotMemoryState({this.items = const []});

  List<CopilotMemoryItem> get longTerm => _sorted(CopilotMemoryType.longTerm);

  List<CopilotMemoryItem> get shortTerm => _sorted(CopilotMemoryType.shortTerm);

  List<CopilotMemoryItem> _sorted(CopilotMemoryType type) {
    final result = items.where((item) => item.type == type).toList()
      ..sort((a, b) {
        final byImportance = b.importance.compareTo(a.importance);
        if (byImportance != 0) return byImportance;
        return b.updatedAt.compareTo(a.updatedAt);
      });
    return result;
  }

  String promptContext() {
    final long = longTerm.take(12).map(_memoryLine).join('\n');
    final short = shortTerm.take(8).map(_memoryLine).join('\n');
    if (long.isEmpty && short.isEmpty) {
      return 'Copilot 记忆：暂无可用记忆。';
    }
    return [
      'Copilot 记忆系统已启用。',
      if (long.isNotEmpty) '长期记忆（跨会话持久保留，优先遵守）：\n$long',
      if (short.isNotEmpty) '短期记忆（近期对话上下文，可随时间衰减）：\n$short',
      '使用约束：记忆可能过期；涉及事实、时间、金额时优先以应用实时数据为准。',
    ].join('\n');
  }

  String _memoryLine(CopilotMemoryItem item) {
    final tags = item.tags.isEmpty ? '' : ' #${item.tags.join(" #")}';
    return '- [${item.importance}/5] ${item.title}: ${item.content}$tags';
  }
}

class CopilotMemoryNotifier extends Notifier<CopilotMemoryState> {
  static const _storageKey = 'copilot_memory';
  static const _shortLimit = 30;

  @override
  CopilotMemoryState build() {
    Future.microtask(_load);
    return const CopilotMemoryState();
  }

  Future<void> _load() async {
    final cached = await ApiClient.storageRead(_storageKey);
    if (cached == null || cached.trim().isEmpty) return;
    try {
      final data = jsonDecode(cached) as List<dynamic>;
      state = CopilotMemoryState(
        items: data
            .whereType<Map>()
            .map((item) => CopilotMemoryItem.fromJson(item.cast()))
            .where((item) => item.content.trim().isNotEmpty)
            .toList(),
      );
    } catch (_) {
      state = const CopilotMemoryState();
    }
  }

  Future<void> upsert({
    String? id,
    required CopilotMemoryType type,
    required String title,
    required String content,
    List<String> tags = const [],
    int importance = 2,
  }) async {
    final now = DateTime.now();
    final existingIndex = id == null
        ? -1
        : state.items.indexWhere((item) => item.id == id);
    final item = existingIndex >= 0
        ? state.items[existingIndex].copyWith(
            type: type,
            title: title.trim().isEmpty ? '未命名记忆' : title.trim(),
            content: content.trim(),
            tags: tags,
            importance: importance.clamp(1, 5),
            updatedAt: now,
          )
        : CopilotMemoryItem(
            id: const Uuid().v4(),
            type: type,
            title: title.trim().isEmpty ? '未命名记忆' : title.trim(),
            content: content.trim(),
            tags: tags,
            importance: importance.clamp(1, 5),
            createdAt: now,
            updatedAt: now,
          );
    final items = [...state.items];
    if (existingIndex >= 0) {
      items[existingIndex] = item;
    } else {
      items.add(item);
    }
    state = CopilotMemoryState(items: _prune(items));
    await _save();
  }

  Future<void> delete(String id) async {
    state = CopilotMemoryState(
      items: state.items.where((item) => item.id != id).toList(),
    );
    await _save();
  }

  Future<void> clearShortTerm() async {
    state = CopilotMemoryState(
      items: state.items
          .where((item) => item.type != CopilotMemoryType.shortTerm)
          .toList(),
    );
    await _save();
  }

  Future<void> rememberInteraction({
    required String userText,
    required String assistantText,
  }) async {
    final normalized = _compact(userText);
    if (normalized.isEmpty) return;
    await upsert(
      type: CopilotMemoryType.shortTerm,
      title: _titleOf(normalized),
      content:
          '用户：${_truncate(normalized, 90)}；助手：${_truncate(_compact(assistantText), 130)}',
      tags: const ['recent'],
      importance: 2,
    );
    final explicit = _extractExplicitMemory(normalized);
    if (explicit != null) {
      await upsert(
        type: CopilotMemoryType.longTerm,
        title: explicit.title,
        content: explicit.content,
        tags: const ['user-preference'],
        importance: 4,
      );
    }
  }

  Future<void> _save() async {
    await ApiClient.storageWrite(
      _storageKey,
      jsonEncode(state.items.map((item) => item.toJson()).toList()),
    );
  }

  List<CopilotMemoryItem> _prune(List<CopilotMemoryItem> items) {
    final long = items
        .where((item) => item.type == CopilotMemoryType.longTerm)
        .toList();
    final short =
        items.where((item) => item.type == CopilotMemoryType.shortTerm).toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return [...long, ...short.take(_shortLimit)];
  }

  _ExplicitMemory? _extractExplicitMemory(String text) {
    final patterns = [
      RegExp(r'记住[：:，,\s]*(.+)$'),
      RegExp(r'以后[都要]*[：:，,\s]*(.+)$'),
      RegExp(r'我的偏好是[：:，,\s]*(.+)$'),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      final value = match?.group(1)?.trim();
      if (value != null && value.length >= 2) {
        return _ExplicitMemory(title: _titleOf(value), content: value);
      }
    }
    return null;
  }

  String _titleOf(String text) {
    final compact = _compact(text);
    if (compact.length <= 16) return compact;
    return '${compact.substring(0, 16)}...';
  }

  String _compact(String text) {
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _truncate(String text, int max) {
    if (text.length <= max) return text;
    return '${text.substring(0, max)}...';
  }
}

class _ExplicitMemory {
  final String title;
  final String content;

  const _ExplicitMemory({required this.title, required this.content});
}

final copilotMemoryProvider =
    NotifierProvider<CopilotMemoryNotifier, CopilotMemoryState>(
      CopilotMemoryNotifier.new,
    );
