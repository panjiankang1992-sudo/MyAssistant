import 'package:flutter/material.dart';
import '../../../domain/models/todo.dart';
import '../../../shared/widgets/tag_chip.dart';
import '../../../core/theme/app_theme.dart';

void showTodoDetail(BuildContext context, Todo todo) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return _DraggableSheet(todo: todo);
    },
  );
}

class _DraggableSheet extends StatefulWidget {
  final Todo todo;

  const _DraggableSheet({required this.todo});

  @override
  State<_DraggableSheet> createState() => _DraggableSheetState();
}

class _DraggableSheetState extends State<_DraggableSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _springController;
  late Animation<double> _springAnimation;

  @override
  void initState() {
    super.initState();
    _springController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _springAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(
        parent: _springController,
        curve: Curves.elasticOut,
      ),
    );
    _springController.forward();
  }

  @override
  void dispose() {
    _springController.dispose();
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

  String _getTypeLabel(String type) {
    switch (type) {
      case 'bill': return '帐单';
      case 'work': return '工作';
      case 'personal': return '个人';
      case 'health': return '健康';
      default: return type;
    }
  }

  String _getActionTitle(String type) {
    switch (type) {
      case 'bill': return '一键记账';
      case 'work': return '开始';
      default: return '操作';
    }
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppColors.handleBar,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
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
                  const Text(
                    '来源 & 类型',
                    style: TextStyle(
                      fontFamily: 'PingFang SC',
                      fontFamilyFallback: ['.SF Pro Text', 'system-ui', 'sans-serif'],
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textTertiary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      TagChip(label: _getSourceLabel(widget.todo.source), type: 'source', value: widget.todo.source),
                      const SizedBox(width: 8),
                      TagChip(label: _getTypeLabel(widget.todo.type), type: 'type', value: widget.todo.type),
                    ],
                  ),
                  if (widget.todo.description != null && widget.todo.description!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      '详情',
                      style: TextStyle(
                        fontFamily: 'PingFang SC',
                        fontFamilyFallback: ['.SF Pro Text', 'system-ui', 'sans-serif'],
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textTertiary,
                        letterSpacing: 0.5,
                      ),
                    ),
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
                  const Text(
                    '时间',
                    style: TextStyle(
                      fontFamily: 'PingFang SC',
                      fontFamilyFallback: ['.SF Pro Text', 'system-ui', 'sans-serif'],
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textTertiary,
                      letterSpacing: 0.5,
                    ),
                  ),
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
                  Container(
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
                                '关闭',
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
                              onPressed: () => Navigator.of(context).pop(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                              ),
                              child: Text(
                                _getActionTitle(widget.todo.type),
                                style: const TextStyle(
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
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}