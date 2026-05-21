import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class TagChip extends StatelessWidget {
  final String label;
  final String type;
  final String value;

  const TagChip({
    super.key,
    required this.label,
    required this.type,
    required this.value,
  });

  Color _getBackgroundColor() {
    if (type == 'source') {
      switch (value) {
        case 'recommend': return AppColors.workBg;
        case 'routine': return AppColors.routineBg;
        case 'message': return AppColors.messageBg;
        case 'calendar': return AppColors.calendarBg;
        default: return AppColors.chipBg;
      }
    } else if (type == 'type') {
      switch (value) {
        case 'bill': return AppColors.billBg;
        case 'work': return AppColors.workBg;
        case 'personal': return AppColors.personalBg;
        case 'health': return AppColors.healthBg;
        default: return AppColors.chipBg;
      }
    }
    return AppColors.chipBg;
  }

  Color _getTextColor() {
    if (type == 'source') {
      switch (value) {
        case 'recommend': return AppColors.primary;
        case 'routine': return AppColors.warning;
        case 'message': return AppColors.success;
        case 'calendar': return AppColors.calendarText;
        default: return AppColors.textTertiary;
      }
    } else if (type == 'type') {
      switch (value) {
        case 'bill': return AppColors.billText;
        case 'work': return AppColors.primary;
        case 'personal': return AppColors.purple;
        case 'health': return AppColors.healthText;
        default: return AppColors.textTertiary;
      }
    }
    return AppColors.textTertiary;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _getBackgroundColor(),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'PingFang SC',
          fontFamilyFallback: const ['.SF Pro Text', 'system-ui', 'sans-serif'],
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: _getTextColor(),
        ),
      ),
    );
  }
}