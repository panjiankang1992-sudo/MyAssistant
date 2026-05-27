import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';

const double appControlHeight = 54;

InputDecoration appInputDecoration({
  required String label,
  String? hintText,
  Widget? suffixIcon,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hintText,
    filled: true,
    fillColor: AppColors.inputBg,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    suffixIcon: suffixIcon,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.8)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.8)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
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
    return CompositedTransformTarget(
      link: _layerLink,
      child: InkWell(
        key: _fieldKey,
        onTap: _toggleMenu,
        borderRadius: BorderRadius.circular(18),
        child: InputDecorator(
          decoration: appInputDecoration(
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
                  color: AppColors.text,
                ),
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
    return Container(
      width: width,
      constraints: const BoxConstraints(maxHeight: 320),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.76)),
        boxShadow: [
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
          return InkWell(
            onTap: () => onSelected(option.value),
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: (selected ? AppColors.primary : AppColors.text)
                          .withValues(alpha: selected ? 0.12 : 0.06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      selected
                          ? Icons.check_rounded
                          : Icons.keyboard_arrow_right_rounded,
                      size: 16,
                      color: selected
                          ? AppColors.primary
                          : AppColors.textTertiary,
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
                        color: selected ? AppColors.primary : AppColors.text,
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
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 28),
      style: IconButton.styleFrom(
        fixedSize: const Size(58, 58),
        minimumSize: const Size(58, 58),
        maximumSize: const Size(58, 58),
        backgroundColor: AppColors.inputBg.withValues(alpha: 0.95),
        foregroundColor: foregroundColor ?? AppColors.text,
        disabledForegroundColor: AppColors.textTertiary.withValues(alpha: 0.45),
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
    return Padding(
      padding: padding,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
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

  Color get _background {
    switch (action.tone) {
      case AppActionButtonTone.primary:
        return const Color(0xFF5B5CF6);
      case AppActionButtonTone.danger:
        return const Color(0xFFE62D27);
      case AppActionButtonTone.neutral:
        return AppColors.inputBg;
    }
  }

  Color get _foreground {
    switch (action.tone) {
      case AppActionButtonTone.primary:
      case AppActionButtonTone.danger:
        return Colors.white;
      case AppActionButtonTone.neutral:
        return AppColors.text;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ElevatedButton(
        onPressed: action.onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _background,
          foregroundColor: _foreground,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: action.tone == AppActionButtonTone.neutral
                ? BorderSide(color: AppColors.border.withValues(alpha: 0.8))
                : BorderSide.none,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (action.icon != null) ...[
              Icon(action.icon, size: 19),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                action.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
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
    return Dialog(
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
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.calendar_month_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${DateFormat('yyyy年M月d日').format(_selected)} ${_weekdayLabel(_selected)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
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
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.16),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          DateFormat('yyyy年M月').format(_visibleMonth),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.arrow_drop_down_rounded,
                          color: AppColors.primary,
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.inputBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, size: 30, color: AppColors.textSecondary),
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
                        color: isSelected
                            ? AppColors.primary
                            : Colors.transparent,
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
                              ? AppColors.textTertiary.withValues(alpha: 0.35)
                              : isSelected
                              ? Colors.white
                              : inMonth
                              ? AppColors.text
                              : AppColors.textTertiary.withValues(alpha: 0.45),
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
    return Expanded(
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: AppColors.textSecondary,
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
