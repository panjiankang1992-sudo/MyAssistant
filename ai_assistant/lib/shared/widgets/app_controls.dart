import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/platform/app_performance.dart';
import '../../core/theme/app_theme.dart';

const double appControlHeight = 54;

InputDecoration appInputDecoration({
  required String label,
  String? hintText,
  Widget? suffixIcon,
  BuildContext? context,
  bool alignLabelWithHint = false,
}) {
  final scheme = context == null ? null : Theme.of(context).colorScheme;
  final accent = scheme?.primary ?? AppColors.primary;
  final labelColor = scheme?.onSurfaceVariant ?? AppColors.textSecondary;
  final hintColor =
      scheme?.onSurfaceVariant.withValues(alpha: 0.62) ??
      AppColors.textTertiary;
  final fillColor = scheme == null
      ? AppColors.inputBg
      : Color.alphaBlend(
          scheme.primary.withValues(alpha: 0.025),
          scheme.surface,
        );
  final borderColor =
      scheme?.outline.withValues(alpha: 0.58) ??
      AppColors.border.withValues(alpha: 0.8);
  return InputDecoration(
    labelText: label.isEmpty ? null : label,
    hintText: hintText,
    alignLabelWithHint: alignLabelWithHint,
    filled: true,
    fillColor: fillColor,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    suffixIcon: suffixIcon,
    suffixIconColor: labelColor,
    hintStyle: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w500,
      color: hintColor,
    ),
    labelStyle: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: labelColor,
    ),
    floatingLabelStyle: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w800,
      color: accent,
    ),
    counterStyle: TextStyle(color: labelColor),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: borderColor),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: borderColor),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: accent, width: 1.4),
    ),
  );
}

ButtonStyle appControlButtonStyle({
  Color background = AppColors.primary,
  Color foreground = Colors.white,
}) {
  return ElevatedButton.styleFrom(
    minimumSize: const Size(0, appControlHeight),
    fixedSize: const Size.fromHeight(appControlHeight),
    elevation: 0,
    backgroundColor: background,
    foregroundColor: foreground,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
  ).copyWith(
    animationDuration: AppPerformance.lowLatencyMode
        ? Duration.zero
        : AppAnimations.shortDuration,
  );
}

class AppDropdownOption<T> {
  final T value;
  final String label;

  const AppDropdownOption({required this.value, required this.label});
}

class AppDropdownField<T> extends StatefulWidget {
  final String label;
  final T value;
  final List<AppDropdownOption<T>> options;
  final ValueChanged<T> onChanged;

  const AppDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  State<AppDropdownField<T>> createState() => _AppDropdownFieldState<T>();
}

class _AppDropdownFieldState<T> extends State<AppDropdownField<T>> {
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _fieldKey = GlobalKey();
  OverlayEntry? _entry;

  @override
  void dispose() {
    _hideMenu();
    super.dispose();
  }

  void _hideMenu() {
    _entry?.remove();
    _entry = null;
  }

  void _toggleMenu() {
    if (_entry == null) {
      _showMenu();
    } else {
      _hideMenu();
    }
  }

