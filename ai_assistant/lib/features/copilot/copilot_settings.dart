import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/core_providers.dart';
import 'copilot_avatar.dart';

class CopilotPersonaPreset {
  final String value;
  final String label;
  final String description;
  final String prompt;

  const CopilotPersonaPreset({
    required this.value,
    required this.label,
    required this.description,
    required this.prompt,
  });
}

class CopilotPersonaCatalog {
  static const customValue = 'custom';
  static const defaultValue = 'gentle';

  static const presets = [
    CopilotPersonaPreset(
      value: 'lively',
      label: '活泼',
      description: '轻快、有能量，适合脑暴和推动行动。',
      prompt:
          '你是一个活泼、聪明、行动力很强的个人智能助手。'
          '你的语气轻快、有生命力，但不吵闹、不浮夸。'
          '你会先抓住用户真正想解决的问题，再用短句、清晰步骤和一点点俏皮感推动事情往前走。'
          '当用户卡住时，你会给出鼓励和可立即执行的小动作；处理数据时依旧保持准确，优先使用表格、状态灯和简洁结论。'
          '不要长篇铺垫，不要过度热情，不要使用幼稚化表达。',
    ),
    CopilotPersonaPreset(
      value: 'steady',
      label: '稳重',
      description: '克制、可靠，适合计划、复盘和复杂决策。',
      prompt:
          '你是一个稳重、可靠、判断力强的个人智能助手。'
          '你的语气冷静、清楚、有分寸，先确认事实和约束，再给出稳妥方案。'
          '遇到复杂问题时，你会拆解优先级、风险、下一步动作；遇到不确定信息时明确说明假设。'
          '处理应用内数据时，优先给出结构化摘要、表格、状态灯和可执行建议。'
          '不要夸张，不要催促，不要用情绪化措辞。',
    ),
    CopilotPersonaPreset(
      value: 'gentle',
      label: '温柔',
      description: '耐心、体贴，适合陪伴式整理和日常协助。',
      prompt:
          '你是一个温柔、耐心、很会照顾用户节奏的个人智能助手。'
          '你的语气柔和、清爽、不过度亲昵，会让用户感到被理解但不被打扰。'
          '你会先回应用户的真实感受和需求，再把事情整理成轻量、可完成的步骤。'
          '处理应用内数据时保持准确和简洁，优先使用清晰小结、状态灯、列表和温和的下一步建议。'
          '不要说教，不要堆砌安慰，不要把简单问题复杂化。',
    ),
    CopilotPersonaPreset(
      value: 'serious',
      label: '严肃',
      description: '直接、专业，适合高效查询和执行任务。',
      prompt:
          '你是一个严肃、专业、目标导向的个人智能助手。'
          '你的语气直接、准确、少寒暄，优先回答结论、证据和行动项。'
          '你会压缩无关表达，明确指出风险、阻塞和需要用户确认的事项。'
          '处理应用内数据时必须结构化展示，代办使用红黄绿灯和表格，统计分析给出关键指标和结论。'
          '不要玩笑，不要情绪化，不要为了显得友好而牺牲效率。',
    ),
  ];

  static CopilotPersonaPreset byValue(String value) {
    return presets.firstWhere(
      (item) => item.value == value,
      orElse: () => presets.firstWhere((item) => item.value == defaultValue),
    );
  }

  static String normalizeStyle(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed == customValue) return customValue;
    if (presets.any((item) => item.value == trimmed)) return trimmed;
    return defaultValue;
  }

  static String defaultPromptOf(String style) {
    if (style == customValue) return CopilotSettings.defaultPersona;
    return byValue(style).prompt;
  }
}

class CopilotSettings {
  final String assistantName;
  final String assistantAvatar;
  final String userCallName;
  final String persona;
  final String personaStyle;
  final int version;

  const CopilotSettings({
    this.assistantName = 'MyAssistant',
    this.assistantAvatar = CopilotAvatarCatalog.defaultValue,
    this.userCallName = '',
    this.persona = defaultPersona,
    this.personaStyle = CopilotPersonaCatalog.defaultValue,
    this.version = 1,
  });

  static const defaultPersona =
      '你是一个温柔、耐心、很会照顾用户节奏的个人智能助手。'
      '你的语气柔和、清爽、不过度亲昵，会让用户感到被理解但不被打扰。'
      '你会先回应用户的真实感受和需求，再把事情整理成轻量、可完成的步骤。'
      '处理应用内数据时保持准确和简洁，优先使用清晰小结、状态灯、列表和温和的下一步建议。'
      '不要说教，不要堆砌安慰，不要把简单问题复杂化。';

  String get displayName =>
      assistantName.trim().isEmpty ? 'MyAssistant' : assistantName.trim();

  String get displayAvatar => CopilotAvatarCatalog.normalize(assistantAvatar);

  String get displayAvatarDescription =>
      CopilotAvatarCatalog.descriptionOf(displayAvatar);

  String get displayUserCallName => userCallName.trim();

  String get displayPersona =>
      persona.trim().isEmpty ? defaultPersona : persona.trim();

  String get displayPersonaStyle =>
      CopilotPersonaCatalog.normalizeStyle(personaStyle);

  CopilotSettings copyWith({
    String? assistantName,
    String? assistantAvatar,
    String? userCallName,
    String? persona,
    String? personaStyle,
  }) {
    return CopilotSettings(
      assistantName: assistantName ?? this.assistantName,
      assistantAvatar: assistantAvatar ?? this.assistantAvatar,
      userCallName: userCallName ?? this.userCallName,
      persona: persona ?? this.persona,
      personaStyle: personaStyle ?? this.personaStyle,
      version: version + 1,
    );
  }

  Map<String, dynamic> toJson() => {
    'assistantName': assistantName,
    'assistantAvatar': assistantAvatar,
    'userCallName': userCallName,
    'persona': persona,
    'personaStyle': personaStyle,
    'version': version,
  };

  factory CopilotSettings.fromJson(Map<String, dynamic> json) {
    final persona =
        json['persona'] as String? ?? CopilotSettings.defaultPersona;
    final rawStyle = json['personaStyle'] as String?;
    final style = rawStyle == null && persona.trim() != defaultPersona
        ? CopilotPersonaCatalog.customValue
        : CopilotPersonaCatalog.normalizeStyle(rawStyle);
    return CopilotSettings(
      assistantName: json['assistantName'] as String? ?? 'MyAssistant',
      assistantAvatar: CopilotAvatarCatalog.normalize(
        json['assistantAvatar'] as String?,
      ),
      userCallName: json['userCallName'] as String? ?? '',
      persona: persona,
      personaStyle: style,
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
    final cached = await ref
        .read(datasourceProvider)
        .getAppSettingJson('copilot_setting', _storageKey);
    if (cached == null || cached.isEmpty) return;
    try {
      state = CopilotSettings.fromJson(cached);
    } catch (_) {
      state = const CopilotSettings();
    }
  }

  Future<void> update(CopilotSettings settings) async {
    state = settings;
    await ref
        .read(datasourceProvider)
        .upsertAppSettingJson(
          module: 'profile',
          dataType: 'copilot_setting',
          id: _storageKey,
          payload: settings.toJson(),
        );
  }
}

final copilotSettingsProvider =
    NotifierProvider<CopilotSettingsNotifier, CopilotSettings>(
      CopilotSettingsNotifier.new,
    );
