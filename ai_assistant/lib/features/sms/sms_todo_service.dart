import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../data/datasources/local_datasource.dart';
import '../../data/repositories/todo_repository.dart';
import '../../domain/models/ai_model_config.dart';
import '../../domain/models/todo.dart';
import '../copilot/services/openai_compatible_client.dart';

class SmsTodoService {
  static const _channel = MethodChannel('my_assistant/sms');

  final LocalDatasource datasource;
  final TodoRepository todoRepository;
  final AiModelConfig? aiModelConfig;
  final OpenAiCompatibleClient _aiClient;

  SmsTodoService({
    required this.datasource,
    required this.todoRepository,
    this.aiModelConfig,
    OpenAiCompatibleClient? aiClient,
  }) : _aiClient = aiClient ?? OpenAiCompatibleClient();

  Future<SmsImportResult> importRecent({int days = 7, DateTime? now}) async {
    final base = now ?? DateTime.now();
    final messages = await _fetchMessages(days: days);
    if (messages.isEmpty) {
      return const SmsImportResult(created: 0, skipped: 0, unsupported: false);
    }

    final existing = await datasource.getAllTodos();
    var created = 0;
    var skipped = 0;
    for (final message in messages) {
      if (message.body.trim().isEmpty || _alreadyExists(existing, message)) {
        skipped++;
        continue;
      }
      final analysis =
          _analyzeByRules(message, base) ?? await _analyzeByAi(message, base);
      if (analysis == null) {
        skipped++;
        continue;
      }
      final todo = Todo(
        id: const Uuid().v4(),
        title: analysis.title,
        description: _descriptionOf(message, analysis),
        source: 'sms',
        routineId: message.id,
        type: 'message',
        action: 'none',
        time: analysis.time,
        date: analysis.date,
        createdAt: base,
        updatedAt: base,
        priority: analysis.priority,
      );
      await todoRepository.addTodo(todo);
      existing.add(todo);
      created++;
    }
    return SmsImportResult(
      created: created,
      skipped: skipped,
      unsupported: false,
    );
  }

  Future<List<SmsMessage>> _fetchMessages({required int days}) async {
    try {
      final raw = await _channel
          .invokeMethod<List<dynamic>>('fetchRecent', {'days': days})
          .timeout(
            const Duration(seconds: 2),
            onTimeout: () => const <dynamic>[],
          );
      return (raw ?? const [])
          .whereType<Map>()
          .map((item) => SmsMessage.fromMap(item.cast<String, Object?>()))
          .where((message) => message.body.trim().isNotEmpty)
          .toList();
    } on MissingPluginException {
      return const [];
    } on PlatformException {
      return const [];
    }
  }

  SmsAnalysis? _analyzeByRules(SmsMessage message, DateTime now) {
    final text = message.body.replaceAll(RegExp(r'\s+'), ' ').trim();
    final lower = text.toLowerCase();

    final looksLikePickup =
        text.contains('取件') ||
        text.contains('取货') ||
        text.contains('提货') ||
        text.contains('驿站') ||
        text.contains('快递柜') ||
        text.contains('丰巢') ||
        text.contains('菜鸟') ||
        text.contains('包裹');
    if (looksLikePickup) {
      final code = _firstMatch(text, [
        RegExp(r'(?:取件码|取货码|提货码|领取码|凭证码|验证码)[：:\s]*([A-Za-z0-9\-]{3,12})'),
        RegExp(r'(?:码|凭证)[：:\s]*([A-Za-z0-9\-]{4,12})'),
      ]);
      final location = _firstMatch(text, [
        RegExp(r'(?:至|到|在|前往)([^，。,；;]{2,18}(?:驿站|快递柜|丰巢|站点|门店|柜))'),
        RegExp(r'([^，。,；;]{2,18}(?:驿站|快递柜|丰巢|站点|门店|柜))'),
      ]);
      final title = [
        '取快递',
        if (code != null && code.isNotEmpty) code,
      ].join(' ');
      return SmsAnalysis(
        title: title,
        summary: [
          if (code != null) '取件码：$code',
          if (location != null) '地点：$location',
        ].join('\n'),
        date: _todoDate(message.receivedAt, now),
        time: _todoTime(message.receivedAt, fallback: '18:00'),
        priority: 0,
      );
    }

    final hasTicket =
        lower.contains('ticket') ||
        text.contains('出票') ||
        text.contains('检票') ||
        text.contains('航班') ||
        text.contains('车次');
    if (hasTicket) {
      return SmsAnalysis(
        title: '查看出行短信',
        summary: '可能是出行票务或行程信息',
        date: _todoDate(message.receivedAt, now),
        time: _todoTime(message.receivedAt, fallback: '09:00'),
        priority: 1,
      );
    }

    // 纯验证码、营销短信默认不生成代办，避免打扰。
    if (text.contains('验证码') || text.contains('优惠') || text.contains('退订')) {
      return null;
    }
    return null;
  }

