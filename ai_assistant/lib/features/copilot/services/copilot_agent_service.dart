import '../../../data/datasources/local_datasource.dart';
import '../../../domain/models/ai_model_config.dart';
import '../../profile/profile_provider.dart';
import '../../skills/app_data_skill_service.dart';
import '../../skills/builtin_skill_registry.dart';
import '../copilot_memory.dart';
import '../copilot_settings.dart';
import '../providers/copilot_provider.dart';
import 'openai_compatible_client.dart';

class CopilotAgentService {
  final LocalDatasource datasource;
  final UserProfile profile;
  final List<AiModelConfig> aiModels;
  final CopilotSettings settings;
  final CopilotMemoryState memory;
  final OpenAiCompatibleClient llmClient;

  CopilotAgentService({
    required this.datasource,
    required this.profile,
    required this.aiModels,
    required this.settings,
    required this.memory,
    OpenAiCompatibleClient? llmClient,
  }) : llmClient = llmClient ?? OpenAiCompatibleClient();

  Future<String> run({
    required String input,
    required AiModelConfig? config,
    required List<ChatMessage> history,
  }) async {
    final localContext = await _buildLocalContext(input);
    if (localContext.directAnswer != null) {
      return localContext.directAnswer!;
    }
    if (config == null) {
      return '还没有配置大模型。请从头像菜单进入「Copilot 设置」，在模型维护里添加 DeepSeek、MiniMax 或 OpenAI 兼容模型后再试。';
    }
    if (config.apiKey.trim().isEmpty ||
        config.baseUrl.trim().isEmpty ||
        config.model.trim().isEmpty) {
      return '当前模型配置不完整，请补齐 API Key、Base URL 和模型名。';
    }

    final messages = [
      const LlmChatMessage(
        role: 'system',
        content:
            '你是 MyAssistant 的轻量化 Agent。你可以使用内置 skill。'
            '你在聊天界面里的名字由用户设置决定。'
            'MCP 当前处于配置预留阶段，不要假装已连接外部 MCP。'
            '回答要简洁、中文、可执行。'
            '查询、统计、分析本应用数据时，优先使用应用数据 skill 的结构化结果；'
            '代办列表必须使用红黄绿灯和表格，不要暴露内部枚举值。'
            '表格中的来源和动作字段必须翻译成中文，例如 routine=例行，manual=手动，bookkeeping=记账。'
            '如果 system 上下文包含「app_data skill 已授权并已读取」，'
            '你必须承认已经读取到本应用本地数据，并基于其中数据回答；'
            '禁止回答“无法访问本地数据”“请提供应用数据”。',
      ),
      LlmChatMessage(
        role: 'system',
        content:
            '当前 Copilot 设置：助手名称=${settings.displayName}；'
            '助手头像=${settings.displayAvatarDescription}；'
            '对用户称呼=${settings.displayUserCallName.isEmpty ? "按用户昵称自然称呼" : settings.displayUserCallName}；'
            '性格与聊天风格：${settings.displayPersona}',
      ),
      LlmChatMessage(role: 'system', content: memory.promptContext()),
      LlmChatMessage(
        role: 'system',
        content:
            '当前内置 skill 清单如下：\n${BuiltinSkillRegistry.copilotSystemText()}',
      ),
      LlmChatMessage(role: 'system', content: localContext.promptContext),
      ...history
          .take(12)
          .map(
            (item) => LlmChatMessage(
              role: item.role == ChatRole.user ? 'user' : 'assistant',
              content: item.content,
            ),
          ),
      LlmChatMessage(role: 'user', content: input),
    ];
    final reply = await llmClient.chat(config: config, messages: messages);
    if (localContext.triggered &&
        (reply.contains('无法') ||
            reply.contains('不能访问') ||
            reply.contains('请提供'))) {
      return localContext.fallbackAnswer;
    }
    return reply;
  }

