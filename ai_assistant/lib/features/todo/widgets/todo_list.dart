import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models/todo.dart';
import '../../../shared/widgets/app_controls.dart';
import '../../../shared/widgets/empty_state.dart';
import 'todo_item.dart';

class TodoList extends StatelessWidget {
  final List<Todo> todos;
  final bool isLoading;
  final bool readOnly;
  final void Function(Todo) onToggle;
  final void Function(Todo) onDelete;
  final void Function(Todo) onTap;
  final void Function(Todo) onActionTap;
  final void Function(Todo) onComplete;
  final void Function(Todo) onDefer;

  const TodoList({
    super.key,
    required this.todos,
    this.isLoading = false,
    this.readOnly = false,
    required this.onToggle,
    required this.onDelete,
    required this.onTap,
    required this.onActionTap,
    required this.onComplete,
    required this.onDefer,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (todos.isEmpty) {
      return const EmptyState(
        icon: Icons.checklist_rtl,
        title: '暂无待办事项',
        subtitle: '点击下方 + 添加',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 104),
      itemCount: todos.length + 1,
      itemBuilder: (context, index) {
        if (index == todos.length) {
          return const SizedBox(height: 4);
        }
        final todo = todos[index];
        return _StaggeredItem(
          index: index,
          child: _SwipeActions(
            key: ValueKey(todo.id),
            enabled: !todo.completed,
            onComplete: () => onComplete(todo),
            onDefer: () => _showDeferSheet(context, todo),
            onDelete: () => _showDeleteActionSheet(context, todo),
            child: TodoItem(
              todo: todo,
              readOnly: readOnly,
              onTap: () => onTap(todo),
              onToggle: () => onToggle(todo),
              onLongPress: () => _showDeleteActionSheet(context, todo),
              onActionTap: () => onActionTap(todo),
            ),
          ),
        );
      },
    );
  }

  void _showDeferSheet(BuildContext context, Todo todo) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    // Find next Monday
    final daysUntilMonday = (DateTime.monday - today.weekday + 7) % 7;
    final nextMonday = daysUntilMonday == 0
        ? today.add(const Duration(days: 7))
        : today.add(Duration(days: daysUntilMonday));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(ctx).height * 0.82,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _deferOption(
                          ctx,
                          parentContext: context,
                          icon: Icons.schedule_rounded,
                          label: '延期 1 小时',
                          dateTime: _todoDateTime(
                            todo,
                          ).add(const Duration(hours: 1)),
                          todo: todo,
                        ),
                        const Divider(height: 0.5),
                        _deferOption(
                          ctx,
                          parentContext: context,
                          icon: Icons.more_time_rounded,
                          label: '延期 5 小时',
                          dateTime: _todoDateTime(
                            todo,
                          ).add(const Duration(hours: 5)),
                          todo: todo,
                        ),
                        const Divider(height: 0.5),
                        _deferOption(
                          ctx,
                          parentContext: context,
                          icon: Icons.wb_sunny,
                          label: '延期至明天',
                          date: tomorrow,
                          todo: todo,
                        ),
                        const Divider(height: 0.5),
                        _deferOption(
                          ctx,
                          parentContext: context,
                          icon: Icons.calendar_today,
                          label: '延期至下周一',
                          date: nextMonday,
                          todo: todo,
                        ),
                        const Divider(height: 0.5),
                        _deferOption(
                          ctx,
                          parentContext: context,
                          icon: Icons.next_week,
                          label: '延期至下周同日',
                          date: today.add(const Duration(days: 7)),
                          todo: todo,
                        ),
                        const Divider(height: 0.5),
                        ListTile(
                          leading: const Icon(
                            Icons.date_range,
                            size: 22,
                            color: AppColors.textSecondary,
                          ),
                          title: const Text(
                            '自定义日期时间',
                            style: TextStyle(
                              fontFamily: 'PingFang SC',
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              color: AppColors.text,
                            ),
                          ),
                          onTap: () async {
                            Navigator.of(ctx).pop();
                            final todoDateTime = _todoDateTime(todo);
                            final picked = await showAppDatePicker(
                              context: context,
                              initialDate: todoDateTime.isBefore(today)
                                  ? today
                                  : DateTime(
                                      todoDateTime.year,
                                      todoDateTime.month,
                                      todoDateTime.day,
                                    ),
                              firstDate: today,
                              lastDate: DateTime(2030),
                            );
                            if (picked == null || !context.mounted) return;
                            final pickedTime = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay(
                                hour: todoDateTime.hour,
                                minute: todoDateTime.minute,
                              ),
                              builder: (context, child) => Theme(
                                data: Theme.of(context).copyWith(
                                  timePickerTheme: TimePickerThemeData(
                                    backgroundColor: AppColors.surface,
                                    hourMinuteColor: AppColors.inputBg,
                                    hourMinuteTextColor: AppColors.text,
                                    dialHandColor: AppColors.primary,
                                    dialBackgroundColor: AppColors.inputBg,
                                    entryModeIconColor: AppColors.primary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                ),
                                child: child!,
                              ),
                            );
                            if (pickedTime == null) return;
                            _applyDeferDateTime(
                              todo,
                              DateTime(
                                picked.year,
                                picked.month,
                                picked.day,
                                pickedTime.hour,
                                pickedTime.minute,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ListTile(
                      title: const Text(
                        '取消',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'PingFang SC',
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      onTap: () => Navigator.of(ctx).pop(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _deferOption(
    BuildContext ctx, {
    required BuildContext parentContext,
    required IconData icon,
    required String label,
    DateTime? date,
    DateTime? dateTime,
    required Todo todo,
  }) {
    return ListTile(
      leading: Icon(icon, size: 22, color: AppColors.warning),
      title: Text(
        label,
        style: const TextStyle(
          fontFamily: 'PingFang SC',
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: AppColors.text,
        ),
      ),
      onTap: () {
        Navigator.of(ctx).pop();
        if (dateTime != null) {
          _applyDeferDateTime(todo, dateTime);
        } else if (date != null) {
          _applyDefer(todo, date, parentContext);
        }
      },
    );
  }

  DateTime _todoDateTime(Todo todo) {
    final parts = todo.time.split(':');
    final hour = int.tryParse(parts.first) ?? 9;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    final scheduled = DateTime(
      todo.date.year,
      todo.date.month,
      todo.date.day,
      hour.clamp(0, 23),
      minute.clamp(0, 59),
    );
    final now = DateTime.now();
    return scheduled.isBefore(now) ? now : scheduled;
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _applyDeferDateTime(Todo todo, DateTime newDateTime) {
    final updated = todo.copyWith(
      date: DateTime(newDateTime.year, newDateTime.month, newDateTime.day),
      time: _formatTime(newDateTime),
    );
    onDefer(updated);
  }

  void _applyDefer(Todo todo, DateTime newDate, BuildContext context) {
    final updated = todo.copyWith(
      date: DateTime(newDate.year, newDate.month, newDate.day),
    );
    onDefer(updated);
  }

  void _showDeleteActionSheet(BuildContext context, Todo todo) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      title: const Text(
                        '删除待办',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.danger,
                          fontFamily: 'PingFang SC',
                          fontSize: 17,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      onTap: () {
                        Navigator.of(context).pop();
                        onDelete(todo);
                      },
                    ),
                    const Divider(height: 0.5, indent: 0, endIndent: 0),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ListTile(
                  title: const Text(
                    '取消',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'PingFang SC',
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

/// 双向滑动操作组件
/// - 右滑 → 完成（绿色圆形对勾）
/// - 左滑一段 → 延期（橙色 "延期"）
/// - 左滑到底 → 删除（红色垃圾桶）
class _SwipeActions extends StatefulWidget {
  final VoidCallback onComplete;
  final VoidCallback onDefer;
  final VoidCallback onDelete;
  final Widget child;
  final bool enabled;

  const _SwipeActions({
    super.key,
    required this.onComplete,
    required this.onDefer,
    required this.onDelete,
    required this.child,
    this.enabled = true,
  });

  @override
  State<_SwipeActions> createState() => _SwipeActionsState();
}

class _SwipeActionsState extends State<_SwipeActions>
    with TickerProviderStateMixin {
  double _offset = 0;
  bool _dragging = false;
  bool _completeArmed = false;
  late AnimationController _controller;
  late AnimationController _completeController;
  late Animation<double> _animation;

  // 左滑阈值
  static const double _deferThreshold = 60.0;
  static const double _deleteThreshold = 140.0;
  static const double _deferSnap = 80.0;
  static const double _deleteSnap = 160.0;

  // 右滑阈值
  static const double _completeThreshold = 50.0;
  static const double _completeSnap = 76.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _animation =
        Tween<double>(begin: 0, end: 0).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeOut),
        )..addListener(() {
          if (!_dragging) {
            setState(() => _offset = _animation.value);
          }
        });
    _completeController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 1500),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed &&
              mounted &&
              _completeArmed) {
            _completeArmed = false;
            widget.onComplete();
          }
        });
  }

  @override
  void dispose() {
    _controller.dispose();
    _completeController.dispose();
    super.dispose();
  }

  void _cancelCompleteCountdown() {
    if (!_completeArmed) return;
    _completeArmed = false;
    _completeController.stop();
    _completeController.reset();
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
    if (!widget.enabled) {
      return widget.child;
    }

    final showComplete = _offset > 10;
    final showDefer = _offset < -10;
    final showDelete =
        _offset < -(widget.enabled ? _deferThreshold : double.infinity);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 右滑背景：完成按钮
        if (showComplete)
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: _completeSnap,
                  height: double.infinity,
                  child: Center(
                    child: GestureDetector(
                      onTap: () {
                        _cancelCompleteCountdown();
                        _animateTo(0);
                        widget.onComplete();
                      },
                      child: AnimatedBuilder(
                        animation: _completeController,
                        builder: (context, _) {
                          final progress = _completeController.value;
                          return Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color.lerp(
                                AppColors.success.withValues(alpha: 0.08),
                                AppColors.success,
                                progress,
                              ),
                              border: Border.all(
                                color: AppColors.success.withValues(
                                  alpha: 0.25 + progress * 0.35,
                                ),
                                width: 1.2,
                              ),
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 38,
                                  height: 38,
                                  child: CircularProgressIndicator(
                                    value: progress,
                                    strokeWidth: 2,
                                    color: AppColors.success,
                                    backgroundColor: Colors.transparent,
                                  ),
                                ),
                                Icon(
                                  Icons.check_rounded,
                                  size: 18,
                                  color: progress > 0.55
                                      ? Colors.white
                                      : AppColors.success,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        // 左滑背景：延期按钮
        if (showDefer)
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () {
                        _animateTo(0);
                        widget.onDefer();
                      },
                      child: Container(
                        width: 80,
                        height: double.infinity,
                        color: Colors.transparent,
                        child: Center(
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.warning.withValues(alpha: 0.1),
                              border: Border.all(
                                color: AppColors.warning.withValues(alpha: 0.3),
                                width: 1.2,
                              ),
                            ),
                            child: const Icon(
                              Icons.more_time_rounded,
                              size: 18,
                              color: AppColors.warning,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // 删除按钮
                    if (showDelete)
                      GestureDetector(
                        onTap: () {
                          _animateTo(0);
                          widget.onDelete();
                        },
                        child: Container(
                          width: 80,
                          height: double.infinity,
                          color: Colors.transparent,
                          child: Center(
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.danger.withValues(alpha: 0.08),
                                border: Border.all(
                                  color: AppColors.danger.withValues(
                                    alpha: 0.25,
                                  ),
                                  width: 1.2,
                                ),
                              ),
                              child: Center(
                                child: SvgPicture.asset(
                                  'assets/icons/delete.svg',
                                  width: 17,
                                  height: 17,
                                  colorFilter: const ColorFilter.mode(
                                    AppColors.danger,
                                    BlendMode.srcIn,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

        // 前景内容 + 手势
        GestureDetector(
          onHorizontalDragStart: (_) {
            _cancelCompleteCountdown();
            if (widget.enabled) _dragging = true;
          },
          onHorizontalDragUpdate: (details) {
            if (!widget.enabled) return;
            setState(() {
              _offset += details.delta.dx;
              // 右滑上限
              if (_offset > _completeSnap) _offset = _completeSnap;
              // 左滑上限
              if (_offset < -_deleteSnap) _offset = -_deleteSnap;
            });
          },
          onHorizontalDragEnd: (details) {
            if (!widget.enabled) return;
            _dragging = false;
            if (_offset > _completeThreshold) {
              // 右滑 → 吸附到完成位置
              _animateTo(_completeSnap);
              _completeArmed = true;
              _completeController.forward(from: 0);
            } else if (_offset < -_deleteThreshold) {
              // 左滑到底 → 吸附到删除位置
              _animateTo(-_deleteSnap);
            } else if (_offset < -_deferThreshold) {
              // 左滑一段 → 吸附到延期位置
              _animateTo(-_deferSnap);
            } else {
              // 未达阈值 → 回弹
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

class _StaggeredItem extends StatefulWidget {
  final int index;
  final Widget child;

  const _StaggeredItem({required this.index, required this.child});

  @override
  State<_StaggeredItem> createState() => _StaggeredItemState();
}

class _StaggeredItemState extends State<_StaggeredItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    Future.delayed(Duration(milliseconds: widget.index * 60), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(position: _slideAnimation, child: widget.child),
    );
  }
}
