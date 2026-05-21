import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/models/routine.dart';
import '../providers/routine_provider.dart';

void showRoutineModal(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return const _RoutineModalContent();
    },
  );
}

class _RoutineModalContent extends ConsumerStatefulWidget {
  const _RoutineModalContent();

  @override
  ConsumerState<_RoutineModalContent> createState() => _RoutineModalContentState();
}

class _RoutineModalContentState extends ConsumerState<_RoutineModalContent> {
  bool _seeded = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final notifier = ref.read(routineNotifierProvider.notifier);
      await notifier.loadRoutines();
      final routines = ref.read(routineNotifierProvider);
      if (routines.isEmpty && !_seeded) {
        _seeded = true;
        final now = DateTime.now();
        await notifier.addRoutine(
          Routine(
            id: 0,
            title: '周报撰写',
            type: 'work',
            time: '14:30',
            createdAt: now,
          ),
        );
        await notifier.addRoutine(
          Routine(
            id: 0,
            title: '健身房训练',
            type: 'health',
            time: '18:30',
            createdAt: now,
          ),
        );
      }
    });
  }

  Future<void> _showAddDialog() async {
    final titleController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String type = 'work';
    int hour = 9;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('添加例行待办'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: '标题',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '请输入标题';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: type,
                      decoration: const InputDecoration(
                        labelText: '类型',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'bill', child: Text('帐单')),
                        DropdownMenuItem(value: 'work', child: Text('工作')),
                        DropdownMenuItem(value: 'personal', child: Text('个人')),
                        DropdownMenuItem(value: 'health', child: Text('健康')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            type = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: hour,
                      decoration: const InputDecoration(
                        labelText: '时间',
                        border: OutlineInputBorder(),
                      ),
                      items: List.generate(
                        24,
                        (i) => DropdownMenuItem(
                          value: i,
                          child: Text('${i.toString().padLeft(2, '0')}:00'),
                        ),
                      ),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            hour = value;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () {
                    if (!formKey.currentState!.validate()) return;
                    final routine = Routine(
                      id: 0,
                      title: titleController.text.trim(),
                      type: type,
                      time: '${hour.toString().padLeft(2, '0')}:00',
                      createdAt: DateTime.now(),
                    );
                    ref.read(routineNotifierProvider.notifier).addRoutine(routine);
                    Navigator.of(context).pop();
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDelete(Routine routine) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('确认删除'),
          content: Text('确定要删除 "${routine.title}" 吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      ref.read(routineNotifierProvider.notifier).deleteRoutine(routine.id);
    }
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'bill':
        return '帐单';
      case 'work':
        return '工作';
      case 'personal':
        return '个人';
      case 'health':
        return '健康';
      default:
        return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    final routines = ref.watch(routineNotifierProvider);

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
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D1D6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '例行管理',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: routines.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('暂无例行待办'),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: routines.length,
                      itemBuilder: (context, index) {
                      final routine = routines[index];
                      return ListTile(
                        title: Text(routine.title),
                        subtitle: Text(routine.time),
                        leading: Chip(
                          label: Text(
                            _getTypeLabel(routine.type),
                            style: const TextStyle(fontSize: 12),
                          ),
                          padding: EdgeInsets.zero,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _confirmDelete(routine),
                        ),
                      );
                    },
                  ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _showAddDialog,
                  child: const Text('添加例行待办'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