  Future<_LocalContext> _buildLocalContext(String input) async {
    final lower = input.toLowerCase();
    final wantsAppData =
        input.contains('技能') ||
        lower.contains('skill') ||
        input.contains('当前应用') ||
        input.contains('应用内') ||
        input.contains('所有数据') ||
        input.contains('我的数据') ||
        input.contains('个人信息') ||
        input.contains('待办') ||
        input.contains('日程') ||
        input.contains('明天') ||
        input.contains('明日') ||
        input.contains('今天') ||
        input.contains('例行') ||
        input.contains('账单') ||
        input.contains('记账') ||
        input.contains('收支') ||
        input.contains('消费') ||
        input.contains('收入') ||
        input.contains('随手记') ||
        input.contains('日记') ||
        input.contains('文档') ||
        input.contains('统计') ||
        input.contains('分析') ||
        input.contains('标签') ||
        input.contains('模型') ||
        input.contains('导入') ||
        lower.contains('todo');
    if (!wantsAppData) {
      return const _LocalContext(
        triggered: false,
        promptContext: '本轮未触发 app_data skill。',
        fallbackAnswer: '',
      );
    }
    if (input.contains('技能') || lower.contains('skill')) {
      final lines = BuiltinSkillRegistry.all
          .map(
            (skill) =>
                '| ${skill.name} | `${skill.id}` | ${skill.summary.replaceAll('|', '\\|')} |',
          )
          .join('\n');
      final answer = [
        '## 内置 Skill',
        '',
        '| 能力 | ID | 适合处理 |',
        '|---|---|---|',
        lines,
        '',
        '**数据类 skill 输出规范**',
        '- 代办：🔴 逾期、🟡 待处理、🟢 已完成，并使用表格列表。',
        '- 记账：展示收入、支出、净额，金额保留两位小数。',
        '- 随手记：区分日记、文档、归纳文档，默认读取摘要。',
      ].join('\n');
      return _LocalContext(
        triggered: true,
        promptContext:
            'builtin_skill_list 已读取。当前内置 skill 清单：\n'
            '${BuiltinSkillRegistry.copilotSystemText()}',
        fallbackAnswer: answer,
        directAnswer: answer,
      );
    }

    final dataSkill = await AppDataSkillService(
      datasource: datasource,
      profile: profile,
    ).buildFor(input);
    final modelsText = aiModels
        .map((m) => '${m.name}(${m.provider}/${m.model})')
        .join('、');
    final fallback = [
      dataSkill.fallbackAnswer,
      '',
      '**本地配置**',
      '- 个人信息：${profile.name.isEmpty ? "未设置昵称" : profile.name}'
          '${profile.email.isEmpty ? "" : "，邮箱 ${profile.email}"}',
      '- AI 模型：${modelsText.isEmpty ? "暂无" : modelsText}',
    ].join('\n');
    final directIntent =
        input.contains('看下') ||
        input.contains('看看') ||
        input.contains('查看') ||
        input.contains('列出') ||
        input.contains('当前应用') ||
        input.contains('应用内') ||
        input.contains('所有数据') ||
        input.contains('我的数据') ||
        input.contains('我的代办') ||
        input.contains('我的待办') ||
        input.contains('代办列表') ||
        input.contains('账单') ||
        input.contains('记账') ||
        input.contains('收支') ||
        input.contains('随手记') ||
        input.contains('统计') ||
        input.contains('分析') ||
        input.trim() == '待办';
    return _LocalContext(
      triggered: true,
      promptContext:
          '${dataSkill.promptContext}\n\n'
          '本地配置：AI 模型=${modelsText.isEmpty ? "暂无" : modelsText}\n'
          '约束：只能基于上述数据分析；不要声称无法读取本应用数据。',
      fallbackAnswer: dataSkill.directAnswer ?? fallback,
      directAnswer: directIntent ? (dataSkill.directAnswer ?? fallback) : null,
    );
  }
}

class _LocalContext {
  final bool triggered;
  final String promptContext;
  final String fallbackAnswer;
  final String? directAnswer;

  const _LocalContext({
    required this.triggered,
    required this.promptContext,
    required this.fallbackAnswer,
    this.directAnswer,
  });
}
