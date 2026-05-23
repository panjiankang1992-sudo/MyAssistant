import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../domain/models/tag.dart';
import '../../../domain/models/todo.dart';
import '../../../shared/widgets/tag_chip.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/todo_provider.dart';
import 'tag_selector.dart';

void showTodoDetail(BuildContext context, Todo todo, {bool readOnly = false}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return _TodoDetailSheet(todo: todo, readOnly: readOnly);
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

class _TodoDetailSheetState extends ConsumerState<_TodoDetailSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _springController;
  late Animation<double> _springAnimation;
  bool _editing = false;

  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  List<Tag> _tags = [];
  late String _source;
  late DateTime _date;
  late int _hour;
  late int _minute;

  @override
  void initState() {
    super.initState();
    _springController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _springAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _springController, curve: Curves.elasticOut),
    );
    _springController.forward();

    _titleController = TextEditingController(text: widget.todo.title);
    _descriptionController = TextEditingController(text: widget.todo.description ?? '');
    _tags = List.from(widget.todo.tags);
    _source = widget.todo.source;
    _date = widget.todo.date;
    final timeParts = widget.todo.time.split(':');
    _hour = int.tryParse(timeParts.first) ?? 9;
    _minute = int.tryParse(timeParts.elementAt(1)) ?? 0;
  }

  @override
  void dispose() {
    _springController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String _getSourceLabel(String source) {
    switch (source) {
      case 'recommend': return '推荐';
      case 'routine': return '例行';
      case 'message': return '消息';
      case 'calendar': return '日历';
      case 'manual': return '手动';
      default: return source;
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
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
      description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      type: _tags.isNotEmpty ? _tags.first.name : widget.todo.type,
      tags: _tags,
      source: _source,
      date: DateTime(_date.year, _date.month, _date.day),
      time: '${_hour.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}',
    );
    await ref.read(todoNotifierProvider.notifier).updateTodo(updated);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity! > 300) {
          Navigator.of(context).pop();
        }
      },
      child: AnimatedBuilder(
        animation: _springAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _springAnimation.value,
            child: child,
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: AppAnimations.elevatedShadow(),
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 8,
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _editing ? _buildEditMode() : _buildViewMode(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildViewMode() {
    return Column(
      key: const ValueKey('view'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(child: _buildHandle()),
        const SizedBox(height: 16),
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
        Row(children: [
          TagChip(label: _getSourceLabel(widget.todo.source), type: 'source', value: widget.todo.source),
          const SizedBox(width: 8),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: widget.todo.tags.map((tag) => TagChip.fromTag(label: tag.name, colorKey: tag.colorKey)).toList(),
          ),
        ]),
        if (widget.todo.description != null && widget.todo.description!.isNotEmpty) ...[
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
        const SizedBox(height: 20),
        if (widget.readOnly)
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF0F0F5),
                foregroundColor: AppColors.text,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              ),
              child: const Text('关闭', style: TextStyle(fontFamily: 'PingFang SC', fontFamilyFallback: ['.SF Pro Text', 'system-ui', 'sans-serif'], fontSize: 14, fontWeight: FontWeight.w500)),
            ),
          )
        else
          _buildButtons(
            leftLabel: '关闭',
            leftOnPressed: () => Navigator.of(context).pop(),
            rightLabel: '编辑',
            rightOnPressed: () => setState(() => _editing = true),
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildEditMode() {
    return SingleChildScrollView(
      key: const ValueKey('edit'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: _buildHandle()),
          const SizedBox(height: 16),
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
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                value: _hour,
                decoration: _inputDecoration(''),
                items: List.generate(24, (i) => DropdownMenuItem(value: i, child: Text(i.toString().padLeft(2, '0')))),
                onChanged: (v) { if (v != null) setState(() => _hour = v); },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<int>(
                value: _minute,
                decoration: _inputDecoration(''),
                items: List.generate(60, (i) => DropdownMenuItem(value: i, child: Text(i.toString().padLeft(2, '0')))),
                onChanged: (v) { if (v != null) setState(() => _minute = v); },
              ),
            ),
          ]),
          const SizedBox(height: 16),
          _buildSectionLabel('来源'),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _source,
            decoration: _inputDecoration(''),
            items: const [
              DropdownMenuItem(value: 'recommend', child: Text('推荐')),
              DropdownMenuItem(value: 'manual', child: Text('手动')),
              DropdownMenuItem(value: 'routine', child: Text('例行')),
              DropdownMenuItem(value: 'message', child: Text('消息')),
              DropdownMenuItem(value: 'calendar', child: Text('日历')),
            ],
            onChanged: (v) { if (v != null) setState(() => _source = v); },
          ),
          const SizedBox(height: 20),
          _buildButtons(
            leftLabel: '取消',
            leftOnPressed: () => setState(() => _editing = false),
            rightLabel: '保存',
            rightOnPressed: _save,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildHandle() {
    return Container(
      width: 36,
      height: 5,
      decoration: BoxDecoration(
        color: AppColors.handleBar,
        borderRadius: BorderRadius.circular(3),
      ),
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
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
      child: Row(children: [
        Expanded(
          child: SizedBox(
            height: 44,
            child: ElevatedButton(
              onPressed: leftOnPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF0F0F5),
                foregroundColor: AppColors.text,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              ),
              child: Text(leftLabel, style: const TextStyle(fontFamily: 'PingFang SC', fontFamilyFallback: ['.SF Pro Text', 'system-ui', 'sans-serif'], fontSize: 14, fontWeight: FontWeight.w500)),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              ),
              child: Text(rightLabel, style: const TextStyle(fontFamily: 'PingFang SC', fontFamilyFallback: ['.SF Pro Text', 'system-ui', 'sans-serif'], fontSize: 14, fontWeight: FontWeight.w500)),
            ),
          ),
        ),
      ]),
    );
  }
}
