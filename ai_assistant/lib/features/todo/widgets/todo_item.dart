import 'package:flutter/material.dart';
import '../../../domain/models/tag.dart';
import '../../../domain/models/todo.dart';
import '../../../shared/widgets/tag_chip.dart';
import '../../../core/theme/app_theme.dart';

class TodoItem extends StatefulWidget {
  final Todo todo;
  final bool readOnly;
  final VoidCallback? onTap;
  final VoidCallback? onToggle;
  final VoidCallback? onLongPress;

  const TodoItem({
    super.key,
    required this.todo,
    this.readOnly = false,
    this.onTap,
    this.onToggle,
    this.onLongPress,
  });

  @override
  State<TodoItem> createState() => _TodoItemState();
}

class _TodoItemState extends State<TodoItem> with SingleTickerProviderStateMixin {
  late AnimationController _checkController;
  late Animation<double> _checkScale;
  late Animation<double> _checkColor;
  bool _itemPressed = false;

  @override
  void initState() {
    super.initState();
    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _checkScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _checkController, curve: Curves.elasticOut),
    );
    _checkColor = Tween<double>(begin: 0, end: 1).animate(_checkController);
    if (widget.todo.completed) {
      _checkController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant TodoItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.todo.completed != oldWidget.todo.completed) {
      if (widget.todo.completed) {
        _checkController.forward();
      } else {
        _checkController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _checkController.dispose();
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

  (Color, Color, String) _getActionStyle() {
    if (widget.todo.tags.isEmpty) return (AppColors.personalBg, AppColors.purple, '→');
    final colorKey = widget.todo.tags.first.colorKey;
    return (TagPalette.bgColor(colorKey), TagPalette.textColor(colorKey), '→');
  }

  @override
  Widget build(BuildContext context) {
    final actionStyle = _getActionStyle();

    return GestureDetector(
      onTapDown: widget.readOnly ? null : (_) => setState(() => _itemPressed = true),
      onTapUp: widget.readOnly ? null : (_) => setState(() => _itemPressed = false),
      onTapCancel: widget.readOnly ? null : () => setState(() => _itemPressed = false),
      onTap: widget.onTap,
      onLongPress: widget.readOnly ? null : widget.onLongPress,
      child: AnimatedScale(
        scale: _itemPressed ? 0.985 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: widget.todo.completed ? 0.55 : 1.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _itemPressed ? const Color(0xFFF9F9FB) : AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              boxShadow: AppAnimations.cardShadow(),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: widget.readOnly ? null : widget.onToggle,
                  child: AnimatedBuilder(
                    animation: _checkController,
                    builder: (context, _) {
                      return Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color.lerp(
                            Colors.transparent,
                            AppColors.success,
                            _checkColor.value,
                          ),
                          border: Border.all(
                            color: Color.lerp(
                              AppColors.checkboxBorder,
                              AppColors.success,
                              _checkColor.value,
                            )!,
                            width: 2,
                          ),
                        ),
                        child: _checkController.value > 0.3
                            ? ScaleTransition(
                                scale: _checkScale,
                                child: const Icon(Icons.check, size: 12, color: Colors.white),
                              )
                            : null,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.todo.title,
                        style: TextStyle(
                          fontFamily: 'PingFang SC',
                          fontFamilyFallback: const ['.SF Pro Text', 'system-ui', 'sans-serif'],
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: widget.todo.completed ? AppColors.textTertiary : AppColors.text,
                          decoration: widget.todo.completed ? TextDecoration.lineThrough : null,
                          fontStyle: widget.todo.completed ? FontStyle.italic : FontStyle.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (widget.todo.description != null && widget.todo.description!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            widget.todo.description!,
                            style: const TextStyle(
                              fontFamily: 'PingFang SC',
                              fontFamilyFallback: ['.SF Pro Text', 'system-ui', 'sans-serif'],
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: AppColors.textTertiary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          TagChip(label: _getSourceLabel(widget.todo.source), type: 'source', value: widget.todo.source),
                          const SizedBox(width: 6),
                          ...widget.todo.tags.take(3).map((tag) => Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: TagChip.fromTag(label: tag.name, colorKey: tag.colorKey),
                          )),
                          if (widget.todo.tags.length > 3)
                            const Padding(
                              padding: EdgeInsets.only(right: 4),
                              child: Text('…', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                            ),
                          Text(
                            widget.todo.time,
                            style: const TextStyle(
                              fontFamily: 'SF Mono',
                              fontFamilyFallback: ['Menlo', 'Monaco', 'monospace'],
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: actionStyle.$1,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      actionStyle.$3,
                      style: TextStyle(
                        fontSize: actionStyle.$3 == '▶' ? 12 : 14,
                        color: actionStyle.$2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}