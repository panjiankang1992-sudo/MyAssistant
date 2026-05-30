import 'package:flutter/material.dart';
import '../../../domain/models/tag.dart';
import '../../../domain/models/todo.dart';
import '../../../core/platform/app_performance.dart';
import '../../../core/theme/app_theme.dart';
import 'form_controls.dart';

class TodoItem extends StatefulWidget {
  final Todo todo;
  final bool readOnly;
  final VoidCallback? onTap;
  final VoidCallback? onToggle;
  final VoidCallback? onLongPress;
  final VoidCallback? onActionTap;

  const TodoItem({
    super.key,
    required this.todo,
    this.readOnly = false,
    this.onTap,
    this.onToggle,
    this.onLongPress,
    this.onActionTap,
  });

  @override
  State<TodoItem> createState() => _TodoItemState();
}

class _TodoItemState extends State<TodoItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _checkController;
  late Animation<double> _checkScale;
  late Animation<double> _checkColor;
  bool _itemPressed = false;

  @override
  void initState() {
    super.initState();
    _checkController = AnimationController(
      vsync: this,
      duration: AppPerformance.lowLatencyMode
          ? Duration.zero
          : const Duration(milliseconds: 300),
    );
    _checkScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _checkController,
        curve: AppPerformance.lowLatencyMode
            ? Curves.linear
            : Curves.elasticOut,
      ),
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

  (Color, Color, IconData) _getActionStyle() {
    final action = TodoActions.byValue(widget.todo.action);
    if (widget.todo.action != 'none') {
      return (action.color.withValues(alpha: 0.1), action.color, action.icon);
    }
    if (widget.todo.tags.isEmpty) {
      return (
        AppColors.personalBg,
        AppColors.purple,
        Icons.arrow_forward_rounded,
      );
    }
    final colorKey = widget.todo.tags.first.colorKey;
    return (
      TagPalette.bgColor(colorKey),
      TagPalette.textColor(colorKey),
      Icons.arrow_forward_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    final actionStyle = _getActionStyle();
    final scheme = Theme.of(context).colorScheme;
    final reduceMotion = AppPerformance.shouldReduceMotion(context);
    final cardColor = !reduceMotion && _itemPressed
        ? scheme.appPressed
        : scheme.appSurface;
    final mutedText = scheme.appMutedText;
    final actionColor = actionStyle.$2;
    final actionBg = Color.alphaBlend(
      actionColor.withValues(alpha: scheme.isDarkTheme ? 0.18 : 0.10),
      scheme.appSurface,
    );

    final content = Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: scheme.isDarkTheme || reduceMotion
            ? null
            : AppAnimations.cardShadow(),
        border: widget.todo.priority > 0
            ? Border(
                left: BorderSide(
                  color: widget.todo.priority >= 2
                      ? AppColors.danger
                      : AppColors.warning,
                  width: 3,
                ),
              )
            : Border.all(color: scheme.appBorder.withValues(alpha: 0.8)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: widget.readOnly ? null : widget.onToggle,
            behavior: HitTestBehavior.opaque,
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
                      ? reduceMotion
                            ? const Icon(
                                Icons.check,
                                size: 12,
                                color: Colors.white,
                              )
                            : ScaleTransition(
                                scale: _checkScale,
                                child: const Icon(
                                  Icons.check,
                                  size: 12,
                                  color: Colors.white,
                                ),
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
                    fontFamilyFallback: const [
                      '.SF Pro Text',
                      'system-ui',
                      'sans-serif',
                    ],
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: widget.todo.completed
                        ? scheme.appDisabledText
                        : scheme.appText,
                    decoration: widget.todo.completed
                        ? TextDecoration.lineThrough
                        : null,
                    fontStyle: widget.todo.completed
                        ? FontStyle.italic
                        : FontStyle.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (widget.todo.description != null &&
                    widget.todo.description!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      widget.todo.description!,
                      style: const TextStyle(
                        fontFamily: 'PingFang SC',
                        fontFamilyFallback: [
                          '.SF Pro Text',
                          'system-ui',
                          'sans-serif',
                        ],
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ).copyWith(color: mutedText),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      widget.todo.time,
                      style: const TextStyle(
                        fontFamily: 'SF Mono',
                        fontFamilyFallback: ['Menlo', 'Monaco', 'monospace'],
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ).copyWith(color: mutedText),
                    ),
                    const SizedBox(width: 8),
                    if (_shouldShowSourceChip(widget.todo.source))
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: _TodoMiniSourceChip(source: widget.todo.source),
                      ),
                    ...widget.todo.tags
                        .take(3)
                        .map(
                          (tag) => Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: _TodoMiniTag(tag: tag),
                          ),
                        ),
                    if (widget.todo.tags.length > 3)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Text(
                          '…',
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.appSubtleText,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _SourceIcon(
            source: widget.todo.source,
            onTap: widget.todo.source == 'calendar' ? widget.onActionTap : null,
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label: widget.todo.action == 'bookkeeping' ? '执行记账' : '执行动作',
            child: _TodoActionButton(
              onTap: widget.readOnly ? null : widget.onActionTap,
              backgroundColor: actionBg,
              foregroundColor: actionColor,
              icon: actionStyle.$3,
              reduceMotion: reduceMotion,
              darkMode: scheme.isDarkTheme,
            ),
          ),
        ],
      ),
    );

    final item = reduceMotion
        ? Opacity(opacity: widget.todo.completed ? 0.55 : 1.0, child: content)
        : AnimatedScale(
            scale: _itemPressed ? 0.985 : 1.0,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
            child: AnimatedOpacity(
              opacity: widget.todo.completed ? 0.55 : 1.0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              child: content,
            ),
          );

    return GestureDetector(
      onTapDown: widget.readOnly || reduceMotion
          ? null
          : (_) => setState(() => _itemPressed = true),
      onTapUp: widget.readOnly || reduceMotion
          ? null
          : (_) => setState(() => _itemPressed = false),
      onTapCancel: widget.readOnly || reduceMotion
          ? null
          : () => setState(() => _itemPressed = false),
      onTap: widget.onTap,
      onLongPress: widget.readOnly ? null : widget.onLongPress,
      child: item,
    );
  }
}

