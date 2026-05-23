import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../domain/models/routine.dart';
import '../../../domain/models/tag.dart';
import '../../../shared/widgets/tag_chip.dart';
import '../providers/routine_provider.dart';
import 'tag_selector.dart';

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
    List<Tag> tags = [];
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
                    TagSelector(
                      selectedTags: tags,
                      onChanged: (value) {
                        setState(() {
                          tags = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: hour,
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
                      type: tags.isNotEmpty ? tags.first.name : 'work',
                      tags: tags,
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

  Future<void> _showEditDialog(Routine routine) async {
    final titleController = TextEditingController(text: routine.title);
    final formKey = GlobalKey<FormState>();
    List<Tag> tags = List.from(routine.tags);
    final timeParts = routine.time.split(':');
    int hour = int.tryParse(timeParts[0]) ?? 9;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('编辑例行待办'),
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
                        if (value == null || value.trim().isEmpty) return '请输入标题';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TagSelector(
                      selectedTags: tags,
                      onChanged: (value) => setDialogState(() => tags = value),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: hour,
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
                        if (value != null) setDialogState(() => hour = value);
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
                    final newRoutine = routine.copyWith(
                      title: titleController.text.trim(),
                      type: tags.isNotEmpty ? tags.first.name : routine.type,
                      tags: tags,
                      time: '${hour.toString().padLeft(2, '0')}:00',
                      updatedAt: DateTime.now(),
                    );
                    ref.read(routineNotifierProvider.notifier).updateRoutine(newRoutine);
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
                        return _RoutineListItem(
                          routine: routine,
                          onEdit: () => _showEditDialog(routine),
                          onDelete: () => _confirmDelete(routine),
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

class _RoutineListItem extends StatelessWidget {
  final Routine routine;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RoutineListItem({
    required this.routine,
    required this.onEdit,
    required this.onDelete,
  });

  String _getTypeLabel(String type) {
    switch (type) {
      case 'bill': return '帐单';
      case 'work': return '工作';
      case 'personal': return '个人';
      case 'health': return '健康';
      default: return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SwipeToDeleteRoutine(
      onDelete: onDelete,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFE5E5EA), width: 0.5)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (routine.tags.isNotEmpty)
                        ...routine.tags.take(3).map((tag) => Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: TagChip.fromTag(label: tag.name, colorKey: tag.colorKey),
                        ))
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F2FD),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(_getTypeLabel(routine.type), style: const TextStyle(fontSize: 11, color: Color(0xFF4A90D9))),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(routine.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(routine.time, style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E93))),
                ],
              ),
            ),
            GestureDetector(
              onTap: onEdit,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: SvgPicture.asset(
                  'assets/icons/edit.svg',
                  width: 18,
                  height: 18,
                  colorFilter: const ColorFilter.mode(Color(0xFF8E8E93), BlendMode.srcIn),
                ),
              ),
            ),
          ],
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
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _animation = Tween<double>(begin: 0, end: 0).animate(
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
    _animation = Tween<double>(begin: _offset, end: target).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
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
                          color: const Color(0xFFFF3B30).withValues(alpha: 0.08),
                          border: Border.all(color: const Color(0xFFFF3B30).withValues(alpha: 0.25), width: 1.2),
                        ),
                        child: Center(
                          child: SvgPicture.asset(
                            'assets/icons/delete.svg',
                            width: 17,
                            height: 17,
                            colorFilter: const ColorFilter.mode(Color(0xFFFF3B30), BlendMode.srcIn),
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