  void _showMenu() {
    if (widget.options.isEmpty) return;
    final box = _fieldKey.currentContext?.findRenderObject() as RenderBox?;
    final width = box?.size.width ?? 220;
    _entry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _hideMenu,
            ),
          ),
          CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            targetAnchor: Alignment.bottomLeft,
            followerAnchor: Alignment.topLeft,
            offset: const Offset(0, 8),
            child: Material(
              color: Colors.transparent,
              child: _DropdownOverlay<T>(
                width: width,
                value: widget.value,
                options: widget.options,
                onSelected: (value) {
                  _hideMenu();
                  widget.onChanged(value);
                },
              ),
            ),
          ),
        ],
      ),
    );
    Overlay.of(context).insert(_entry!);
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.options.firstWhere(
      (option) => option.value == widget.value,
      orElse: () => widget.options.first,
    );
    final textColor = Theme.of(context).colorScheme.onSurface;
    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        key: _fieldKey,
        onTap: _toggleMenu,
        behavior: HitTestBehavior.opaque,
        child: InputDecorator(
          decoration: appInputDecoration(
            context: context,
            label: widget.label,
            suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded),
          ),
          child: SizedBox(
            height: 22,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                selected.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ).copyWith(color: textColor),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DropdownOverlay<T> extends StatelessWidget {
  final double width;
  final T value;
  final List<AppDropdownOption<T>> options;
  final ValueChanged<T> onSelected;

  const _DropdownOverlay({
    required this.width,
    required this.value,
    required this.options,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = scheme.primary;
    return Container(
      width: width,
      constraints: const BoxConstraints(maxHeight: 320),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.46)),
        boxShadow: AppPerformance.lowLatencyMode
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
      ),
      child: ListView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: options.length,
        itemBuilder: (context, index) {
          final option = options[index];
          final selected = option.value == value;
          return GestureDetector(
            onTap: () => onSelected(option.value),
            behavior: HitTestBehavior.opaque,
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: (selected ? accent : AppColors.text).withValues(
                        alpha: selected ? 0.12 : 0.06,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      selected
                          ? Icons.check_rounded
                          : Icons.keyboard_arrow_right_rounded,
                      size: 16,
                      color: selected
                          ? accent
                          : scheme.onSurfaceVariant.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      option.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: selected
                            ? FontWeight.w900
                            : FontWeight.w800,
                        color: selected ? accent : scheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class AppDateMarker {
  final String label;
  final Color color;

  const AppDateMarker({required this.label, required this.color});
}

typedef AppDateMarkerBuilder = AppDateMarker? Function(DateTime date);

class AppAddFab extends StatelessWidget {
  final VoidCallback onPressed;
  final String tooltip;
  final List<Color> gradientColors;

  const AppAddFab({
    super.key,
    required this.onPressed,
    this.tooltip = '新增',
    this.gradientColors = const [Color(0xFF8B5CF6), Color(0xFF0A84FF)],
  });

  @override
  Widget build(BuildContext context) {
    final reduceMotion = AppPerformance.shouldReduceMotion(context);
    return Transform.translate(
      offset: const Offset(0, -12),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: Ink(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: reduceMotion
                    ? null
                    : [
                        BoxShadow(
                          color: gradientColors.last.withValues(alpha: 0.26),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                        BoxShadow(
                          color: gradientColors.first.withValues(alpha: 0.16),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
              ),
              child: const Icon(
                Icons.add_rounded,
                size: 29,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum AppActionButtonTone { primary, danger, neutral }

class AppRoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? foregroundColor;

  const AppRoundIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 28),
      style: IconButton.styleFrom(
        fixedSize: const Size(58, 58),
        minimumSize: const Size(58, 58),
        maximumSize: const Size(58, 58),
        backgroundColor: scheme.appInput.withValues(alpha: 0.95),
        foregroundColor: foregroundColor ?? scheme.appText,
        disabledForegroundColor: scheme.appDisabledText,
        shape: const CircleBorder(),
        elevation: 0,
      ),
    );
  }
}

class AppBottomAction {
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;
  final AppActionButtonTone tone;

  const AppBottomAction({
    required this.label,
    required this.onPressed,
    this.icon,
    this.tone = AppActionButtonTone.primary,
  });
}

class AppFloatingActionBar extends StatelessWidget {
  final List<AppBottomAction> actions;
  final EdgeInsets padding;

  const AppFloatingActionBar({
    super.key,
    required this.actions,
    this.padding = const EdgeInsets.fromLTRB(22, 8, 22, 14),
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: padding,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: scheme.appElevatedSurface.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: scheme.appBorder.withValues(alpha: 0.72)),
          boxShadow: AppPerformance.lowLatencyMode
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (event) {
                if (actions.isEmpty) return;
                final gapTotal = 10.0 * (actions.length - 1);
                final itemWidth =
                    (constraints.maxWidth - gapTotal) / actions.length;
                for (var i = 0; i < actions.length; i++) {
                  final start = i * (itemWidth + 10);
                  final end = start + itemWidth;
                  if (event.localPosition.dx >= start &&
                      event.localPosition.dx <= end) {
                    actions[i].onPressed();
                    return;
                  }
                }
              },
              child: IgnorePointer(
                child: Row(
                  children: [
                    for (var i = 0; i < actions.length; i++) ...[
                      if (i > 0) const SizedBox(width: 10),
                      Expanded(child: AppPillActionButton(action: actions[i])),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class AppVoiceInputFab extends StatefulWidget {
  final bool listening;
  final String transcript;
  final VoidCallback onPressed;
  final VoidCallback onLongPressStart;
  final VoidCallback onLongPressEnd;
  final List<Color> gradientColors;

  const AppVoiceInputFab({
    super.key,
    required this.listening,
    required this.transcript,
    required this.onPressed,
    required this.onLongPressStart,
    required this.onLongPressEnd,
    this.gradientColors = const [Color(0xFF8B5CF6), Color(0xFF0A84FF)],
  });

  @override
  State<AppVoiceInputFab> createState() => _AppVoiceInputFabState();
}

class _AppVoiceInputFabState extends State<AppVoiceInputFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  var _armed = false;

  bool get _hasVoiceText => widget.transcript.trim().isNotEmpty;
  bool get _active => widget.listening || _armed;
  bool get _shouldPulse => _active && _hasVoiceText;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 920),
    );
  }

  @override
  void didUpdateWidget(covariant AppVoiceInputFab oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPulse();
  }

  void _syncPulse() {
    if (AppPerformance.lowLatencyMode) {
      _pulseController.stop();
      return;
    }
    if (_shouldPulse) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      _pulseController.stop();
      _pulseController.animateTo(
        0,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.transcript.trim();
    final scheme = Theme.of(context).colorScheme;
    final reduceMotion = AppPerformance.shouldReduceMotion(context);
    return Transform.translate(
      offset: const Offset(0, -12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: widget.onPressed,
            onLongPressStart: (_) {
              setState(() => _armed = true);
              _syncPulse();
              widget.onLongPressStart();
            },
            onLongPressEnd: (_) {
              if (mounted) setState(() => _armed = false);
              _syncPulse();
              widget.onLongPressEnd();
            },
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final pulse = _pulseController.value;
                final scale = reduceMotion
                    ? 1.0
                    : (_armed ? 1.06 : 1.0) + pulse * 0.08;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedOpacity(
                      opacity: reduceMotion ? 0 : (_shouldPulse ? 1 : 0),
                      duration: reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 160),
                      child: Transform.scale(
                        scale: 1.05 + pulse * 0.38,
                        child: Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: widget.gradientColors.last.withValues(
                              alpha: 0.12 * (1 - pulse * 0.45),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Transform.scale(scale: scale, child: child),
                  ],
                );
              },
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: widget.gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: reduceMotion
                      ? null
                      : [
                          BoxShadow(
                            color: widget.gradientColors.last.withValues(
                              alpha: 0.26,
                            ),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                          BoxShadow(
                            color: widget.gradientColors.first.withValues(
                              alpha: 0.16,
                            ),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                ),
                child: Icon(
                  widget.listening || _armed
                      ? Icons.mic_rounded
                      : Icons.add_rounded,
                  size: 29,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: _active
                ? Padding(
                    key: ValueKey(text.isEmpty ? 'empty' : text),
                    padding: const EdgeInsets.only(top: 10),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 280),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: scheme.appElevatedSurface.withValues(
                            alpha: 0.94,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: scheme.appBorder.withValues(alpha: 0.78),
                          ),
                          boxShadow: reduceMotion
                              ? null
                              : [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 18,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          child: Text(
                            text.isEmpty ? '正在听...' : text,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.28,
                              color: text.isEmpty
                                  ? scheme.appSubtleText
                                  : scheme.appText,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('hidden')),
          ),
        ],
      ),
    );
  }
}

class AppPillActionButton extends StatelessWidget {
  final AppBottomAction action;
  final double height;

  const AppPillActionButton({
    super.key,
    required this.action,
    this.height = 48,
  });

  Color _background(ColorScheme scheme) {
    switch (action.tone) {
      case AppActionButtonTone.primary:
        return scheme.primary;
      case AppActionButtonTone.danger:
        return const Color(0xFFE62D27);
      case AppActionButtonTone.neutral:
        return scheme.appInput;
    }
  }

  Color _foreground(ColorScheme scheme) {
    switch (action.tone) {
      case AppActionButtonTone.primary:
      case AppActionButtonTone.danger:
        return scheme.onPrimary;
      case AppActionButtonTone.neutral:
        return scheme.appText;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = _background(scheme);
    final foreground = _foreground(scheme);
    final side = action.tone == AppActionButtonTone.neutral
        ? BorderSide(color: scheme.appBorder.withValues(alpha: 0.8))
        : BorderSide.none;
    return SizedBox(
      height: height,
      child: Semantics(
        button: true,
        label: action.label,
        onTap: action.onPressed,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: action.onPressed,
          child: Container(
            height: height,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(24),
              border: side == BorderSide.none
                  ? null
                  : Border.fromBorderSide(side),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (action.icon != null) ...[
                  Icon(action.icon, size: 19, color: foreground),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    action.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: foreground,
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

Future<DateTime?> showAppDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  AppDateMarkerBuilder? markerBuilder,
}) {
  return showDialog<DateTime>(
    context: context,
    builder: (context) => _AppDatePickerDialog(
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      markerBuilder: markerBuilder,
    ),
  );
}

class _AppDatePickerDialog extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final AppDateMarkerBuilder? markerBuilder;

  const _AppDatePickerDialog({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    this.markerBuilder,
  });

  @override
  State<_AppDatePickerDialog> createState() => _AppDatePickerDialogState();
}

class _AppDatePickerDialogState extends State<_AppDatePickerDialog> {
  late DateTime _selected;
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialDate;
    _visibleMonth = DateTime(_selected.year, _selected.month);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Dialog(
      backgroundColor: scheme.appSurface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.calendar_month_rounded,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${DateFormat('yyyy年M月d日').format(_selected)} ${_weekdayLabel(_selected)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: scheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: scheme.primary.withValues(alpha: 0.16),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          DateFormat('yyyy年M月').format(_visibleMonth),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: scheme.primary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.arrow_drop_down_rounded,
                          color: scheme.primary,
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  _MonthNavButton(
                    icon: Icons.chevron_left_rounded,
                    onTap: () => setState(() {
                      _visibleMonth = DateTime(
                        _visibleMonth.year,
                        _visibleMonth.month - 1,
                      );
                    }),
                  ),
                  const SizedBox(width: 10),
                  _MonthNavButton(
                    icon: Icons.chevron_right_rounded,
                    onTap: () => setState(() {
                      _visibleMonth = DateTime(
                        _visibleMonth.year,
                        _visibleMonth.month + 1,
                      );
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _CalendarGrid(
                visibleMonth: _visibleMonth,
                selected: _selected,
                firstDate: widget.firstDate,
                lastDate: widget.lastDate,
                markerBuilder: widget.markerBuilder,
                onSelected: (date) => setState(() {
                  _selected = date;
                  _visibleMonth = DateTime(date.year, date.month);
                }),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(_selected),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(82, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('确定'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthNavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MonthNavButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: scheme.appInput,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.appBorder),
        ),
        child: Icon(icon, size: 30, color: scheme.appMutedText),
      ),
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  final DateTime visibleMonth;
  final DateTime selected;
  final DateTime firstDate;
  final DateTime lastDate;
  final AppDateMarkerBuilder? markerBuilder;
  final ValueChanged<DateTime> onSelected;

  const _CalendarGrid({
    required this.visibleMonth,
    required this.selected,
    required this.firstDate,
    required this.lastDate,
    required this.markerBuilder,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final firstOfMonth = DateTime(visibleMonth.year, visibleMonth.month);
    final leading = firstOfMonth.weekday % 7;
    final firstCell = firstOfMonth.subtract(Duration(days: leading));
    return Column(
      children: [
        const Row(
          children: [
            _WeekdayCell('日'),
            _WeekdayCell('一'),
            _WeekdayCell('二'),
            _WeekdayCell('三'),
            _WeekdayCell('四'),
            _WeekdayCell('五'),
            _WeekdayCell('六'),
          ],
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: 42,
          itemBuilder: (context, index) {
            final date = firstCell.add(Duration(days: index));
            final inMonth = date.month == visibleMonth.month;
            final isSelected = _sameDate(date, selected);
            final disabled =
                date.isBefore(_dateOnly(firstDate)) ||
                date.isAfter(_dateOnly(lastDate));
            final marker = disabled ? null : markerBuilder?.call(date);
            return InkWell(
              onTap: disabled ? null : () => onSelected(date),
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Center(
                    child: AnimatedContainer(
                      duration: AppAnimations.shortDuration,
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: isSelected ? scheme.primary : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${date.day}',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: isSelected
                              ? FontWeight.w900
                              : FontWeight.w700,
                          color: disabled
                              ? scheme.appDisabledText
                              : isSelected
                              ? scheme.onPrimary
                              : inMonth
                              ? scheme.appText
                              : scheme.appDisabledText,
                        ),
                      ),
                    ),
                  ),
                  if (marker != null && marker.label.isNotEmpty)
                    Positioned(
                      right: 2,
                      bottom: 1,
                      child: Text(
                        marker.label,
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                        softWrap: false,
                        style: TextStyle(
                          fontSize: 9,
                          height: 1,
                          fontWeight: FontWeight.w900,
                          color: inMonth
                              ? marker.color
                              : marker.color.withValues(alpha: 0.42),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _WeekdayCell extends StatelessWidget {
  final String label;

  const _WeekdayCell(this.label);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: scheme.appMutedText,
          ),
        ),
      ),
    );
  }
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

bool _sameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _weekdayLabel(DateTime date) {
  const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  return weekdays[date.weekday - 1];
}
