import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:uuid/uuid.dart';
import '../../../core/providers/core_providers.dart';
import '../../../domain/models/tag.dart';
import '../../../domain/models/todo.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/edge_swipe_pop.dart';
import '../../../shared/widgets/app_controls.dart';
import '../../ai_settings/ai_model_provider.dart';
import '../../copilot/services/openai_compatible_client.dart';
import '../providers/todo_provider.dart';
import '../services/todo_text_parser.dart';
import 'routine_tab.dart';
import '../../tags/tag_selector.dart';
import 'form_controls.dart';
import 'todo_reminder_controls.dart';

void showAddTodoModal(
  BuildContext context, {
  DateTime? initialDate,
  bool startVoiceInput = false,
  String? initialVoiceText,
}) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: '关闭',
    barrierColor: Colors.black.withValues(alpha: 0.12),
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (context, animation, secondaryAnimation) {
      return _AddTodoModalContent(
        initialDate: initialDate,
        startVoiceInput: startVoiceInput,
        initialVoiceText: initialVoiceText,
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      );
    },
  );
}

class _AddTodoModalContent extends ConsumerStatefulWidget {
  final DateTime? initialDate;
  final bool startVoiceInput;
  final String? initialVoiceText;

  const _AddTodoModalContent({
    this.initialDate,
    this.startVoiceInput = false,
    this.initialVoiceText,
  });

  @override
  ConsumerState<_AddTodoModalContent> createState() =>
      _AddTodoModalContentState();
}

class _AddTodoPageShell extends StatelessWidget {
  final Widget child;

  const _AddTodoPageShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return EdgeSwipePop(
      child: Material(
        color: Theme.of(context).colorScheme.appPage,
        child: child,
      ),
    );
  }
}

class _AddTodoHeader extends StatelessWidget {
  final VoidCallback? onSave;
  final bool saving;

  const _AddTodoHeader({required this.onSave, required this.saving});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 16, 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8B5CF6), Color(0xFF0A84FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.add_task_rounded,
              size: 18,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '新增',
              style: TextStyle(
                fontFamily: 'PingFang SC',
                fontFamilyFallback: const [
                  '.SF Pro Text',
                  'system-ui',
                  'sans-serif',
                ],
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: scheme.appText,
              ),
            ),
          ),
          AppRoundIconButton(
            tooltip: saving ? '保存中' : '保存',
            onPressed: onSave,
            icon: saving ? Icons.hourglass_top_rounded : Icons.check_rounded,
            foregroundColor: AppColors.primary,
          ),
          const SizedBox(width: 8),
          AppRoundIconButton(
            tooltip: '关闭',
            onPressed: () => Navigator.of(context).pop(),
            icon: Icons.close_rounded,
          ),
        ],
      ),
    );
  }
}

class _AddTodoTabBar extends StatelessWidget {
  final TabController controller;
  final Widget Function(int index, String label, IconData icon) itemBuilder;

  const _AddTodoTabBar({required this.controller, required this.itemBuilder});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 48,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: scheme.appControlSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.appBorder.withValues(alpha: 0.55)),
        ),
        child: Row(
          children: [
            Expanded(child: itemBuilder(0, '新增代办', Icons.check_circle_outline)),
            Expanded(child: itemBuilder(1, '例行代办', Icons.repeat_rounded)),
          ],
        ),
      ),
    );
  }
}

