import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../domain/models/tag.dart';
import '../../../domain/models/todo.dart';
import '../../../shared/widgets/tag_chip.dart';
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

  @override
  Widget build(BuildContext context) {
    return EdgeSwipePop(
      child: Material(
        color: AppColors.surface,
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
                      IconButton(
                        tooltip: '返回',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      ),
                      Expanded(
                        child: Text(
                          _editing ? '编辑代办' : '代办详情',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: '关闭',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
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
    return Column(
      key: const ValueKey('view'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.todo.title,
          style: const TextStyle(
            fontFamily: 'PingFang SC',
            fontFamilyFallback: ['.SF Pro Text', 'system-ui', 'sans-serif'],
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 12),
        _buildSectionLabel('来源 & 标签'),
        const SizedBox(height: 4),
        Row(
          children: [
            _buildSourceBadge(widget.todo.source),
            const SizedBox(width: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: widget.todo.tags
                  .map(
                    (tag) => TagChip.fromTag(
                      label: tag.name,
                      colorKey: tag.colorKey,
                    ),
                  )
                  .toList(),
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
            style: const TextStyle(
              fontFamily: 'PingFang SC',
              fontFamilyFallback: ['.SF Pro Text', 'system-ui', 'sans-serif'],
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
        ],
        const SizedBox(height: 16),
        _buildSectionLabel('日期'),
        const SizedBox(height: 4),
        Text(
          DateFormat('yyyy-MM-dd').format(widget.todo.date),
          style: const TextStyle(
            fontFamily: 'PingFang SC',
            fontFamilyFallback: ['.SF Pro Text', 'system-ui', 'sans-serif'],
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        _buildSectionLabel('时间'),
        const SizedBox(height: 4),
        Text(
          widget.todo.time,
          style: const TextStyle(
            fontFamily: 'PingFang SC',
            fontFamilyFallback: ['.SF Pro Text', 'system-ui', 'sans-serif'],
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        _buildSectionLabel('动作'),
        const SizedBox(height: 4),
        _buildActionBadge(widget.todo.action),
        const SizedBox(height: 4),
        _buildSectionLabel('优先级'),
        const SizedBox(height: 4),
        _buildPriorityBadge(),
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
        const SizedBox(height: 16),
        _buildSectionLabel('详情'),
        const SizedBox(height: 6),
        TextFormField(
          controller: _descriptionController,
          decoration: _inputDecoration('添加详细描述…'),
          maxLines: 3,
          minLines: 2,
        ),
        const SizedBox(height: 16),
        _buildSectionLabel('标签'),
        const SizedBox(height: 6),
        TagSelector(
          selectedTags: _tags,
          onChanged: (tags) => setState(() => _tags = tags),
        ),
        const SizedBox(height: 16),
        _buildSectionLabel('日期'),
        const SizedBox(height: 6),
        InkWell(
          onTap: _pickDate,
          child: InputDecorator(
            decoration: _inputDecoration(''),
            child: Text(DateFormat('yyyy-MM-dd').format(_date)),
          ),
        ),
        const SizedBox(height: 16),
        _buildSectionLabel('时间'),
        const SizedBox(height: 6),
        TimeInputField(
          value: _time,
          onChanged: (value) => setState(() => _time = value),
        ),
        const SizedBox(height: 16),
        _buildSectionLabel('动作'),
        const SizedBox(height: 6),
        ActionSelector(
          value: _action,
          onChanged: (value) => setState(() => _action = value),
        ),
        const SizedBox(height: 16),
        _buildSectionLabel('来源'),
        const SizedBox(height: 6),
        SourceSelector(
          value: _source,
          onChanged: (value) => setState(() => _source = value),
        ),
        const SizedBox(height: 16),
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
    if (!_editing && widget.readOnly) {
      return _buildButtons(
        leftLabel: '关闭',
        leftOnPressed: () => Navigator.of(context).pop(),
        rightLabel: '关闭',
        rightOnPressed: () => Navigator.of(context).pop(),
      );
    }
    return _editing
        ? _buildButtons(
            leftLabel: '取消',
            leftOnPressed: () => setState(() => _editing = false),
            rightLabel: '保存',
            rightOnPressed: _save,
          )
        : _buildButtons(
            leftLabel: '关闭',
            leftOnPressed: () => Navigator.of(context).pop(),
            rightLabel: '编辑',
            rightOnPressed: () => setState(() => _editing = true),
          );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontFamily: 'PingFang SC',
        fontFamilyFallback: ['.SF Pro Text', 'system-ui', 'sans-serif'],
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textTertiary,
        letterSpacing: 0.5,
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: AppColors.inputBg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'PingFang SC',
          fontFamilyFallback: const ['.SF Pro Text', 'system-ui', 'sans-serif'],
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }

  Widget _buildActionBadge(String value) {
    final action = TodoActions.byValue(value);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: action.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: action.color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(action.icon, size: 14, color: action.color),
          const SizedBox(width: 5),
          Text(
            action.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: action.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceBadge(String value) {
    final source = TodoSources.byValue(value);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: source.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: source.color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(source.icon, size: 14, color: source.color),
          const SizedBox(width: 5),
          Text(
            _getSourceLabel(value),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: source.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityChip(int priority, String label) {
    final isSelected = _priority == priority;
    final Color bg;
    final Color fg;
    if (priority == 2) {
      bg = AppColors.danger;
      fg = Colors.white;
    } else if (priority == 1) {
      bg = AppColors.warning;
      fg = Colors.white;
    } else {
      bg = AppColors.inputBg;
      fg = AppColors.textSecondary;
    }
    return GestureDetector(
      onTap: () => setState(() => _priority = priority),
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
            color: isSelected ? fg : bg.withValues(alpha: 0.8),
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
    return Container(
      padding: const EdgeInsets.only(top: 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 44,
              child: ElevatedButton(
                onPressed: leftOnPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF0F0F5),
                  foregroundColor: AppColors.text,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: Text(
                  leftLabel,
                  style: const TextStyle(
                    fontFamily: 'PingFang SC',
                    fontFamilyFallback: [
                      '.SF Pro Text',
                      'system-ui',
                      'sans-serif',
                    ],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 44,
              child: ElevatedButton(
                onPressed: rightOnPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: Text(
                  rightLabel,
                  style: const TextStyle(
                    fontFamily: 'PingFang SC',
                    fontFamilyFallback: [
                      '.SF Pro Text',
                      'system-ui',
                      'sans-serif',
                    ],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
