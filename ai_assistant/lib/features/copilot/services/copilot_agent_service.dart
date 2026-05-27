import '../../../data/datasources/local_datasource.dart';
import '../../../domain/models/ai_model_config.dart';
import '../../../domain/models/todo.dart';
import '../../profile/profile_provider.dart';
import '../../skills/builtin_skill_registry.dart';
import '../providers/copilot_provider.dart';
import 'openai_compatible_client.dart';

class CopilotAgentService {
  final LocalDatasource datasource;
  final UserProfile profile;
  final List<AiModelConfig> aiModels;
  final OpenAiCompatibleClient llmClient;

  CopilotAgentService({
    required this.datasource,
    required this.profile,
    required this.aiModels,
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
      return '还没有配置大模型。请从头像菜单进入「AI 模型」，添加 DeepSeek、MiniMax 或 OpenAI 兼容模型后再试。';
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
            'MCP 当前处于配置预留阶段，不要假装已连接外部 MCP。'
            '回答要简洁、中文、可执行。'
            '如果 system 上下文包含「app_data skill 已授权并已读取」，'
            '你必须承认已经读取到本应用本地数据，并基于其中数据回答；'
            '禁止回答“无法访问本地数据”“请提供应用数据”。',
      ),
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
        input.contains('今天') ||
        input.contains('例行') ||
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
          .map((skill) => '- **${skill.name}** `${skill.id}`：${skill.summary}')
          .join('\n');
      return _LocalContext(
        triggered: true,
        promptContext:
            'builtin_skill_list 已读取。当前内置 skill 清单：\n'
            '${BuiltinSkillRegistry.copilotSystemText()}',
        fallbackAnswer: '当前内置技能有：\n\n$lines',
        directAnswer: '当前内置技能有：\n\n$lines',
      );
    }

    final allTodos = await datasource.getAllTodos();
    final routines = await datasource.getAllRoutines();
    final tags = await datasource.getAllTags();
    final metadata = await datasource.getMetadataOptions();

    final activeTodos = allTodos.where((item) => !item.deleted).toList()
      ..sort((a, b) {
        final byDate = a.date.compareTo(b.date);
        if (byDate != 0) return byDate;
        return a.time.compareTo(b.time);
      });
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final end = today.add(const Duration(days: 7));
    final upcoming = activeTodos
        .where((item) => !item.date.isBefore(today) && item.date.isBefore(end))
        .take(30)
        .map(
          (item) =>
              '- ${_fmt(item.date)} ${item.time} '
              '${item.completed ? "[已完成]" : "[未完成]"} '
              '${item.title}'
              '${item.tags.isEmpty ? "" : " #${item.tags.map((t) => t.name).join(" #")}"}'
              '${_actionText(item.action)}'
              '${_sourceText(item.source)}',
        )
        .join('\n');
    final routinesText = routines
        .take(30)
        .map(
          (item) =>
              '- ${item.title} ${item.time} ${_repeatLabel(item.repeatRule, item.repeatDays)}'
              '${item.tags.isEmpty ? "" : " #${item.tags.map((t) => t.name).join(" #")}"}',
        )
        .join('\n');
    final tagText = tags.map((t) => t.name).join('、');
    final sourceText = metadata
        .where((m) => m.kind == 'source')
        .map((m) => m.label)
        .join('、');
    final actionText = metadata
        .where((m) => m.kind == 'action')
        .map((m) => m.label)
        .join('、');
    final modelsText = aiModels
        .map((m) => '${m.name}(${m.provider}/${m.model})')
        .join('、');
    final completedCount = activeTodos.where((t) => t.completed).length;
    final openCount = activeTodos.length - completedCount;
    final todoAnswer = _buildTodoAnswer(input, activeTodos);
    final fallback = [
      '我已读取当前应用内数据，摘要如下：',
      '- 个人信息：${profile.name.isEmpty ? "未设置昵称" : profile.name}'
          '${profile.email.isEmpty ? "" : "，邮箱 ${profile.email}"}',
      '- 待办：未删除 ${activeTodos.length} 条，其中未完成 $openCount 条，已完成 $completedCount 条',
      '- 例行：${routines.length} 条',
      '- 标签：${tagText.isEmpty ? "暂无" : tagText}',
      '- 来源选项：${sourceText.isEmpty ? "暂无" : sourceText}',
      '- 动作选项：${actionText.isEmpty ? "暂无" : actionText}',
      '- AI 模型：${modelsText.isEmpty ? "暂无" : modelsText}',
      if (upcoming.isNotEmpty) '未来 7 天待办：\n$upcoming',
      if (routinesText.isNotEmpty) '例行待办：\n$routinesText',
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
        input.trim() == '待办';
    return _LocalContext(
      triggered: true,
      promptContext:
          'app_data skill 已授权并已读取本应用本地数据库和本地配置。'
          '下面是可直接使用的真实应用数据快照，不是用户手工提供的文本：\n'
          '$fallback\n'
          '约束：只能基于上述数据分析；不要声称无法读取本应用数据。',
      fallbackAnswer: todoAnswer ?? fallback,
      directAnswer: directIntent ? (todoAnswer ?? fallback) : null,
    );
  }

  String? _buildTodoAnswer(String input, List<Todo> activeTodos) {
    if (!input.contains('代办') && !input.contains('待办')) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime target = today;
    var title = '今天';
    if (input.contains('明天')) {
      target = today.add(const Duration(days: 1));
      title = '明天';
    } else if (input.contains('后天')) {
      target = today.add(const Duration(days: 2));
      title = '后天';
    }
    final todos =
        activeTodos.where((item) => _sameDay(item.date, target)).toList()
          ..sort((a, b) => a.time.compareTo(b.time));
    final open = todos.where((item) => !item.completed).length;
    if (todos.isEmpty) {
      return '我已读取本地数据库，$title（${_fmt(target)}）没有待办。';
    }
    final lines = todos
        .map((item) {
          final tags = item.tags.isEmpty
              ? ''
              : ' ${item.tags.map((t) => '#${t.name}').join(' ')}';
          final action = _actionText(item.action);
          final source = _sourceText(item.source);
          return '- **${item.time}** ${item.completed ? "[已完成]" : "[未完成]"} ${item.title}$tags$action$source';
        })
        .join('\n');
    return '我已读取本地数据库，$title（${_fmt(target)}）共有 **${todos.length} 条**代办，其中未完成 **$open 条**：\n\n$lines';
  }

  String _sourceText(String source) {
    final label = switch (source.trim().toLowerCase()) {
      '' => '',
      'routine' => '例行',
      'ai' => 'AI',
      'recommend' => 'AI',
      'calendar' => '日历',
      'message' => '消息',
      'manual' => '手动',
      _ => source,
    };
    return label.isEmpty ? '' : ' 来源:$label';
  }

  String _actionText(String action) {
    final label = switch (action.trim().toLowerCase()) {
      '' => '',
      'none' => '',
      'bookkeeping' => '记账',
      'open_app' => '打开应用',
      'call' => '拨打电话',
      'message' => '发消息',
      _ => action,
    };
    return label.isEmpty ? '' : ' 动作:$label';
  }

  String _fmt(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _repeatLabel(String rule, String? days) {
    return switch (rule) {
      'daily' => '每天',
      'weekdays' => '工作日',
      'weekly' => '每周${days == null || days.isEmpty ? "" : "($days)"}',
      'monthly' => '每月${days == null || days.isEmpty ? "" : "($days)"}',
      _ => rule,
    };
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