class _AddTodoModalContentState extends ConsumerState<_AddTodoModalContent>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final stt.SpeechToText _speech = stt.SpeechToText();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  List<Tag> _tags = [];
  String _source = 'ai';
  String _action = 'none';
  DateTime _date = DateTime.now();
  late String _time;
  Duration? _quickTime;
  int _priority = 0;
  bool _reminderEnabled = true;
  int _reminderMinutesBefore = Todo.defaultReminderMinutesForPriority(0);
  bool _reminderCustomized = false;
  bool _aiParsing = false;
  bool _saving = false;
  bool _speechReady = false;
  bool _isListening = false;
  bool _voiceVisible = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final initialDate = widget.initialDate;
    if (initialDate != null) {
      _date = DateTime(initialDate.year, initialDate.month, initialDate.day);
    }
    final now = DateTime.now();
    _time =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final initialVoiceText = widget.initialVoiceText?.trim() ?? '';
    if (initialVoiceText.isNotEmpty) {
      _descriptionController.text = initialVoiceText;
    }
    Future.microtask(() async {
      await _initSpeech();
      if (initialVoiceText.isNotEmpty && mounted) {
        await _applyAiParseFromText(
          initialVoiceText,
          preserveDescription: true,
        );
      } else if (widget.startVoiceInput && mounted) {
        await _toggleVoiceInput();
      }
    });
  }

  @override
  void dispose() {
    _speech.cancel();
    _tabController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    final available = await _speech.initialize(
      onStatus: (status) {
        if (!mounted) return;
        final listening = status == 'listening';
        setState(() => _isListening = listening);
      },
      onError: (_) {
        if (!mounted) return;
        setState(() => _isListening = false);
      },
    );
    if (!mounted) return;
    setState(() => _speechReady = available);
  }

  Future<void> _toggleVoiceInput() async {
    if (_isListening) {
      await _finishVoiceInput();
      return;
    }
    if (!_speechReady) {
      await _initSpeech();
    }
    if (!_speechReady) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前设备暂不可用语音识别，请检查麦克风/语音识别权限')),
        );
      }
      return;
    }
    setState(() {
      _voiceVisible = true;
      _isListening = true;
    });
    await _speech.listen(
      onResult: _handleSpeechResult,
      listenOptions: stt.SpeechListenOptions(
        localeId: 'zh_CN',
        listenFor: const Duration(seconds: 20),
        pauseFor: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _handleSpeechResult(SpeechRecognitionResult result) async {
    final text = result.recognizedWords.trim();
    if (!mounted || text.isEmpty) return;
    setState(() {
      _descriptionController.text = text;
      _descriptionController.selection = TextSelection.collapsed(
        offset: _descriptionController.text.length,
      );
      if (result.finalResult) {
        _isListening = false;
        _voiceVisible = false;
      }
    });
    if (result.finalResult) {
      await _applyAiParseFromText(text, preserveDescription: true);
    }
  }

  Future<void> _finishVoiceInput() async {
    await _speech.stop();
    final text = _descriptionController.text.trim();
    if (mounted) {
      setState(() {
        _isListening = false;
        _voiceVisible = false;
      });
    }
    if (text.isNotEmpty) {
      await _applyAiParseFromText(text, preserveDescription: true);
    }
  }

  Future<void> _dismissVoiceButton() async {
    if (!_voiceVisible) return;
    if (_isListening) {
      await _finishVoiceInput();
      return;
    }
    if (mounted) setState(() => _voiceVisible = false);
  }

  Future<void> _pickDateTime() async {
    final picked = await showGeneralDialog<DateTime>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭日期时间选择',
      barrierColor: Colors.black.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _TodoDateTimePickerDialog(initialValue: _selectedDateTime);
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
    if (picked != null) {
      setState(() {
        _date = DateTime(picked.year, picked.month, picked.day);
        _time =
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
        _quickTime = null;
      });
    }
  }

  DateTime get _selectedDateTime {
    final parts = _time.split(':');
    final hour = int.tryParse(parts.first) ?? 9;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return DateTime(_date.year, _date.month, _date.day, hour, minute);
  }

  void _applyQuickTime(Duration duration) {
    final next = DateTime.now().add(duration);
    setState(() {
      _date = DateTime(next.year, next.month, next.day);
      _time =
          '${next.hour.toString().padLeft(2, '0')}:${next.minute.toString().padLeft(2, '0')}';
      _quickTime = duration;
    });
  }

  Future<void> _saveManual() async {
    if (_saving) return;
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入标题')));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    final now = DateTime.now();
    final description = _descriptionController.text.trim();
    final todo = Todo(
      id: const Uuid().v4(),
      title: title,
      description: description.isEmpty ? null : description,
      source: _source,
      type: _tags.isNotEmpty ? _tags.first.name : 'personal',
      tags: _tags,
      action: _action,
      priority: _priority,
      reminderEnabled: _reminderEnabled,
      reminderMinutesBefore: _reminderMinutesBefore,
      time: _time,
      date: DateTime(_date.year, _date.month, _date.day),
      createdAt: now,
      updatedAt: now,
    );

    try {
      await ref.read(todoNotifierProvider.notifier).addTodo(todo);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('添加失败: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _applyAiParse() async {
    await _applyAiParseFromText(
      _titleController.text.trim(),
      preserveDescription: false,
    );
  }

  Future<void> _applyAiParseFromText(
    String text, {
    required bool preserveDescription,
  }) async {
    if (text.isEmpty) return;
    final config = ref.read(aiModelProvider).selected;
    if (config == null ||
        config.apiKey.trim().isEmpty ||
        config.baseUrl.trim().isEmpty ||
        config.model.trim().isEmpty) {
      _applyLocalParse(text, preserveDescription: preserveDescription);
      return;
    }
    setState(() => _aiParsing = true);
    try {
      final tags = await ref.read(allTagsProvider.future);
      final now = DateTime.now();
      final reply = await OpenAiCompatibleClient().chat(
        config: config,
        messages: [
          LlmChatMessage(
            role: 'system',
            content:
                '你是待办信息抽取器，只返回 JSON，不要 Markdown。'
                '字段：title, description, tagNames, date, time, source, action, priority。'
                'tagNames 从这些标签中选择 0 到 6 个：${tags.map((t) => t.name).join(", ")}。'
                'date 用 yyyy-MM-dd，time 用 HH:mm。'
                'source 只能是 ai, routine, calendar, message，默认 ai。'
                'action 只能是 none, bookkeeping, open_app, call, message。'
                'priority 只能是 0, 1, 2。'
                '今天是 ${DateFormat('yyyy-MM-dd').format(now)}。',
          ),
          LlmChatMessage(role: 'user', content: text),
        ],
      );
      final parsed = _decodeAiTodo(reply);
      final tagNames = (parsed['tagNames'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toSet();
      final matchedTags = tags
          .where((tag) => tagNames.contains(tag.name))
          .take(6)
          .toList();
      setState(() {
        _titleController.text = (parsed['title'] as String? ?? text).trim();
        _descriptionController.text = preserveDescription
            ? text
            : (parsed['description'] as String? ?? '').trim();
        _tags = matchedTags;
        _source = _validSource(parsed['source'] as String?);
        _action = _validAction(parsed['action'] as String?);
        _priority = ((parsed['priority'] as num?)?.toInt() ?? 0).clamp(0, 2);
        if (!_reminderCustomized) {
          _reminderMinutesBefore = Todo.defaultReminderMinutesForPriority(
            _priority,
          );
        }
        _time = _validTime(parsed['time'] as String?);
        _date = _validDate(parsed['date'] as String?) ?? _date;
      });
    } catch (_) {
      _applyLocalParse(text, preserveDescription: preserveDescription);
    } finally {
      if (mounted) setState(() => _aiParsing = false);
    }
  }

  void _applyLocalParse(String text, {bool preserveDescription = false}) {
    final result = TodoTextParser.parse(text);
    if (result.title.isEmpty) return;
    setState(() {
      _titleController.text = result.title;
      _descriptionController.text = preserveDescription
          ? text
          : result.description ?? '';
      _tags = [_tagForType(result.type)];
      _source = 'ai';
      _time = result.time;
      _date = result.date;
      _action = result.type == 'bill' ? 'bookkeeping' : 'none';
      _priority = result.date.difference(DateTime.now()).inHours <= 24 ? 1 : 0;
      if (!_reminderCustomized) {
        _reminderMinutesBefore = Todo.defaultReminderMinutesForPriority(
          _priority,
        );
      }
    });
  }

  Map<String, dynamic> _decodeAiTodo(String raw) {
    final trimmed = raw.trim();
    final match = RegExp(r'\{[\s\S]*\}').firstMatch(trimmed);
    final jsonText = match?.group(0) ?? trimmed;
    final decoded = jsonDecode(jsonText);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('AI 返回不是 JSON 对象');
    }
    return decoded;
  }

  String _validSource(String? value) {
    const values = {'ai', 'routine', 'calendar', 'message'};
    return values.contains(value) ? value! : 'ai';
  }

  String _validAction(String? value) {
    const values = {'none', 'bookkeeping', 'open_app', 'call', 'message'};
    return values.contains(value) ? value! : 'none';
  }

  String _validTime(String? value) {
    final match = RegExp(r'^(\d{1,2}):(\d{1,2})$').firstMatch(value ?? '');
    if (match == null) return _time;
    final hour = (int.tryParse(match.group(1) ?? '') ?? 9).clamp(0, 23);
    final minute = (int.tryParse(match.group(2) ?? '') ?? 0).clamp(0, 59);
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  DateTime? _validDate(String? value) {
    if (value == null) return null;
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  Tag _tagForType(String type) {
    final now = DateTime.now();
    switch (type) {
      case 'work':
        return Tag(
          id: 'tag-preset-work',
          name: '工作',
          colorKey: 'blue',
          createdAt: now,
          updatedAt: now,
        );
      case 'bill':
        return Tag(
          id: 'tag-preset-bill',
          name: '账单',
          colorKey: 'pink',
          createdAt: now,
          updatedAt: now,
        );
      case 'health':
        return Tag(
          id: 'tag-preset-health',
          name: '健康',
          colorKey: 'green',
          createdAt: now,
          updatedAt: now,
        );
      default:
        return Tag(
          id: 'tag-preset-personal',
          name: '个人',
          colorKey: 'purple',
          createdAt: now,
          updatedAt: now,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AddTodoPageShell(
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Stack(
            children: [
              Column(
                children: [
                  _AddTodoHeader(
                    onSave: _saving ? null : () => unawaited(_saveManual()),
                    saving: _saving,
                  ),
                  _AddTodoTabBar(
                    controller: _tabController,
                    itemBuilder: _buildTabItem,
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        Listener(
                          behavior: HitTestBehavior.translucent,
                          onPointerDown: (_) =>
                              unawaited(_dismissVoiceButton()),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _buildFormField(
                                    label: '标题',
                                    child: TextFormField(
                                      controller: _titleController,
                                      decoration: appInputDecoration(
                                        context: context,
                                        label: '',
                                        hintText: '输入待办事项…',
                                        suffixIcon: _aiParsing
                                            ? const Padding(
                                                padding: EdgeInsets.all(14),
                                                child: SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                ),
                                              )
                                            : AppIconTapButton(
                                                tooltip: '使用当前 AI 分析',
                                                onPressed: _applyAiParse,
                                                icon:
                                                    Icons.auto_awesome_rounded,
                                                iconSize: 18,
                                                foregroundColor:
                                                    AppColors.primary,
                                              ),
                                      ),
                                      validator: (value) {
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          return '请输入标题';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildFormField(
                                    label: '详情',
                                    child: TextFormField(
                                      controller: _descriptionController,
                                      decoration: appInputDecoration(
                                        context: context,
                                        label: '',
                                        hintText: '添加详细描述…',
                                      ),
                                      maxLines: 3,
                                      minLines: 2,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    '标签',
                                    style: TextStyle(
                                      fontFamily: 'PingFang SC',
                                      fontFamilyFallback: const [
                                        '.SF Pro Text',
                                        'system-ui',
                                        'sans-serif',
                                      ],
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.appMutedText,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  TagSelector(
                                    selectedTags: _tags,
                                    onChanged: (tags) =>
                                        setState(() => _tags = tags),
                                  ),
                                  const SizedBox(height: 16),
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      final compact =
                                          constraints.maxWidth < 560;
                                      final dateField = _buildFormField(
                                        label: '日期时间',
                                        child: _DateInputButton(
                                          value:
                                              '${DateFormat('MM-dd').format(_date)} $_time',
                                          onTap: _pickDateTime,
                                        ),
                                      );
                                      final quickField = _buildFormField(
                                        label: '快捷时间',
                                        child: _QuickTimeChips(
                                          selected: _quickTime,
                                          onSelected: _applyQuickTime,
                                        ),
                                      );
                                      if (compact) {
                                        return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            dateField,
                                            const SizedBox(height: 12),
                                            quickField,
                                          ],
                                        );
                                      }
                                      return Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(flex: 3, child: dateField),
                                          const SizedBox(width: 12),
                                          Expanded(flex: 7, child: quickField),
                                        ],
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  _buildFormField(
                                    label: '动作',
                                    child: ActionSelector(
                                      value: _action,
                                      onChanged: (value) =>
                                          setState(() => _action = value),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildFormField(
                                    label: '来源',
                                    child: SourceSelector(
                                      value: _source,
                                      onChanged: (value) =>
                                          setState(() => _source = value),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildFormField(
                                    label: '优先级',
                                    child: Row(
                                      children: [
                                        _buildPriorityChip(0, '普通'),
                                        const SizedBox(width: 8),
                                        _buildPriorityChip(1, '重要'),
                                        const SizedBox(width: 8),
                                        _buildPriorityChip(2, '紧急'),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildFormField(
                                    label: '提醒',
                                    child: TodoReminderSelector(
                                      enabled: _reminderEnabled,
                                      minutesBefore: _reminderMinutesBefore,
                                      onEnabledChanged: (value) {
                                        setState(() {
                                          _reminderEnabled = value;
                                          _reminderCustomized = true;
                                        });
                                      },
                                      onMinutesChanged: (value) {
                                        setState(() {
                                          _reminderMinutesBefore = value;
                                          _reminderCustomized = true;
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 32),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const RoutineTab(),
                      ],
                    ),
                  ),
                  _buildBottomActions(),
                ],
              ),
              _buildVoiceFabOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormField({required String label, required Widget child}) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontFamily: 'PingFang SC',
            fontFamilyFallback: const [
              '.SF Pro Text',
              'system-ui',
              'sans-serif',
            ],
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: scheme.appMutedText,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  Widget _buildPriorityChip(int priority, String label) {
    final isSelected = _priority == priority;
    final scheme = Theme.of(context).colorScheme;
    final Color bg;
    final Color fg;
    if (priority == 2) {
      bg = AppColors.danger;
      fg = Colors.white;
    } else if (priority == 1) {
      bg = AppColors.warning;
      fg = Colors.white;
    } else {
      bg = scheme.appInput;
      fg = scheme.appMutedText;
    }
    return GestureDetector(
      onTap: () => setState(() {
        _priority = priority;
        if (!_reminderCustomized) {
          _reminderMinutesBefore = Todo.defaultReminderMinutesForPriority(
            priority,
          );
        }
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? bg : bg.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? bg : bg.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'PingFang SC',
            fontFamilyFallback: const [
              '.SF Pro Text',
              'system-ui',
              'sans-serif',
            ],
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? fg : scheme.appMutedText,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActions() {
    return ListenableBuilder(
      listenable: _tabController,
      builder: (context, child) {
        if (_tabController.index != 0) return const SizedBox.shrink();
        return AppFloatingActionBar(
          actions: [
            AppBottomAction(
              label: _saving ? '保存中' : '保存',
              icon: _saving ? Icons.hourglass_top_rounded : Icons.check_rounded,
              onPressed: _saving ? () {} : () => unawaited(_saveManual()),
              tone: AppActionButtonTone.primary,
            ),
          ],
        );
      },
    );
  }

  Widget _buildVoiceFabOverlay() {
    return ListenableBuilder(
      listenable: _tabController,
      builder: (context, child) {
        if (_tabController.index != 0 || !_voiceVisible) {
          return const SizedBox.shrink();
        }
        return Positioned(
          left: 0,
          right: 0,
          bottom: 78,
          child: Center(
            child: AppVoiceInputFab(
              listening: _isListening,
              transcript: _descriptionController.text,
              onPressed: () => unawaited(_toggleVoiceInput()),
              onLongPressStart: () {},
              onLongPressEnd: () {},
              gradientColors: _isListening
                  ? const [Color(0xFFFF6B5E), Color(0xFFE11D48)]
                  : const [Color(0xFF14B8A6), Color(0xFF2563EB)],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabItem(int index, String label, IconData icon) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => _tabController.animateTo(index),
      child: ListenableBuilder(
        listenable: _tabController,
        builder: (context, child) {
          final isActive = _tabController.index == index;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: isActive ? scheme.appSurface : Colors.transparent,
              borderRadius: BorderRadius.horizontal(
                left: Radius.circular(index == 0 ? 13 : 4),
                right: Radius.circular(index == 1 ? 13 : 4),
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.10),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.72),
                        blurRadius: 2,
                        offset: const Offset(0, -1),
                      ),
                    ]
                  : [],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 17,
                  color: isActive ? scheme.primary : scheme.appSubtleText,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'PingFang SC',
                      fontFamilyFallback: const [
                        '.SF Pro Text',
                        'system-ui',
                        'sans-serif',
                      ],
                      fontSize: 14,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      color: isActive ? scheme.appText : scheme.appMutedText,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DateInputButton extends StatelessWidget {
  final String value;
  final VoidCallback onTap;

  const _DateInputButton({required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: scheme.appInput,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.appBorder),
        ),
        child: Row(
          children: [
            Icon(Icons.event_rounded, size: 18, color: scheme.appSubtleText),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Menlo',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: scheme.appText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickTimeChips extends StatelessWidget {
  final Duration? selected;
  final ValueChanged<Duration> onSelected;

  const _QuickTimeChips({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    const items = [
      ('一小时', Duration(hours: 1)),
      ('2小时', Duration(hours: 2)),
      ('5小时', Duration(hours: 5)),
      ('一天', Duration(days: 1)),
      ('一周', Duration(days: 7)),
    ];
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            Expanded(
              child: _QuickTimeChip(
                label: items[i].$1,
                selected: selected == items[i].$2,
                onTap: () => onSelected(items[i].$2),
              ),
            ),
            if (i != items.length - 1) const SizedBox(width: 5),
          ],
        ],
      ),
    );
  }
}

class _QuickTimeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _QuickTimeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: selected ? scheme.primary : scheme.appInput,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? scheme.primary : scheme.appBorder,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : const [],
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: selected ? scheme.onPrimary : scheme.appMutedText,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TodoDateTimePickerDialog extends StatefulWidget {
  final DateTime initialValue;

  const _TodoDateTimePickerDialog({required this.initialValue});

  @override
  State<_TodoDateTimePickerDialog> createState() =>
      _TodoDateTimePickerDialogState();
}

class _TodoDateTimePickerDialogState extends State<_TodoDateTimePickerDialog> {
  late DateTime _value;
  late bool _dateMode;
  late FixedExtentScrollController _dayController;
  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;
  late FixedExtentScrollController _yearController;
  late FixedExtentScrollController _monthController;
  late FixedExtentScrollController _dateDayController;

  static final _firstDay = DateTime(2020);
  static final _lastDay = DateTime(2030, 12, 31);

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
    _dateMode = false;
    _createControllers();
  }

  @override
  void dispose() {
    _dayController.dispose();
    _hourController.dispose();
    _minuteController.dispose();
    _yearController.dispose();
    _monthController.dispose();
    _dateDayController.dispose();
    super.dispose();
  }

  void _createControllers() {
    final dateIndex = _dayIndex(_value);
    _dayController = _controller(dateIndex);
    _hourController = _controller(_value.hour);
    _minuteController = _controller(_value.minute);
    _yearController = _controller(_value.year - 2020);
    _monthController = _controller(_value.month - 1);
    _dateDayController = _controller(_value.day - 1);
  }

  FixedExtentScrollController _controller(int initialItem) {
    return FixedExtentScrollController(
      initialItem: initialItem,
      keepScrollOffset: false,
    );
  }

  int _dayIndex(DateTime value) {
    final day = DateTime(value.year, value.month, value.day);
    return day.difference(_firstDay).inDays.clamp(0, _dayCount - 1);
  }

  int get _dayCount => _lastDay.difference(_firstDay).inDays + 1;

  void _toggleMode() {
    setState(() {
      _dateMode = !_dateMode;
      _yearController.dispose();
      _monthController.dispose();
      _dateDayController.dispose();
      _dayController.dispose();
      _yearController = _controller(_value.year - 2020);
      _monthController = _controller(_value.month - 1);
      _dateDayController = _controller(_value.day - 1);
      _dayController = _controller(_dayIndex(_value));
    });
  }

  void _setDate(DateTime date) {
    setState(() {
      _value = DateTime(
        date.year,
        date.month,
        date.day,
        _value.hour,
        _value.minute,
      );
    });
  }

  void _setYearMonthDay({int? year, int? month, int? day}) {
    final nextYear = year ?? _value.year;
    final nextMonth = month ?? _value.month;
    final maxDay = DateTime(nextYear, nextMonth + 1, 0).day;
    final nextDay = (day ?? _value.day).clamp(1, maxDay);
    setState(() {
      _value = DateTime(
        nextYear,
        nextMonth,
        nextDay,
        _value.hour,
        _value.minute,
      );
      if (day == null) {
        _dateDayController.dispose();
        _dateDayController = _controller(nextDay - 1);
      }
      _dayController.dispose();
      _dayController = _controller(_dayIndex(_value));
    });
  }

  void _setTime({int? hour, int? minute}) {
    setState(() {
      _value = DateTime(
        _value.year,
        _value.month,
        _value.day,
        hour ?? _value.hour,
        minute ?? _value.minute,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: math.min(width - 34, 430),
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(34),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 34,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: _toggleMode,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        _fullDateLabel(_value),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      _dateMode
                          ? Icons.arrow_drop_up_rounded
                          : Icons.arrow_drop_down_rounded,
                      size: 30,
                      color: AppColors.text,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 286,
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.center,
                      child: Container(
                        height: 70,
                        decoration: BoxDecoration(
                          border: Border.symmetric(
                            horizontal: BorderSide(
                              color: AppColors.border.withValues(alpha: 0.8),
                            ),
                          ),
                        ),
                      ),
                    ),
                    _dateMode ? _buildDateWheel() : _buildDateTimeWheel(),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: AppPointerTap(
                      onTap: () => Navigator.of(context).pop(),
                      child: const SizedBox(
                        height: 48,
                        child: Center(
                          child: Text(
                            '取消',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(width: 1, height: 36, color: AppColors.border),
                  Expanded(
                    child: AppPointerTap(
                      onTap: () => Navigator.of(context).pop(_value),
                      child: const SizedBox(
                        height: 48,
                        child: Center(
                          child: Text(
                            '确定',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateTimeWheel() {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: _wheel(
            controller: _dayController,
            count: _dayCount,
            onSelectedItemChanged: (index) =>
                _setDate(_firstDay.add(Duration(days: index))),
            itemBuilder: (index) =>
                _shortDateLabel(_firstDay.add(Duration(days: index))),
          ),
        ),
        Expanded(
          flex: 3,
          child: _wheel(
            controller: _hourController,
            count: 24,
            onSelectedItemChanged: (index) => _setTime(hour: index),
            itemBuilder: (index) => index.toString().padLeft(2, '0'),
          ),
        ),
        Expanded(
          flex: 3,
          child: _wheel(
            controller: _minuteController,
            count: 60,
            onSelectedItemChanged: (index) => _setTime(minute: index),
            itemBuilder: (index) => index.toString().padLeft(2, '0'),
          ),
        ),
      ],
    );
  }

  Widget _buildDateWheel() {
    final maxDay = DateTime(_value.year, _value.month + 1, 0).day;
    return Row(
      children: [
        Expanded(
          child: _wheel(
            controller: _yearController,
            count: 11,
            onSelectedItemChanged: (index) =>
                _setYearMonthDay(year: 2020 + index),
            itemBuilder: (index) => '${2020 + index}年',
          ),
        ),
        Expanded(
          child: _wheel(
            controller: _monthController,
            count: 12,
            onSelectedItemChanged: (index) =>
                _setYearMonthDay(month: index + 1),
            itemBuilder: (index) => '${index + 1}月',
          ),
        ),
        Expanded(
          child: _wheel(
            controller: _dateDayController,
            count: maxDay,
            onSelectedItemChanged: (index) => _setYearMonthDay(day: index + 1),
            itemBuilder: (index) => '${index + 1}日',
          ),
        ),
      ],
    );
  }

  Widget _wheel({
    required FixedExtentScrollController controller,
    required int count,
    required ValueChanged<int> onSelectedItemChanged,
    required String Function(int index) itemBuilder,
  }) {
    return CupertinoPicker.builder(
      scrollController: controller,
      itemExtent: 68,
      magnification: 1.12,
      squeeze: 1.08,
      useMagnifier: true,
      selectionOverlay: const SizedBox.shrink(),
      onSelectedItemChanged: onSelectedItemChanged,
      childCount: count,
      itemBuilder: (context, index) {
        return Center(
          child: Text(
            itemBuilder(index),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w900,
              color: AppColors.text,
            ),
          ),
        );
      },
    );
  }
}

String _shortDateLabel(DateTime date) => '${date.month}月${date.day}日';

String _fullDateLabel(DateTime date) {
  const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
  return '${date.year}年${date.month}月${date.day}日 星期${weekdays[date.weekday - 1]}';
}
