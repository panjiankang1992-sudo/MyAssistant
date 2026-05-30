import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/platform/app_performance.dart';
import '../../../domain/models/tag.dart';

class TagChip extends StatelessWidget {
  final String label;
  final String type;
  final String value;
  final String? _colorKey;
  final Color? _bgColor;
  final Color? _textColor;
  final bool selected;

  const TagChip({
    super.key,
    required this.label,
    this.type = '',
    this.value = '',
    this.selected = false,
  }) : _colorKey = null,
       _bgColor = null,
       _textColor = null;

  const TagChip.fromTag({
    super.key,
    required this.label,
    required String colorKey,
    this.selected = false,
  }) : type = '',
       value = '',
       _colorKey = colorKey,
       _bgColor = null,
       _textColor = null;

  const TagChip.withColor({
    super.key,
    required this.label,
    required Color bgColor,
    required Color textColor,
    this.selected = false,
  }) : type = '',
       value = '',
       _colorKey = null,
       _bgColor = bgColor,
       _textColor = textColor;

  Color _getBackgroundColor() {
    if (_bgColor != null) return _bgColor;
    if (_colorKey != null) return TagPalette.bgColor(_colorKey);
    if (type == 'source') {
      switch (value) {
        case 'recommend':
          return AppColors.workBg;
        case 'routine':
          return AppColors.routineBg;
        case 'message':
          return AppColors.messageBg;
        case 'sms':
          return AppColors.healthBg;
        case 'calendar':
          return AppColors.calendarBg;
        default:
          return AppColors.chipBg;
      }
    } else if (type == 'type') {
      switch (value) {
        case 'bill':
          return AppColors.billBg;
        case 'work':
          return AppColors.workBg;
        case 'personal':
          return AppColors.personalBg;
        case 'health':
          return AppColors.healthBg;
        default:
          return AppColors.chipBg;
      }
    }
    return AppColors.chipBg;
  }

  Color _getTextColor() {
    if (_textColor != null) return _textColor;
    if (_colorKey != null) return TagPalette.textColor(_colorKey);
    if (type == 'source') {
      switch (value) {
        case 'recommend':
          return AppColors.primary;
        case 'routine':
          return AppColors.warning;
        case 'message':
          return AppColors.success;
        case 'sms':
          return AppColors.healthText;
        case 'calendar':
          return AppColors.calendarText;
        default:
          return AppColors.textTertiary;
      }
    } else if (type == 'type') {
      switch (value) {
        case 'bill':
          return AppColors.billText;
        case 'work':
          return AppColors.primary;
        case 'personal':
          return AppColors.purple;
        case 'health':
          return AppColors.healthText;
        default:
          return AppColors.textTertiary;
      }
    }
    return AppColors.textTertiary;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = _getBackgroundColor();
    final fg = _getTextColor();
    final fill = scheme.isDarkTheme
        ? Color.alphaBlend(
            fg.withValues(alpha: selected ? 0.24 : 0.16),
            scheme.appSurface,
          )
        : (selected ? fg.withValues(alpha: 0.16) : bg.withValues(alpha: 0.62));
    final reduceMotion = AppPerformance.shouldReduceMotion(context);
    final padding = EdgeInsets.fromLTRB(selected ? 8 : 10, 5, 10, 5);
    final decoration = BoxDecoration(
      color: fill,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(
        color: selected
            ? fg.withValues(alpha: 0.72)
            : fg.withValues(alpha: 0.14),
        width: selected ? 1.4 : 1,
      ),
      boxShadow: selected && !reduceMotion
          ? [
              BoxShadow(
                color: fg.withValues(alpha: 0.12),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ]
          : null,
    );
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (selected) ...[
          Icon(Icons.check_rounded, size: 13, color: fg),
          const SizedBox(width: 3),
        ],
        Text(
          label,
          style: TextStyle(
            fontFamily: 'PingFang SC',
            fontFamilyFallback: const [
              '.SF Pro Text',
              'system-ui',
              'sans-serif',
            ],
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: fg.withValues(alpha: selected ? 1 : 0.86),
          ),
        ),
      ],
    );
    if (reduceMotion) {
      return Container(padding: padding, decoration: decoration, child: child);
    }
    return AnimatedContainer(
      duration: AppAnimations.shortDuration,
      padding: padding,
      decoration: decoration,
      child: child,
    );
  }
}
