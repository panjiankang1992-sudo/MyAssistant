import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class PromptCards extends StatelessWidget {
  final void Function(String) onTap;

  const PromptCards({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final prompts = [
      _PromptData(Icons.analytics, '分析本月消费趋势，给出省钱建议', AppColors.workBg),
      _PromptData(Icons.article, '总结我本周的工作内容，生成周报', const Color(0xFFE8FAF3)),
      _PromptData(Icons.event, '根据待办事项安排明天的日程', AppColors.routineBg),
      _PromptData(Icons.lightbulb, '提醒我有哪些即将到期的待办', AppColors.personalBg),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: prompts.map((p) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              elevation: 0,
              child: InkWell(
                onTap: () => onTap(p.text),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: p.bgColor,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(p.icon, size: 15, color: AppColors.textSecondary),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          p.text,
                          style: const TextStyle(
                            fontFamily: 'PingFang SC',
                            fontFamilyFallback: ['.SF Pro Text', 'system-ui', 'sans-serif'],
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _PromptData {
  final IconData icon;
  final String text;
  final Color bgColor;

  const _PromptData(this.icon, this.text, this.bgColor);
}