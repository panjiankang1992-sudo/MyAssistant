import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/api_client.dart';
import 'copilot_avatar.dart';

class CopilotSettings {
  final String assistantName;
  final String assistantAvatar;
  final String userCallName;
  final String persona;
  final int version;

  const CopilotSettings({
    this.assistantName = 'MyAssistant',
    this.assistantAvatar = CopilotAvatarCatalog.defaultValue,
    this.userCallName = '',
    this.persona = defaultPersona,
    this.version = 1,
  });

  static const defaultPersona =
      '你是一个温和、聪明、行动力强的个人智能助手。'
      '你会先读懂用户真实意图，再给出简洁、可执行的回应。'
      '聊天风格自然、有耐心、不啰嗦；处理应用内数据时优先使用表格、状态灯和清晰的小结。'
      '称呼用户时保持亲近但不过度热情。';

  String get displayName =>
      assistantName.trim().isEmpty ? 'MyAssistant' : assistantName.trim();

  String get displayAvatar => CopilotAvatarCatalog.normalize(assistantAvatar);

  String get displayAvatarDescription =>
      CopilotAvatarCatalog.descriptionOf(displayAvatar);

  String get displayUserCallName => userCallName.trim();

  String get displayPersona =>
      persona.trim().isEmpty ? defaultPersona : persona.trim();

  CopilotSettings copyWith({
    String? assistantName,
    String? assistantAvatar,
    String? userCallName,
    String? persona,
  }) {
    return CopilotSettings(
      assistantName: assistantName ?? this.assistantName,
      assistantAvatar: assistantAvatar ?? this.assistantAvatar,
      userCallName: userCallName ?? this.userCallName,
      persona: persona ?? this.persona,
      version: version + 1,
    );
  }

  Map<String, dynamic> toJson() => {
    'assistantName': assistantName,
    'assistantAvatar': assistantAvatar,
    'userCallName': userCallName,
    'persona': persona,
    'version': version,
  };

  factory CopilotSettings.fromJson(Map<String, dynamic> json) {
    return CopilotSettings(
      assistantName: json['assistantName'] as String? ?? 'MyAssistant',
      assistantAvatar: CopilotAvatarCatalog.normalize(
        json['assistantAvatar'] as String?,
      ),
      userCallName: json['userCallName'] as String? ?? '',
      persona: json['persona'] as String? ?? CopilotSettings.defaultPersona,
      version: json['version'] as int? ?? 1,
    );
  }
}

class CopilotSettingsNotifier extends Notifier<CopilotSettings> {
  static const _storageKey = 'copilot_settings';

  @override
  CopilotSettings build() {
    Future.microtask(_load);
    return const CopilotSettings();
  }

  Future<void> _load() async {
    final cached = await ApiClient.storageRead(_storageKey);
    if (cached == null || cached.trim().isEmpty) return;
    try {
      final json = jsonDecode(cached) as Map<String, dynamic>;
      state = CopilotSettings.fromJson(json);
    } catch (_) {
      state = const CopilotSettings();
    }
  }

  Future<void> update(CopilotSettings settings) async {
    state = settings;
    await ApiClient.storageWrite(_storageKey, jsonEncode(settings.toJson()));
  }
}

final copilotSettingsProvider =
    NotifierProvider<CopilotSettingsNotifier, CopilotSettings>(
      CopilotSettingsNotifier.new,
    );
