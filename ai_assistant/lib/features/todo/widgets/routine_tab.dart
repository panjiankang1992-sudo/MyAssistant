import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../domain/models/routine.dart';
import '../../../domain/models/tag.dart';
import '../../../shared/widgets/edge_swipe_pop.dart';
import '../../../core/providers/core_providers.dart';
import '../providers/routine_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../tags/tag_selector.dart';
import 'form_controls.dart';

Tag _typeToTag(String type, List<Tag> availableTags) {
  // 优先从真实标签中匹配
  final matched = availableTags.where((t) => t.name == type).firstOrNull;
  if (matched != null) return matched;
  // 兼容旧数据：真实标签尚未加载时也显示中文，不再暴露 personal/work 这类内部值。
  switch (type) {
    case 'bill':
      return Tag(
        id: 'fallback_bill',
        name: '账单',
        colorKey: 'pink',
        sortOrder: 0,
        isPreset: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    case 'work':
      return Tag(
        id: 'fallback_work',
        name: '工作',
        colorKey: 'blue',
        sortOrder: 0,
        isPreset: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    case 'personal':
      return Tag(
        id: 'fallback_personal',
        name: '个人',
        colorKey: 'purple',
        sortOrder: 0,
        isPreset: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    case 'health':
      return Tag(
        id: 'fallback_health',
        name: '健康',
        colorKey: 'green',
        sortOrder: 0,
        isPreset: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    default:
      return Tag(
        id: 'fallback_default',
        name: type,
        colorKey: 'blue',
        sortOrder: 0,
        isPreset: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
  }
}

Tag _defaultRoutineTag() {
  final now = DateTime.now();
  return Tag(
    id: 'tag-preset-personal',
    name: '个人',
    colorKey: 'purple',
    sortOrder: 0,
    isPreset: true,
    createdAt: now,
    updatedAt: now,
  );
}

InputDecoration _routinePlainInputDecoration(String hint) {
  return InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: AppColors.inputBg,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.primary),
    ),
  );
}

class _RoutineFieldBlock extends StatelessWidget {
  final String label;
  final Widget child;

  const _RoutineFieldBlock({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

// ============================================================
// 共用表单组件：标签 + 时间（滚轮选择）+ 重复规则
// ============================================================
class _RoutineFormFields extends StatefulWidget {
  final List<Tag> initialTags;
  final String initialTime; // 'HH:mm'
  final String initialAction;
  final String initialRepeatRule;
  final Set<int> initialWeekdays;
  final Set<int> initialMonthDays;
  final ValueChanged<List<Tag>> onTagsChanged;
  final ValueChanged<String> onTimeChanged; // 'HH:mm'
  final ValueChanged<String> onActionChanged;
  final void Function(String rule, Set<int> weekdays, Set<int> monthDays)
  onRepeatChanged;

  const _RoutineFormFields({
    required this.initialTags,
    required this.initialTime,
    required this.initialAction,
    required this.initialRepeatRule,
    required this.initialWeekdays,
    required this.initialMonthDays,
    required this.onTagsChanged,
    required this.onTimeChanged,
    required this.onActionChanged,
    required this.onRepeatChanged,
  });

  @override
  State<_RoutineFormFields> createState() => _RoutineFormFieldsState();
}

class _RoutineFormFieldsState extends State<_RoutineFormFields> {
  late String _repeatRule;
  late Set<int> _selectedWeekdays;
  late Set<int> _selectedMonthDays;
  late List<Tag> _selectedTags;

  static const _weekdayLabels = ['一', '二', '三', '四', '五', '六', '日'];
  static const _weekdayValues = [1, 2, 3, 4, 5, 6, 7];

  @override
  void initState() {
    super.initState();
    _repeatRule = widget.initialRepeatRule;
    _selectedWeekdays = Set.from(widget.initialWeekdays);
    _selectedMonthDays = Set.from(widget.initialMonthDays);
    _selectedTags = List.from(widget.initialTags);
  }

  @override
  Widget build(BuildContext context) {
    final repeatChips = Wrap(
      spacing: 8,
      runSpacing: 8,
      children:
          [
            ('daily', '每天'),
            ('weekdays', '工作日'),
            ('weekly', '每周'),
            ('monthly', '每月'),
          ].map((r) {
            final selected = _repeatRule == r.$1;
            return ChoiceChip(
              label: Text(r.$2, style: const TextStyle(fontSize: 13)),
              selected: selected,
              selectedColor: AppColors.primaryLight,
              onSelected: (_) {
                setState(() => _repeatRule = r.$1);
                widget.onRepeatChanged(
                  _repeatRule,
                  _selectedWeekdays,
                  _selectedMonthDays,
                );
              },
            );
          }).toList(),
    );
    Widget repeatOptions() {
      if (_repeatRule == 'weekly') {
        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Wrap(
            spacing: 6,
            children: List.generate(7, (i) {
              final day = _weekdayValues[i];
              final selected = _selectedWeekdays.contains(day);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (selected) {
                      if (_selectedWeekdays.length > 1) {
                        _selectedWeekdays.remove(day);
                      }
                    } else {
                      _selectedWeekdays.add(day);
                    }
                  });
                  widget.onRepeatChanged(
                    _repeatRule,
                    _selectedWeekdays,
                    _selectedMonthDays,
                  );
                },
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : AppColors.inputBg,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.border,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      _weekdayLabels[i],
                      style: TextStyle(
                        fontSize: 12,
                        color: selected
                            ? Colors.white
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      }
      if (_repeatRule == 'monthly') {
        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: List.generate(31, (i) {
              final day = i + 1;
              final selected = _selectedMonthDays.contains(day);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (selected) {
                      _selectedMonthDays.remove(day);
                    } else {
                      _selectedMonthDays.add(day);
                    }
                  });
                  widget.onRepeatChanged(
                    _repeatRule,
                    _selectedWeekdays,
                    _selectedMonthDays,
                  );
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : AppColors.inputBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.border,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '$day',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: selected
                            ? Colors.white
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      }
      return const SizedBox.shrink();
    }

    final timeField = _RoutineFieldBlock(
      label: '时间',
      child: TimeInputField(
        value: widget.initialTime,
        onChanged: widget.onTimeChanged,
      ),
    );
    final repeatField = _RoutineFieldBlock(
      label: '重复',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [repeatChips, repeatOptions()],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 560) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [timeField, const SizedBox(height: 12), repeatField],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: timeField),
                const SizedBox(width: 12),
                Expanded(flex: 6, child: repeatField),
              ],
            );
          },
        ),

        const SizedBox(height: 14),
        _RoutineFieldBlock(
          label: '标签',
          child: TagSelector(
            selectedTags: _selectedTags,
            onChanged: (tags) {
              setState(() => _selectedTags = tags);
              widget.onTagsChanged(List.unmodifiable(tags));
            },
          ),
        ),

        const SizedBox(height: 14),
        _RoutineFieldBlock(
          label: '动作',
          child: ActionSelector(
            value: widget.initialAction,
            onChanged: widget.onActionChanged,
          ),
        ),
      ],
    );
  }
}

