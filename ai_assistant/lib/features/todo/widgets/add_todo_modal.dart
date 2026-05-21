import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../domain/models/todo.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/todo_provider.dart';
import '../services/todo_text_parser.dart';
import 'smart_input.dart';
import 'routine_tab.dart';

void showAddTodoModal(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      return const _AddTodoModalContent();
    },
  );
}

class _AddTodoModalContent extends ConsumerStatefulWidget {
  const _AddTodoModalContent();

  @override
  ConsumerState<_AddTodoModalContent> createState() => _AddTodoModalContentState();
}

class _AddTodoModalContentState extends ConsumerState<_AddTodoModalContent>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String _type = 'personal';
  String _source = 'recommend';
  DateTime _date = DateTime.now();
  int _hour = 9;
  int _minute = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _date = picked;
      });
    }
  }

  Future<void> _saveManual() async {
    if (!_formKey.currentState!.validate()) return;

    final now = DateTime.now();
    final time =
        '${_hour.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}';

    final todo = Todo(
      id: const Uuid().v4(),
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      source: _source,
      type: _type,
      time: time,
      date: DateTime(_date.year, _date.month, _date.day),
      createdAt: now,
      updatedAt: now,
    );

    try {
      await ref.read(todoNotifierProvider.notifier).addTodo(todo);
      if (context.mounted) Navigator.of(context).pop();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('添加失败: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _onSmartParsed(ParsedResult result) async {
    try {
      final now = DateTime.now();

      final todo = Todo(
        id: const Uuid().v4(),
        title: result.title,
        description: result.description,
        source: result.source,
        type: result.type,
        time: result.time,
        date: result.date,
        createdAt: now,
        updatedAt: now,
      );

      await ref.read(todoNotifierProvider.notifier).addTodo(todo);
      if (context.mounted) Navigator.of(context).pop();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('添加失败: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 5,
                margin: const EdgeInsets.only(top: 8, bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.handleBar,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F0F5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Expanded(child: _buildTabItem(0, '智能新增')),
                    Expanded(child: _buildTabItem(1, '手动新增')),
                    Expanded(child: _buildTabItem(2, '例行管理')),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 480,
              child: TabBarView(
                controller: _tabController,
                children: [
                  SmartInput(onParsed: _onSmartParsed),
                  SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildFormField(
                            label: '标题',
                            child: TextFormField(
                              controller: _titleController,
                              decoration: InputDecoration(
                                hintText: '输入待办事项…',
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
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
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
                              decoration: InputDecoration(
                                hintText: '添加详细描述…',
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
                              ),
                              maxLines: 3,
                              minLines: 2,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildFormField(
                            label: '类型',
                            child: DropdownButtonFormField<String>(
                              value: _type,
                              decoration: InputDecoration(
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
                              ),
                              items: const [
                                DropdownMenuItem(value: 'work', child: Text('工作')),
                                DropdownMenuItem(value: 'personal', child: Text('个人')),
                                DropdownMenuItem(value: 'bill', child: Text('帐单')),
                                DropdownMenuItem(value: 'health', child: Text('健康')),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _type = value;
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildFormField(
                            label: '日期',
                            child: InkWell(
                              onTap: _pickDate,
                              child: InputDecorator(
                                decoration: InputDecoration(
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
                                ),
                                child: Text(DateFormat('yyyy-MM-dd').format(_date)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildFormField(
                            label: '时间',
                            child: Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<int>(
                                    value: _hour,
                                    decoration: InputDecoration(
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
                                    ),
                                    items: List.generate(
                                      24,
                                      (i) => DropdownMenuItem(
                                        value: i,
                                        child: Text(i.toString().padLeft(2, '0')),
                                      ),
                                    ),
                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(() {
                                          _hour = value;
                                        });
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<int>(
                                    value: _minute,
                                    decoration: InputDecoration(
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
                                    ),
                                    items: List.generate(
                                      60,
                                      (i) => DropdownMenuItem(
                                        value: i,
                                        child: Text(i.toString().padLeft(2, '0')),
                                      ),
                                    ),
                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(() {
                                          _minute = value;
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
const SizedBox(height: 16),
                          _buildFormField(
                            label: '来源',
                            child: DropdownButtonFormField<String>(
                              value: _source,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: AppColors.inputBg,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'recommend', child: Text('推荐')),
                                DropdownMenuItem(value: 'manual', child: Text('手动')),
                                DropdownMenuItem(value: 'routine', child: Text('例行')),
                                DropdownMenuItem(value: 'message', child: Text('消息')),
                                DropdownMenuItem(value: 'calendar', child: Text('日历')),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _source = value;
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 44,
                                  child: ElevatedButton(
                                    onPressed: () => Navigator.of(context).pop(),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFF0F0F5),
                                      foregroundColor: AppColors.text,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(25),
                                      ),
                                    ),
                                    child: const Text(
                                      '取消',
                                      style: TextStyle(
                                        fontFamily: 'PingFang SC',
                                        fontFamilyFallback: ['.SF Pro Text', 'system-ui', 'sans-serif'],
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
                                    onPressed: _saveManual,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(25),
                                      ),
                                    ),
                                    child: const Text(
                                      '保存',
                                      style: TextStyle(
                                        fontFamily: 'PingFang SC',
                                        fontFamilyFallback: ['.SF Pro Text', 'system-ui', 'sans-serif'],
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                  // 例行管理 tab
                  const RoutineTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontFamily: 'PingFang SC',
            fontFamilyFallback: ['.SF Pro Text', 'system-ui', 'sans-serif'],
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  Widget _buildTabItem(int index, String label) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _tabController.animateTo(index),
        child: ListenableBuilder(
          listenable: _tabController,
          builder: (_, __) {
            final isActive = _tabController.index == index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: isActive ? AppColors.surface : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                boxShadow: isActive
                    ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 3, offset: const Offset(0, 1))]
                    : [],
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'PingFang SC',
                    fontFamilyFallback: const ['.SF Pro Text', 'system-ui', 'sans-serif'],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isActive ? AppColors.text : AppColors.textSecondary,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}