import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../domain/models/tag.dart';
import '../../../domain/models/todo.dart';
import '../../../shared/widgets/edge_swipe_pop.dart';
import '../../../shared/widgets/app_controls.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/todo_provider.dart';
import 'form_controls.dart';
import '../../tags/tag_selector.dart';

void showTodoDetail(BuildContext context, Todo todo, {bool readOnly = false}) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: '关闭',
    barrierColor: Colors.black.withValues(alpha: 0.12),
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (context, animation, secondaryAnimation) {
      return _TodoDetailSheet(todo: todo, readOnly: readOnly);
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

class _TodoDetailSheet extends ConsumerStatefulWidget {
  final Todo todo;
  final bool readOnly;

  const _TodoDetailSheet({required this.todo, this.readOnly = false});

  @override
  ConsumerState<_TodoDetailSheet> createState() => _TodoDetailSheetState();
}

class _TodoDetailSheetState extends ConsumerState<_TodoDetailSheet> {
  bool _editing = false;

  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  List<Tag> _tags = [];
  late String _source;
  late String _action;
  late DateTime _date;
  late String _time;
  late int _priority;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.todo.title);
    _descriptionController = TextEditingController(
      text: widget.todo.description ?? '',
    );
    _tags = List.from(widget.todo.tags);
    _source = widget.todo.source;
    _action = widget.todo.action;
    _date = widget.todo.date;
    _time = widget.todo.time;
    _priority = widget.todo.priority;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String _getSourceLabel(String source) {
    return TodoSources.byValue(source).label;
  }

  Future<void> _pickDate() async {
    final picked = await showAppDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) return;
    final updated = widget.todo.copyWith(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      type: _tags.isNotEmpty ? _tags.first.name : widget.todo.type,
      tags: _tags,
      source: _source,
      action: _action,
      date: DateTime(_date.year, _date.month, _date.day),
      priority: _priority,
      time: _time,
    );
    await ref.read(todoNotifierProvider.notifier).updateTodo(updated);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除待办'),
        content: Text('确定删除「${widget.todo.title}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(todoNotifierProvider.notifier).deleteTodo(widget.todo.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return EdgeSwipePop(
      child: Material(
        color: scheme.appPage,
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 14, 16, 10),
                  child: Row(
                    children: [
                      AppRoundIconButton(
                        tooltip: '返回',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icons.arrow_back_ios_new_rounded,
                      ),
                      Expanded(
                        child: Text(
                          _editing ? '编辑代办' : '代办详情',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: scheme.appText,
                          ),
                        ),
                      ),
                      AppRoundIconButton(
                        tooltip: '关闭',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icons.close_rounded,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 2, 20, 112),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: _editing ? _buildEditMode() : _buildViewMode(),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: _buildFixedBottomActions(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildViewMode() {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      key: const ValueKey('view'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.todo.title,
          style: TextStyle(
            fontFamily: 'PingFang SC',
            fontFamilyFallback: const [
              '.SF Pro Text',
              'system-ui',
              'sans-serif',
            ],
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: scheme.appText,
          ),
        ),
        const SizedBox(height: 12),
        _buildSectionLabel('来源 & 标签'),
        const SizedBox(height: 6),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _buildSourceBadge(widget.todo.source),
            ...widget.todo.tags.map(
              (tag) => _DetailChip(
                label: tag.name,
                icon: null,
                color: TagPalette.textColor(tag.colorKey),
                background: TagPalette.bgColor(tag.colorKey),
              ),
            ),
          ],
        ),
        if (widget.todo.description != null &&
            widget.todo.description!.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildSectionLabel('详情'),
          const SizedBox(height: 4),
          Text(
            widget.todo.description!,
            style: TextStyle(
              fontFamily: 'PingFang SC',
              fontFamilyFallback: const [
                '.SF Pro Text',
                'system-ui',
                'sans-serif',
              ],
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: scheme.appMutedText,
              height: 1.6,
            ),
          ),
        ],
        const SizedBox(height: 16),
        _DetailInfoRow(
          label: '时间',
          icon: Icons.schedule_rounded,
          value:
              '${DateFormat('yyyy-MM-dd').format(widget.todo.date)}  ${widget.todo.time}',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildActionBadge(widget.todo.action),
            _buildPriorityBadge(),
          ],
        ),
      ],
    );
  }

  Widget _buildEditMode() {
    return Column(
      key: const ValueKey('edit'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('标题'),
        const SizedBox(height: 6),
        TextFormField(
          controller: _titleController,
          decoration: _inputDecoration('输入待办事项…'),
        ),
        const SizedBox(height: 14),
        _buildSectionLabel('详情'),
        const SizedBox(height: 6),
        TextFormField(
          controller: _descriptionController,
          decoration: _inputDecoration('添加详细描述…'),
          maxLines: 3,
          minLines: 2,
        ),
        const SizedBox(height: 14),
        _buildSectionLabel('标签'),
        const SizedBox(height: 6),
        TagSelector(
          selectedTags: _tags,
          onChanged: (tags) => setState(() => _tags = tags),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionLabel('日期'),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(14),
                    child: InputDecorator(
                      decoration: _inputDecoration(''),
                      child: Text(DateFormat('yyyy-MM-dd').format(_date)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionLabel('时间'),
                  const SizedBox(height: 6),
                  TimeInputField(
                    value: _time,
                    onChanged: (value) => setState(() => _time = value),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _buildSectionLabel('动作'),
        const SizedBox(height: 6),
        ActionSelector(
          value: _action,
          onChanged: (value) => setState(() => _action = value),
        ),
        const SizedBox(height: 14),
        _buildSectionLabel('来源'),
        const SizedBox(height: 6),
        SourceSelector(
          value: _source,
          onChanged: (value) => setState(() => _source = value),
        ),
        const SizedBox(height: 14),
        _buildSectionLabel('优先级'),
        const SizedBox(height: 6),
        Row(
          children: [
            _buildPriorityChip(0, '普通'),
            const SizedBox(width: 8),
            _buildPriorityChip(1, '重要'),
            const SizedBox(width: 8),
            _buildPriorityChip(2, '紧急'),
          ],
        ),
      ],
    );
  }

  Widget _buildFixedBottomActions() {
    return _editing
        ? _buildButtons(
            leftLabel: '取消',
            leftOnPressed: () => setState(() => _editing = false),
            rightLabel: '保存',
            rightOnPressed: _save,
          )
        : _buildButtons(
            leftLabel: '删除',
            leftOnPressed: _delete,
            rightLabel: '编辑',
            rightOnPressed: () => setState(() => _editing = true),
          );
  }

  Widget _buildSectionLabel(String label) {
    final scheme = Theme.of(context).colorScheme;
    return Text(
      label,
      style: TextStyle(
        fontFamily: 'PingFang SC',
        fontFamilyFallback: const ['.SF Pro Text', 'system-ui', 'sans-serif'],
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: scheme.appSubtleText,
        letterSpacing: 0.5,
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return appInputDecoration(context: context, label: '', hintText: hint);
  }

  Widget _buildPriorityBadge() {
    final p = widget.todo.priority;
    final String label;
    final Color color;
    if (p >= 2) {
      label = '紧急';
      color = AppColors.danger;
    } else if (p >= 1) {
      label = '重要';
      color = AppColors.warning;
    } else {
      label = '普通';
      color = AppColors.textTertiary;
    }
    return _DetailChip(
      label: label,
      icon: Icons.flag_rounded,
      color: color,
      background: color,
    );
  }

  Widget _buildActionBadge(String value) {
    final action = TodoActions.byValue(value);
    return _DetailChip(
      label: action.label,
      icon: action.icon,
      color: action.color,
      background: action.color,
    );
  }

  Widget _buildSourceBadge(String value) {
    final source = TodoSources.byValue(value);
    return _DetailChip(
      label: _getSourceLabel(value),
      icon: source.icon,
      color: source.color,
      background: source.color,
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
      onTap: () => setState(() => _priority = priority),
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? bg : bg.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(17),
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

  Widget _buildButtons({
    required String leftLabel,
    required VoidCallback leftOnPressed,
    required String rightLabel,
    required VoidCallback rightOnPressed,
  }) {
    return AppFloatingActionBar(
      actions: [
        AppBottomAction(
          label: leftLabel,
          icon: leftLabel == '删除'
              ? Icons.delete_outline_rounded
              : Icons.close_rounded,
          onPressed: leftOnPressed,
          tone: leftLabel == '删除'
              ? AppActionButtonTone.danger
              : AppActionButtonTone.neutral,
        ),
        AppBottomAction(
          label: rightLabel,
          icon: rightLabel == '编辑' ? Icons.edit_rounded : Icons.check_rounded,
          onPressed: rightOnPressed,
          tone: AppActionButtonTone.primary,
        ),
      ],
    );
  }
}

class _DetailChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color color;
  final Color background;

  const _DetailChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: EdgeInsets.only(left: icon == null ? 12 : 10, right: 12),
      decoration: BoxDecoration(
        color: background.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontFamily: 'PingFang SC',
              fontFamilyFallback: const [
                '.SF Pro Text',
                'system-ui',
                'sans-serif',
              ],
              fontSize: 13,
              height: 1,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailInfoRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final String value;

  const _DetailInfoRow({
    required this.label,
    required this.icon,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 70,
          child: Row(
            children: [
              Icon(icon, size: 15, color: scheme.appSubtleText),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: scheme.appSubtleText,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontFamily: 'PingFang SC',
              fontFamilyFallback: const [
                '.SF Pro Text',
                'system-ui',
                'sans-serif',
              ],
              fontSize: 14,
              height: 1.2,
              fontWeight: FontWeight.w600,
              color: scheme.appMutedText,
            ),
          ),
        ),
      ],
    );
  }
}
