import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/models/todo.dart';

class TodoReminderSelector extends StatelessWidget {
  final bool enabled;
  final int minutesBefore;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<int> onMinutesChanged;

  const TodoReminderSelector({
    super.key,
    required this.enabled,
    required this.minutesBefore,
    required this.onEnabledChanged,
    required this.onMinutesChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const options = [
      (10, '10分钟'),
      (30, '30分钟'),
      (60, '1小时'),
      (120, '2小时'),
      (1440, '1天'),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _ReminderChip(
          label: '不提醒',
          selected: !enabled,
          icon: Icons.notifications_off_rounded,
          onTap: () => onEnabledChanged(false),
        ),
        for (final option in options)
          _ReminderChip(
            label: option.$2,
            selected: enabled && minutesBefore == option.$1,
            icon: option.$1 >= Todo.elevatedReminderMinutes
                ? Icons.event_available_rounded
                : Icons.alarm_rounded,
            onTap: () {
              onMinutesChanged(option.$1);
              onEnabledChanged(true);
            },
          ),
        if (enabled && !options.any((item) => item.$1 == minutesBefore))
          Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: scheme.primary.withValues(alpha: 0.24)),
            ),
            child: Text(
              Todo.formatReminderMinutes(minutesBefore),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: scheme.primary,
              ),
            ),
          ),
      ],
    );
  }
}

class _ReminderChip extends StatelessWidget {
  final String label;
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;

  const _ReminderChip({
    required this.label,
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = selected ? scheme.primary : scheme.appInput;
    final fg = selected ? Colors.white : scheme.appMutedText;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          color: selected ? bg : bg.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: selected ? scheme.primary : scheme.appBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: fg),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
