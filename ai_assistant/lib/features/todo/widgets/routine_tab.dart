import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/models/routine.dart';
import '../providers/routine_provider.dart';
import '../services/todo_text_parser.dart';
import '../../../core/theme/app_theme.dart';

class RoutineTab extends ConsumerStatefulWidget {
  const RoutineTab({super.key});

  @override
  ConsumerState<RoutineTab> createState() => _RoutineTabState();
}

class _RoutineTabState extends ConsumerState<RoutineTab> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  String _type = 'work';
  String _repeatRule = 'daily';
  Set<int> _selectedWeekdays = {1, 2, 3, 4, 5}; // Mon-Fri default
  Set<int> _selectedMonthDays = {1}; // 1st default
  int _hour = 9;
  int _minute = 0;
  bool _showSmartInput = false;
  final _smartController = TextEditingController();

  static const _weekdayLabels = ['一', '二', '三', '四', '五', '六', '日'];
  static const _weekdayValues = [1, 2, 3, 4, 5, 6, 7];

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _smartController.dispose();
    super.dispose();
  }

  Future<void> _addRoutine() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    String? repeatDays;
    switch (_repeatRule) {
      case 'weekly':
        final sorted = _selectedWeekdays.toList()..sort();
        repeatDays = sorted.join(',');
        break;
      case 'monthly':
        final sorted = _selectedMonthDays.toList()..sort();
        repeatDays = sorted.join(',');
        break;
    }

    final routine = Routine(
      id: 0,
      title: title,
      description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
      type: _type,
      time: '${_hour.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}',
      repeatRule: _repeatRule,
      repeatDays: repeatDays,
      createdAt: DateTime.now(),
    );

    await ref.read(routineNotifierProvider.notifier).addRoutine(routine);
    _titleController.clear();
    _descController.clear();
    setState(() {
      _type = 'work';
      _repeatRule = 'daily';
      _hour = 9;
      _minute = 0;
      _selectedWeekdays = {1, 2, 3, 4, 5};
      _selectedMonthDays = {1};
      _showSmartInput = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已添加例行: $title'), duration: const Duration(seconds: 1)),
      );
    }
  }

  void _onSmartParsed(ParsedResult result) {
    setState(() {
      _titleController.text = result.title;
      _descController.text = result.description ?? '';
      _type = result.type == 'bill' ? 'bill' : result.type == 'health' ? 'health' : result.type == 'work' ? 'work' : 'personal';
      _hour = int.tryParse(result.time.split(':')[0]) ?? 9;
      _minute = int.tryParse(result.time.split(':')[1]) ?? 0;
      _repeatRule = 'daily';
      _showSmartInput = false;
    });
    _smartController.clear();
  }

  Future<void> _deleteRoutine(Routine routine) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除「${routine.title}」吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('删除', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(routineNotifierProvider.notifier).deleteRoutine(routine.id);
    }
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'bill': return '帐单';
      case 'work': return '工作';
      case 'personal': return '个人';
      case 'health': return '健康';
      default: return type;
    }
  }

  String _getRepeatLabel(String rule) {
    switch (rule) {
      case 'daily': return '每天';
      case 'weekdays': return '工作日';
      case 'weekly': return '每周';
      case 'monthly': return '每月';
      case 'custom': return '自定义';
      default: return rule;
    }
  }

  Widget _buildRepeatRulePicker() {
    final rules = [
      ('daily', '每天'),
      ('weekdays', '工作日'),
      ('weekly', '每周'),
      ('monthly', '每月'),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: rules.map((r) => ChoiceChip(
        label: Text(r.$2, style: const TextStyle(fontSize: 13)),
        selected: _repeatRule == r.$1,
        onSelected: (_) => setState(() => _repeatRule = r.$1),
        selectedColor: AppColors.primaryLight,
        labelStyle: TextStyle(
          color: _repeatRule == r.$1 ? AppColors.primary : AppColors.textSecondary,
          fontWeight: _repeatRule == r.$1 ? FontWeight.w600 : FontWeight.w400,
        ),
      )).toList(),
    );
  }

  Widget _buildWeekdayPicker() {
    return Wrap(
      spacing: 6,
      children: List.generate(7, (i) {
        final day = _weekdayValues[i];
        final selected = _selectedWeekdays.contains(day);
        return GestureDetector(
          onTap: () => setState(() {
            if (selected) {
              if (_selectedWeekdays.length > 1) _selectedWeekdays.remove(day);
            } else {
              _selectedWeekdays.add(day);
            }
          }),
          child: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : AppColors.inputBg,
              borderRadius: BorderRadius.circular(19),
              border: Border.all(color: selected ? AppColors.primary : AppColors.border),
            ),
            child: Center(child: Text(_weekdayLabels[i], style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: selected ? Colors.white : AppColors.textSecondary))),
          ),
        );
      }),
    );
  }

  Widget _buildMonthDayPicker() {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: List.generate(31, (i) {
        final day = i + 1;
        final selected = _selectedMonthDays.contains(day);
        return GestureDetector(
          onTap: () => setState(() {
            if (selected) {
              _selectedMonthDays.remove(day);
            } else {
              _selectedMonthDays.add(day);
            }
          }),
          child: Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : AppColors.inputBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: selected ? AppColors.primary : AppColors.border),
            ),
            child: Center(child: Text('$day', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: selected ? Colors.white : AppColors.textSecondary))),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final routines = ref.watch(routineNotifierProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 已有例行列表
          if (routines.isNotEmpty) ...[
            const Align(alignment: Alignment.centerLeft, child: Text('已有例行', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
            const SizedBox(height: 8),
            ...routines.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: AppColors.inputBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(6)),
                    child: Text(_getTypeLabel(r.type), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.primary)),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFE8F0FE), borderRadius: BorderRadius.circular(6)),
                    child: Text(_getRepeatLabel(r.repeatRule), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF1A73E8))),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(r.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
                  Text(r.time, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  const SizedBox(width: 6),
                  GestureDetector(onTap: () => _deleteRoutine(r), child: const Icon(Icons.close, size: 16, color: AppColors.textTertiary)),
                ]),
              ),
            )),
            const SizedBox(height: 16),
          ],

          // 智能输入切换
          Row(children: [
            const Text('添加例行', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const Spacer(),
            GestureDetector(
              onTap: () => setState(() => _showSmartInput = !_showSmartInput),
              child: Row(children: [
                Icon(Icons.auto_awesome, size: 14, color: _showSmartInput ? AppColors.primary : AppColors.textTertiary),
                const SizedBox(width: 2),
                Text('智能识别', style: TextStyle(fontSize: 12, color: _showSmartInput ? AppColors.primary : AppColors.textTertiary, fontWeight: FontWeight.w500)),
              ]),
            ),
          ]),
          const SizedBox(height: 8),

          if (_showSmartInput) ...[
            Container(
              padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
              decoration: BoxDecoration(color: AppColors.inputBg, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                Expanded(child: TextField(
                  controller: _smartController,
                  decoration: const InputDecoration(hintText: '例: 每天早上9点跑步', hintStyle: TextStyle(fontSize: 14, color: AppColors.textTertiary), border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8)),
                  style: const TextStyle(fontSize: 14, color: AppColors.text),
                  onSubmitted: (_) {
                    final result = TodoTextParser.parse(_smartController.text.trim());
                    if (result.title.isNotEmpty) _onSmartParsed(result);
                  },
                )),
                const SizedBox(width: 6),
                Container(width: 34, height: 34, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                  child: IconButton(onPressed: () { final r = TodoTextParser.parse(_smartController.text.trim()); if (r.title.isNotEmpty) _onSmartParsed(r); }, icon: const Icon(Icons.send, size: 12, color: Colors.white), padding: EdgeInsets.zero),
                ),
              ]),
            ),
            const SizedBox(height: 12),
          ],

          // 标题
          TextField(
            controller: _titleController,
            decoration: InputDecoration(hintText: '例: 周报撰写', filled: true, fillColor: AppColors.inputBg, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), isDense: true),
            onSubmitted: (_) => _addRoutine(),
          ),
          const SizedBox(height: 10),

          // 详情
          TextField(
            controller: _descController,
            decoration: InputDecoration(hintText: '详情（可选）', filled: true, fillColor: AppColors.inputBg, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), isDense: true),
          ),
          const SizedBox(height: 10),

          // 类型 + 时间
          Row(children: [
            Expanded(child: DropdownButtonFormField<String>(value: _type, isDense: true, decoration: InputDecoration(filled: true, fillColor: AppColors.inputBg, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary)), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10)), items: const [DropdownMenuItem(value: 'work', child: Text('工作', style: TextStyle(fontSize: 13))), DropdownMenuItem(value: 'personal', child: Text('个人', style: TextStyle(fontSize: 13))), DropdownMenuItem(value: 'bill', child: Text('帐单', style: TextStyle(fontSize: 13))), DropdownMenuItem(value: 'health', child: Text('健康', style: TextStyle(fontSize: 13)))], onChanged: (v) { if (v != null) setState(() => _type = v); })),
            const SizedBox(width: 8),
            SizedBox(width: 72, child: DropdownButtonFormField<int>(value: _hour, isDense: true, decoration: InputDecoration(filled: true, fillColor: AppColors.inputBg, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary)), contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10)), items: List.generate(24, (i) => DropdownMenuItem(value: i, child: Text('${i.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 13)))), onChanged: (v) { if (v != null) setState(() => _hour = v); })),
            const Text(':', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            SizedBox(width: 72, child: DropdownButtonFormField<int>(value: _minute, isDense: true, decoration: InputDecoration(filled: true, fillColor: AppColors.inputBg, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary)), contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10)), items: [0, 15, 30, 45].map((m) => DropdownMenuItem(value: m, child: Text(m.toString().padLeft(2, '0'), style: const TextStyle(fontSize: 13)))).toList(), onChanged: (v) { if (v != null) setState(() => _minute = v); })),
          ]),
          const SizedBox(height: 12),

          // 重复规则
          const Text('重复', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          _buildRepeatRulePicker(),
          const SizedBox(height: 8),

          // 条件选择器
          if (_repeatRule == 'weekly') ...[
            const SizedBox(height: 4),
            _buildWeekdayPicker(),
          ] else if (_repeatRule == 'monthly') ...[
            const SizedBox(height: 4),
            _buildMonthDayPicker(),
          ],
          const SizedBox(height: 16),

          // 添加按钮
          SizedBox(width: double.infinity, height: 44,
            child: ElevatedButton(onPressed: _addRoutine, style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))), child: const Text('添加', style: TextStyle(fontFamily: 'PingFang SC', fontSize: 14, fontWeight: FontWeight.w500))),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}