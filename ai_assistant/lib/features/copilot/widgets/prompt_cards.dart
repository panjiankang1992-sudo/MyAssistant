import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../skills/builtin_skill.dart';
import '../../skills/builtin_skill_registry.dart';

class PromptCards extends StatelessWidget {
  final void Function(String) onTap;

  const PromptCards({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const prompts = [
      _PromptData(Icons.analytics_rounded, '分析本月消费趋势', AppColors.workBg),
      _PromptData(Icons.article_rounded, '总结本周工作内容', Color(0xFFE8FAF3)),
      _PromptData(Icons.event_rounded, '安排明天的日程', AppColors.routineBg),
      _PromptData(Icons.lightbulb_rounded, '看看即将到期的待办', AppColors.personalBg),
    ];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 520;
              final itemWidth = isCompact
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 10) / 2;

              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: prompts.map((p) {
                  return SizedBox(
                    width: itemWidth,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => onTap(p.text),
                        borderRadius: BorderRadius.circular(14),
                        child: Ink(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 13,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: p.bgColor,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  p.icon,
                                  size: 15,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  p.text,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'PingFang SC',
                                    fontFamilyFallback: [
                                      '.SF Pro Text',
                                      'system-ui',
                                      'sans-serif',
                                    ],
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.text,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.north_east_rounded,
                                size: 14,
                                color: AppColors.textTertiary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),
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

class BuiltinSkillCards extends StatelessWidget {
  final void Function(String) onTap;

  const BuiltinSkillCards({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const skills = BuiltinSkillRegistry.all;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.extension_rounded,
                    size: 17,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(width: 7),
                  Text(
                    '内置技能',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: AppColors.text,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 560;
                  final itemWidth = isCompact
                      ? constraints.maxWidth
                      : (constraints.maxWidth - 16) / 3;
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: skills.map((skill) {
                      return SizedBox(
                        width: itemWidth,
                        child: _BuiltinSkillCard(
                          skill: skill,
                          onTap: () => onTap('介绍一下内置技能 ${skill.name}'),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BuiltinSkillCard extends StatelessWidget {
  final BuiltinSkill skill;
  final VoidCallback onTap;

  const _BuiltinSkillCard({required this.skill, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: skill.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(skill.icon, size: 16, color: skill.color),
                  ),
                  const Spacer(),
                  Text(
                    skill.id,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textTertiary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Text(
                skill.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                skill.summary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
