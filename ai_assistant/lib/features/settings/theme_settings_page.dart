import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_settings.dart';

class ThemeSettingsPage extends ConsumerWidget {
  const ThemeSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings =
        ref.watch(themeSettingsProvider).value ?? const ThemeSettings();
    final notifier = ref.read(themeSettingsProvider.notifier);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('主题设置'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _IconActionButton(
              icon: Icons.restart_alt_rounded,
              tooltip: '恢复默认',
              onTap: notifier.reset,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 36),
        children: [
          _ThemePreview(settings: settings),
          const SizedBox(height: 22),
          const _SectionHeader(title: '外观', subtitle: '默认跟随系统，也可以手动固定浅色或深色。'),
          const SizedBox(height: 10),
          _ModeGrid(selected: settings.mode, onChanged: notifier.setMode),
          const SizedBox(height: 24),
          const _SectionHeader(title: '强调色', subtitle: '用于按钮、选中状态、输入焦点和关键操作。'),
          const SizedBox(height: 12),
          _AccentGrid(selected: settings.accent, onChanged: notifier.setAccent),
          const SizedBox(height: 24),
          const _SectionHeader(
            title: '显示密度',
            subtitle: '舒适适合触摸，紧凑适合桌面和大量信息浏览。',
          ),
          const SizedBox(height: 10),
          _DensitySelector(
            selected: settings.density,
            onChanged: notifier.setDensity,
          ),
          const SizedBox(height: 24),
          const _SectionHeader(title: '辅助显示'),
          const SizedBox(height: 10),
          _ToggleRow(
            icon: Icons.animation_rounded,
            title: '减少动效',
            subtitle: '弱化水波纹和过渡动画，减少视觉干扰。',
            value: settings.reduceMotion,
            onChanged: notifier.setReduceMotion,
          ),
          const SizedBox(height: 10),
          _ToggleRow(
            icon: Icons.contrast_rounded,
            title: '高对比度',
            subtitle: '提高边框、文本和关键状态的对比度。',
            value: settings.highContrast,
            onChanged: notifier.setHighContrast,
          ),
        ],
      ),
    );
  }
}

class _ThemePreview extends StatelessWidget {
  final ThemeSettings settings;

  const _ThemePreview({required this.settings});

  @override
  Widget build(BuildContext context) {
    final accent = settings.accent.color;
    final isDark = settings.mode == AppThemeMode.dark;
    final bg = isDark ? const Color(0xFF15161B) : AppColors.surface;
    final panel = isDark ? const Color(0xFF24252B) : AppColors.inputBg;
    final text = isDark ? Colors.white : AppColors.text;
    final sub = isDark ? const Color(0xFFB8B8BE) : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: settings.highContrast
              ? accent.withValues(alpha: 0.42)
              : AppColors.border.withValues(alpha: 0.72),
        ),
        boxShadow: AppAnimations.cardShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(Icons.palette_rounded, color: accent, size: 23),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${settings.mode.label} · ${settings.accent.label}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      settings.density == AppThemeDensity.compact
                          ? '紧凑布局，信息展示更密集'
                          : '舒适布局，触摸空间更充足',
                      style: TextStyle(fontSize: 13, color: sub),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: panel,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    _PreviewDot(color: accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 10,
                        decoration: BoxDecoration(
                          color: sub.withValues(alpha: 0.28),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Container(
                      width: 54,
                      height: 24,
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _PreviewLine(color: sub.withValues(alpha: 0.22)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _PreviewLine(
                        color: accent.withValues(alpha: 0.22),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeGrid extends StatelessWidget {
  final AppThemeMode selected;
  final ValueChanged<AppThemeMode> onChanged;

  const _ModeGrid({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 520 ? 1 : 3;
        return GridView.count(
          crossAxisCount: columns,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: columns == 1 ? 4.2 : 1.45,
          children: [
            for (final mode in AppThemeMode.values)
              _ModeTile(
                mode: mode,
                selected: selected == mode,
                onTap: () => onChanged(mode),
              ),
          ],
        );
      },
    );
  }
}

class _ModeTile extends StatelessWidget {
  final AppThemeMode mode;
  final bool selected;
  final VoidCallback onTap;

  const _ModeTile({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppAnimations.shortDuration,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.09) : scheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.48)
                : scheme.outline.withValues(alpha: 0.42),
          ),
        ),
        child: Row(
          children: [
            Icon(
              mode.icon,
              size: 22,
              color: selected ? accent : AppColors.textSecondary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mode.label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: selected ? accent : scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    mode.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.25,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, size: 18, color: accent),
          ],
        ),
      ),
    );
  }
}

class _AccentGrid extends StatelessWidget {
  final AppAccentColor selected;
  final ValueChanged<AppAccentColor> onChanged;

  const _AccentGrid({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final item in AppAccentColors.all)
          _AccentTile(
            item: item,
            selected: selected.id == item.id,
            onTap: () => onChanged(item),
          ),
      ],
    );
  }
}

class _AccentTile extends StatelessWidget {
  final AppAccentColor item;
  final bool selected;
  final VoidCallback onTap;

  const _AccentTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppAnimations.shortDuration,
        width: 142,
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? item.color.withValues(alpha: 0.12) : scheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? item.color.withValues(alpha: 0.5)
                : scheme.outline.withValues(alpha: 0.42),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: item.color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: item.color.withValues(alpha: 0.28),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: selected
                  ? const Icon(
                      Icons.check_rounded,
                      size: 15,
                      color: Colors.white,
                    )
                  : null,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                item.label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected ? item.color : scheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DensitySelector extends StatelessWidget {
  final AppThemeDensity selected;
  final ValueChanged<AppThemeDensity> onChanged;

  const _DensitySelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          scheme.primary.withValues(alpha: 0.025),
          scheme.surface,
        ),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.42)),
      ),
      child: Row(
        children: [
          for (final item in AppThemeDensity.values)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(item),
                child: AnimatedContainer(
                  duration: AppAnimations.shortDuration,
                  height: 48,
                  decoration: BoxDecoration(
                    color: selected == item
                        ? scheme.surface
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: selected == item
                        ? AppAnimations.cardShadow()
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        item.icon,
                        size: 18,
                        color: selected == item
                            ? accent
                            : scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: selected == item
                              ? accent
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.42)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ).copyWith(color: scheme.onSurface),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.25,
                  ).copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _SectionHeader({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: scheme.onSurface,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 5),
          Text(
            subtitle!,
            style: TextStyle(
              fontSize: 13,
              height: 1.35,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _PreviewDot extends StatelessWidget {
  final Color color;

  const _PreviewDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _PreviewLine extends StatelessWidget {
  final Color color;

  const _PreviewLine({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }
}

class _IconActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _IconActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.inputBg,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, size: 20, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