class _TodoActionButton extends StatelessWidget {
  final VoidCallback? onTap;
  final Color backgroundColor;
  final Color foregroundColor;
  final IconData icon;
  final bool reduceMotion;
  final bool darkMode;

  const _TodoActionButton({
    required this.onTap,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.icon,
    required this.reduceMotion,
    required this.darkMode,
  });

  @override
  Widget build(BuildContext context) {
    final button = SizedBox(
      width: 50,
      height: 50,
      child: Center(
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: foregroundColor.withValues(alpha: darkMode ? 0.36 : 0.18),
            ),
          ),
          child: Center(child: Icon(icon, size: 19, color: foregroundColor)),
        ),
      ),
    );
    if (reduceMotion) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: button,
      );
    }
    return Material(
      color: Colors.transparent,
      child: InkResponse(
        onTap: onTap,
        radius: 28,
        containedInkWell: false,
        child: button,
      ),
    );
  }
}

bool _shouldShowSourceChip(String source) {
  return source == 'routine' || source == 'calendar' || source == 'sms';
}

class _TodoMiniTag extends StatelessWidget {
  final Tag tag;

  const _TodoMiniTag({required this.tag});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = TagPalette.textColor(tag.colorKey);
    final bg = TagPalette.bgColor(tag.colorKey);
    final fill = scheme.isDarkTheme
        ? Color.alphaBlend(fg.withValues(alpha: 0.16), scheme.appSurface)
        : bg.withValues(alpha: 0.55);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        tag.name,
        style: TextStyle(
          fontSize: 11,
          height: 1.1,
          fontWeight: FontWeight.w600,
          color: fg.withValues(alpha: 0.88),
        ),
      ),
    );
  }
}

class _TodoMiniSourceChip extends StatelessWidget {
  final String source;

  const _TodoMiniSourceChip({required this.source});

  @override
  Widget build(BuildContext context) {
    final item = TodoSources.byValue(source);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: item.color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(item.icon, size: 11, color: item.color),
          const SizedBox(width: 3),
          Text(
            item.label,
            style: TextStyle(
              fontSize: 11,
              height: 1.1,
              fontWeight: FontWeight.w600,
              color: item.color.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceIcon extends StatelessWidget {
  final String source;
  final VoidCallback? onTap;

  const _SourceIcon({required this.source, this.onTap});

  @override
  Widget build(BuildContext context) {
    final item = TodoSources.byValue(source);
    final reduceMotion = AppPerformance.shouldReduceMotion(context);
    final icon = Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: item.color.withValues(alpha: 0.08),
        shape: BoxShape.circle,
        border: Border.all(color: item.color.withValues(alpha: 0.18)),
      ),
      child: Icon(item.icon, size: 17, color: item.color),
    );
    return Tooltip(
      message: item.label,
      child: reduceMotion
          ? GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: icon,
            )
          : Material(
              color: Colors.transparent,
              child: InkResponse(onTap: onTap, radius: 22, child: icon),
            ),
    );
  }
}