PageRoute<T> _routineSidePageRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
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
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 240),
  );
}

class _RoutineEditorData {
  final String title;
  final String? description;
  final List<Tag> tags;
  final String time;
  final String action;
  final String repeatRule;
  final Set<int> weekdays;
  final Set<int> monthDays;

  const _RoutineEditorData({
    required this.title,
    required this.description,
    required this.tags,
    required this.time,
    required this.action,
    required this.repeatRule,
    required this.weekdays,
    required this.monthDays,
  });
}

String _normalizeRoutineTime(String raw) {
  final match = RegExp(r'^(\d{1,2})(?:[:：点](\d{1,2}))?$').firstMatch(raw);
  if (match == null) return '09:00';
  final hour = (int.tryParse(match.group(1) ?? '') ?? 9).clamp(0, 23);
  final minute = (int.tryParse(match.group(2) ?? '0') ?? 0).clamp(0, 59);
  return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

class _RoutineEditorPage extends StatefulWidget {
  final String title;
  final String saveLabel;
  final String initialTitle;
  final String initialDescription;
  final List<Tag> initialTags;
  final String initialTime;
  final String initialAction;
  final String initialRepeatRule;
  final Set<int> initialWeekdays;
  final Set<int> initialMonthDays;

  const _RoutineEditorPage({
    required this.title,
    required this.saveLabel,
    this.initialTitle = '',
    this.initialDescription = '',
    required this.initialTags,
    required this.initialTime,
    required this.initialAction,
    required this.initialRepeatRule,
    required this.initialWeekdays,
    required this.initialMonthDays,
  });

  @override
  State<_RoutineEditorPage> createState() => _RoutineEditorPageState();
}

class _RoutineEditorPageState extends State<_RoutineEditorPage> {
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  late List<Tag> _tags;
  late String _time;
  late String _action;
  late String _repeatRule;
  late Set<int> _weekdays;
  late Set<int> _monthDays;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _descController = TextEditingController(text: widget.initialDescription);
    _tags = List.from(widget.initialTags);
    _time = _normalizeRoutineTime(widget.initialTime);
    _action = widget.initialAction;
    _repeatRule = widget.initialRepeatRule;
    _weekdays = widget.initialWeekdays.isEmpty
        ? {1, 2, 3, 4, 5}
        : Set.from(widget.initialWeekdays);
    _monthDays = widget.initialMonthDays.isEmpty
        ? {1}
        : Set.from(widget.initialMonthDays);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请输入标题'),
          duration: Duration(milliseconds: 900),
        ),
      );
      return;
    }
    Navigator.of(context).pop(
      _RoutineEditorData(
        title: title,
        description: _descController.text.trim().isEmpty
            ? null
            : _descController.text.trim(),
        tags: List.unmodifiable(_tags),
        time: _time,
        action: _action,
        repeatRule: _repeatRule,
        weekdays: Set.unmodifiable(_weekdays),
        monthDays: Set.unmodifiable(_monthDays),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return EdgeSwipePop(
      child: Material(
        color: AppColors.surface,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 16, 10),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: '返回',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: const TextStyle(
                          fontFamily: 'PingFang SC',
                          fontFamilyFallback: [
                            '.SF Pro Text',
                            'system-ui',
                            'sans-serif',
                          ],
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '关闭',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppColors.text,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 2, 20, 110),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _RoutineFieldBlock(
                            label: '标题',
                            child: TextField(
                              controller: _titleController,
                              decoration: _routinePlainInputDecoration(
                                '输入例行待办标题',
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _RoutineFieldBlock(
                            label: '详情（可选）',
                            child: TextField(
                              controller: _descController,
                              decoration: _routinePlainInputDecoration(
                                '添加详细描述',
                              ),
                              minLines: 2,
                              maxLines: 3,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _RoutineFormFields(
                            initialTags: _tags,
                            initialTime: _time,
                            initialAction: _action,
                            initialRepeatRule: _repeatRule,
                            initialWeekdays: _weekdays,
                            initialMonthDays: _monthDays,
                            onTagsChanged: (tags) {
                              setState(() => _tags = tags);
                            },
                            onTimeChanged: (time) {
                              setState(() => _time = time);
                            },
                            onActionChanged: (value) {
                              setState(() => _action = value);
                            },
                            onRepeatChanged: (rule, wd, md) {
                              setState(() {
                                _repeatRule = rule;
                                _weekdays = Set.from(wd);
                                _monthDays = Set.from(md);
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
                        decoration: BoxDecoration(
                          color: AppColors.surface.withValues(alpha: 0.96),
                          border: const Border(
                            top: BorderSide(color: AppColors.border),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 18,
                              offset: const Offset(0, -8),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 46,
                                child: ElevatedButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.inputBg,
                                    foregroundColor: AppColors.text,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(24),
                                      side: const BorderSide(
                                        color: AppColors.border,
                                      ),
                                    ),
                                  ),
                                  child: const Text(
                                    '取消',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: SizedBox(
                                height: 46,
                                child: ElevatedButton(
                                  onPressed: _save,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                  ),
                                  child: Text(
                                    widget.saveLabel,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// RoutineTab
// ============================================================
class RoutineTab extends ConsumerStatefulWidget {
  const RoutineTab({super.key});

  @override
  ConsumerState<RoutineTab> createState() => _RoutineTabState();
}

class _RoutineTabState extends ConsumerState<RoutineTab> {
  List<Tag> _selectedTags = [];
  List<Tag> _availableTags = [];
  bool _tagsLoaded = false;

  Future<void> _loadTags() async {
    try {
      final repo = ref.read(tagRepoProvider);
      final tags = await repo.getAllTags();
      if (mounted && tags.isNotEmpty) {
        setState(() {
          _availableTags = tags;
          if (_selectedTags.isEmpty) _selectedTags = [tags.first];
        });
      }
    } catch (_) {
      // 静默失败，避免崩溃
    }
  }

  String? _repeatDaysFor(_RoutineEditorData data) {
    String? repeatDays;
    switch (data.repeatRule) {
      case 'weekly':
        final sorted = data.weekdays.toList()..sort();
        repeatDays = sorted.join(',');
        break;
      case 'monthly':
        final sorted = data.monthDays.toList()..sort();
        repeatDays = sorted.join(',');
        break;
    }
    return repeatDays;
  }

  List<Tag> _safeTags(List<Tag> tags) {
    return tags.isNotEmpty
        ? tags
        : [
            _availableTags.isNotEmpty
                ? _availableTags.first
                : _defaultRoutineTag(),
          ];
  }

  Future<void> _addRoutine(_RoutineEditorData data) async {
    final tags = _safeTags(data.tags);
    final tag = tags.first;
    final routine = Routine(
      id: 0,
      title: data.title,
      description: data.description,
      type: tag.name,
      tags: tags,
      action: data.action,
      time: data.time,
      repeatRule: data.repeatRule,
      repeatDays: _repeatDaysFor(data),
      createdAt: DateTime.now(),
    );

    await ref.read(routineNotifierProvider.notifier).addRoutine(routine);
    setState(
      () => _selectedTags = _availableTags.isNotEmpty
          ? [_availableTags.first]
          : [],
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已添加例行: ${data.title}'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _showAddDialog() async {
    final initialTags = _availableTags.isNotEmpty
        ? [_availableTags.first]
        : <Tag>[];
    final data = await Navigator.of(context).push<_RoutineEditorData>(
      _routineSidePageRoute(
        _RoutineEditorPage(
          title: '新增例行待办',
          saveLabel: '保存',
          initialTags: initialTags,
          initialTime: '09:00',
          initialAction: 'none',
          initialRepeatRule: 'daily',
          initialWeekdays: const {1, 2, 3, 4, 5},
          initialMonthDays: const {1},
        ),
      ),
    );
    if (data != null) await _addRoutine(data);
  }

  Future<void> _deleteRoutine(Routine routine) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除「${routine.title}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(routineNotifierProvider.notifier).deleteRoutine(routine.id);
    }
  }

  Future<void> _showEditDialog(Routine routine) async {
    final List<Tag> editTags = routine.tags.isNotEmpty
        ? List.from(routine.tags)
        : [_typeToTag(routine.type, _availableTags)];
    final editRepeatRule = routine.repeatRule;
    final editAction = routine.action;
    Set<int> editWeekdays = {};
    Set<int> editMonthDays = {};
    final editTime = _normalizeRoutineTime(routine.time);

    // Parse existing repeat days
    if (routine.repeatDays != null && routine.repeatDays!.isNotEmpty) {
      if (editRepeatRule == 'weekly') {
        editWeekdays = routine.repeatDays!
            .split(',')
            .map((s) => int.tryParse(s.trim()) ?? 0)
            .toSet();
      } else if (editRepeatRule == 'monthly') {
        editMonthDays = routine.repeatDays!
            .split(',')
            .map((s) => int.tryParse(s.trim()) ?? 0)
            .toSet();
      }
    } else {
      editWeekdays = {1, 2, 3, 4, 5};
      editMonthDays = {1};
    }

    final data = await Navigator.of(context).push<_RoutineEditorData>(
      _routineSidePageRoute(
        _RoutineEditorPage(
          title: '编辑例行待办',
          saveLabel: '保存修改',
          initialTitle: routine.title,
          initialDescription: routine.description ?? '',
          initialTags: editTags,
          initialTime: editTime,
          initialAction: editAction,
          initialRepeatRule: editRepeatRule,
          initialWeekdays: editWeekdays,
          initialMonthDays: editMonthDays,
        ),
      ),
    );
    if (data == null) return;
    final tags = _safeTags(data.tags);
    final tag = tags.first;
    final newRoutine = routine.copyWith(
      title: data.title,
      description: data.description,
      type: tag.name,
      tags: tags,
      action: data.action,
      time: data.time,
      repeatRule: data.repeatRule,
      repeatDays: _repeatDaysFor(data),
      updatedAt: DateTime.now(),
    );
    ref.read(routineNotifierProvider.notifier).updateRoutine(newRoutine);
  }

  @override
  Widget build(BuildContext context) {
    final routines = ref.watch(routineNotifierProvider);
    // 动态加载 tags 表数据（使用 addPostFrameCallback 避免在 build 中调用 ref.watch）
    if (!_tagsLoaded) {
      _tagsLoaded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadTags();
      });
    }

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 104),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 已有例行列表
              if (routines.isNotEmpty) ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '已有例行',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ...routines.map(
                  (r) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _RoutineListItem(
                      routine: r,
                      onEdit: () => _showEditDialog(r),
                      onDelete: () => _deleteRoutine(r),
                      availableTags: _availableTags,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 12,
          child: Container(
            padding: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.96),
              boxShadow: [
                BoxShadow(
                  color: AppColors.surface.withValues(alpha: 0.96),
                  blurRadius: 18,
                  spreadRadius: 12,
                  offset: const Offset(0, -8),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: _showAddDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: const Text(
                  '新增例行',
                  style: TextStyle(
                    fontFamily: 'PingFang SC',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RoutineListItem extends StatelessWidget {
  final Routine routine;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final List<Tag> availableTags;

  const _RoutineListItem({
    required this.routine,
    required this.onEdit,
    required this.onDelete,
    required this.availableTags,
  });

  String _getRepeatLabel(String rule) {
    switch (rule) {
      case 'daily':
        return '每天';
      case 'weekdays':
        return '工作日';
      case 'weekly':
        return '每周';
      case 'monthly':
        return '每月';
      case 'custom':
        return '自定义';
      default:
        return rule;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tags = routine.tags.isNotEmpty
        ? routine.tags
        : [_typeToTag(routine.type, availableTags)];
    return _SwipeToDeleteRoutine(
      onDelete: onDelete,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onEdit,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      routine.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                    if (routine.description != null &&
                        routine.description!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        routine.description!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule,
                          size: 13,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          routine.time,
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'Menlo',
                            color: AppColors.textTertiary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F0FE),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _getRepeatLabel(routine.repeatRule),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF1A73E8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Wrap(
                            spacing: 5,
                            runSpacing: 4,
                            children: tags
                                .take(3)
                                .map((tag) => _RoutineMiniTag(tag: tag))
                                .toList(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const SizedBox(
                width: 32,
                child: Center(
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 22,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoutineMiniTag extends StatelessWidget {
  final Tag tag;

  const _RoutineMiniTag({required this.tag});

  @override
  Widget build(BuildContext context) {
    final fg = TagPalette.textColor(tag.colorKey);
    final bg = TagPalette.bgColor(tag.colorKey);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        tag.name,
        style: TextStyle(
          fontSize: 11,
          height: 1.1,
          fontWeight: FontWeight.w600,
          color: fg.withValues(alpha: 0.88),
        ),
      ),
    );
  }
}

class _SwipeToDeleteRoutine extends StatefulWidget {
  final VoidCallback onDelete;
  final Widget child;

  const _SwipeToDeleteRoutine({required this.onDelete, required this.child});

  @override
  State<_SwipeToDeleteRoutine> createState() => _SwipeToDeleteRoutineState();
}

class _SwipeToDeleteRoutineState extends State<_SwipeToDeleteRoutine>
    with SingleTickerProviderStateMixin {
  double _offset = 0;
  bool _dragging = false;
  late AnimationController _controller;
  late Animation<double> _animation;

  static const double _deleteWidth = 76.0;
  static const double _triggerThreshold = 40.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _animation =
        Tween<double>(begin: 0, end: 0).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeOut),
        )..addListener(() {
          if (!_dragging) setState(() => _offset = _animation.value);
        });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _animateTo(double target) {
    _animation = Tween<double>(
      begin: _offset,
      end: target,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final showDelete = _offset < -10;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (showDelete)
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 0),
              child: Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: _deleteWidth,
                  height: double.infinity,
                  child: Center(
                    child: GestureDetector(
                      onTap: () {
                        _animateTo(0);
                        widget.onDelete();
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(
                            0xFFFF3B30,
                          ).withValues(alpha: 0.08),
                          border: Border.all(
                            color: const Color(
                              0xFFFF3B30,
                            ).withValues(alpha: 0.25),
                            width: 1.2,
                          ),
                        ),
                        child: Center(
                          child: SvgPicture.asset(
                            'assets/icons/delete.svg',
                            width: 17,
                            height: 17,
                            colorFilter: const ColorFilter.mode(
                              Color(0xFFFF3B30),
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        GestureDetector(
          onHorizontalDragStart: (_) => _dragging = true,
          onHorizontalDragUpdate: (details) {
            setState(() {
              _offset += details.delta.dx;
              if (_offset > 0) _offset = 0;
              if (_offset < -_deleteWidth) _offset = -_deleteWidth;
            });
          },
          onHorizontalDragEnd: (details) {
            _dragging = false;
            if (_offset < -_triggerThreshold) {
              _animateTo(-_deleteWidth);
            } else {
              _animateTo(0);
            }
          },
          child: Transform.translate(
            offset: Offset(_offset, 0),
            child: widget.child,
          ),
        ),
      ],
    );
  }
}