  Future<SmsAnalysis?> _analyzeByAi(SmsMessage message, DateTime now) async {
    final config = aiModelConfig;
    if (config == null || config.apiKey.trim().isEmpty) return null;
    try {
      final content = await _aiClient.chat(
        config: config,
        messages: [
          const LlmChatMessage(
            role: 'system',
            content:
                '你是短信代办分析器。只在短信确实需要用户后续处理时返回 JSON；营销、纯验证码、通知类短信返回 {"shouldCreate":false}。JSON 字段：shouldCreate,title,summary,date,time,priority。date 用 yyyy-MM-dd，time 用 HH:mm，priority 0普通 1重要 2紧急。',
          ),
          LlmChatMessage(
            role: 'user',
            content:
                '当前时间：${now.toIso8601String()}\n短信时间：${message.receivedAt.toIso8601String()}\n发件人：${message.address}\n短信原文：${message.body}',
          ),
        ],
      );
      final jsonText = _extractJson(content);
      if (jsonText == null) return null;
      final map = jsonDecode(jsonText) as Map<String, dynamic>;
      if (map['shouldCreate'] != true) return null;
      final date =
          DateTime.tryParse(map['date'] as String? ?? '') ??
          _todoDate(message.receivedAt, now);
      return SmsAnalysis(
        title: (map['title'] as String? ?? '').trim().isEmpty
            ? '处理短信事项'
            : (map['title'] as String).trim(),
        summary: (map['summary'] as String? ?? '').trim(),
        date: DateTime(date.year, date.month, date.day),
        time:
            _normalizeTime(map['time'] as String?) ??
            _todoTime(message.receivedAt, fallback: '09:00'),
        priority: ((map['priority'] as num?)?.toInt() ?? 0).clamp(0, 2),
      );
    } catch (_) {
      return null;
    }
  }

  bool _alreadyExists(List<Todo> todos, SmsMessage message) {
    return todos.any(
      (todo) =>
          !todo.deleted &&
          todo.source == 'sms' &&
          (todo.routineId == message.id ||
              (todo.description ?? '').contains(message.body.trim())),
    );
  }

  String _descriptionOf(SmsMessage message, SmsAnalysis analysis) {
    return [
      if (analysis.summary.trim().isNotEmpty) analysis.summary.trim(),
      '发件人：${message.address.isEmpty ? "未知号码" : message.address}',
      '短信时间：${_formatDateTime(message.receivedAt)}',
      '短信原文：',
      message.body.trim(),
    ].join('\n');
  }

  String? _firstMatch(String text, List<RegExp> patterns) {
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      final value = match?.group(1)?.trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  DateTime _todoDate(DateTime receivedAt, DateTime now) {
    final candidate = DateTime(
      receivedAt.year,
      receivedAt.month,
      receivedAt.day,
    );
    final today = DateTime(now.year, now.month, now.day);
    return candidate.isBefore(today) ? today : candidate;
  }

  String _todoTime(DateTime receivedAt, {required String fallback}) {
    if (DateTime.now().difference(receivedAt).inHours.abs() <= 24) {
      final nextHour = DateTime.now().add(const Duration(hours: 1));
      return '${nextHour.hour.toString().padLeft(2, '0')}:00';
    }
    return fallback;
  }

  String? _normalizeTime(String? raw) {
    if (raw == null) return null;
    final match = RegExp(r'^(\d{1,2}):(\d{1,2})$').firstMatch(raw.trim());
    if (match == null) return null;
    final hour = (int.tryParse(match.group(1) ?? '') ?? 9).clamp(0, 23);
    final minute = (int.tryParse(match.group(2) ?? '') ?? 0).clamp(0, 59);
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  String? _extractJson(String content) {
    final fenced = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(content);
    if (fenced != null) return fenced.group(1)?.trim();
    final start = content.indexOf('{');
    final end = content.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    return content.substring(start, end + 1);
  }

  String _formatDateTime(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }
}

class SmsImportResult {
  final int created;
  final int skipped;
  final bool unsupported;

  const SmsImportResult({
    required this.created,
    required this.skipped,
    required this.unsupported,
  });
}

class SmsMessage {
  final String id;
  final String address;
  final String body;
  final DateTime receivedAt;
  final String platform;

  const SmsMessage({
    required this.id,
    required this.address,
    required this.body,
    required this.receivedAt,
    required this.platform,
  });

  factory SmsMessage.fromMap(Map<String, Object?> map) {
    final millis = (map['receivedAtMillis'] as num?)?.toInt() ?? 0;
    return SmsMessage(
      id: map['id'] as String? ?? const Uuid().v4(),
      address: map['address'] as String? ?? '',
      body: map['body'] as String? ?? '',
      receivedAt: DateTime.fromMillisecondsSinceEpoch(millis),
      platform: map['platform'] as String? ?? 'unknown',
    );
  }
}

class SmsAnalysis {
  final String title;
  final String summary;
  final DateTime date;
  final String time;
  final int priority;

  const SmsAnalysis({
    required this.title,
    required this.summary,
    required this.date,
    required this.time,
    required this.priority,
  });
}
