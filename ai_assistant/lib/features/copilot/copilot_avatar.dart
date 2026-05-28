import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class CopilotAvatarPreset {
  final String id;
  final String label;
  final IconData icon;
  final List<Color> colors;

  const CopilotAvatarPreset({
    required this.id,
    required this.label,
    required this.icon,
    required this.colors,
  });

  String get value => 'preset:$id';
}

class CopilotAvatarCatalog {
  static const defaultValue = 'preset:spark';

  static const presets = [
    CopilotAvatarPreset(
      id: 'spark',
      label: '灵感',
      icon: Icons.auto_awesome_rounded,
      colors: [Color(0xFF0875E1), Color(0xFF60A5FA)],
    ),
    CopilotAvatarPreset(
      id: 'compass',
      label: '向导',
      icon: Icons.explore_rounded,
      colors: [Color(0xFF14B8A6), Color(0xFF22C55E)],
    ),
    CopilotAvatarPreset(
      id: 'brain',
      label: '思考',
      icon: Icons.psychology_alt_rounded,
      colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
    ),
    CopilotAvatarPreset(
      id: 'orbit',
      label: '执行',
      icon: Icons.hub_rounded,
      colors: [Color(0xFFFF9500), Color(0xFFFF5E3A)],
    ),
    CopilotAvatarPreset(
      id: 'shield',
      label: '稳妥',
      icon: Icons.verified_user_rounded,
      colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
    ),
    CopilotAvatarPreset(
      id: 'leaf',
      label: '轻盈',
      icon: Icons.local_florist_rounded,
      colors: [Color(0xFF16A34A), Color(0xFF84CC16)],
    ),
  ];

  static String normalize(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return defaultValue;
    if (trimmed.startsWith('preset:') ||
        trimmed.startsWith('file:') ||
        trimmed.startsWith('emoji:')) {
      return trimmed;
    }
    return 'emoji:$trimmed';
  }

  static String fileValue(String path) => 'file:$path';

  static CopilotAvatarPreset presetOf(String value) {
    final id = normalize(value).replaceFirst('preset:', '');
    return presets.firstWhere(
      (item) => item.id == id,
      orElse: () => presets.first,
    );
  }

  static String descriptionOf(String value) {
    final normalized = normalize(value);
    if (normalized.startsWith('preset:')) {
      return '默认头像：${presetOf(normalized).label}';
    }
    if (normalized.startsWith('file:')) return '用户自定义图片头像';
    if (normalized.startsWith('emoji:')) {
      return '符号头像：${normalized.replaceFirst('emoji:', '')}';
    }
    return '默认头像';
  }
}

class CopilotAvatarView extends StatelessWidget {
  final String value;
  final double size;
  final bool isError;
  final bool selected;
  final EdgeInsetsGeometry? margin;

  const CopilotAvatarView({
    super.key,
    required this.value,
    this.size = 38,
    this.isError = false,
    this.selected = false,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final normalized = CopilotAvatarCatalog.normalize(value);
    final borderColor = selected
        ? AppColors.primary.withValues(alpha: 0.64)
        : Colors.white.withValues(alpha: 0.2);
    return Container(
      width: size,
      height: size,
      margin: margin,
      padding: EdgeInsets.all(selected ? 3 : 0),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppColors.primary.withValues(alpha: 0.12) : null,
        border: selected ? Border.all(color: borderColor, width: 1.5) : null,
      ),
      child: ClipOval(child: _avatarBody(normalized)),
    );
  }

  Widget _avatarBody(String value) {
    if (isError) {
      return _gradientBody(
        colors: [
          AppColors.danger.withValues(alpha: 0.95),
          const Color(0xFFFF9B8F),
        ],
        child: const Icon(
          Icons.priority_high_rounded,
          color: Colors.white,
          size: 19,
        ),
      );
    }
    if (value.startsWith('file:')) {
      final path = value.replaceFirst('file:', '');
      return Image.file(
        File(path),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            _presetBody(CopilotAvatarCatalog.presets.first),
      );
    }
    if (value.startsWith('emoji:')) {
      final text = value.replaceFirst('emoji:', '');
      final glyph = String.fromCharCodes(text.runes.take(2));
      return _gradientBody(
        colors: const [AppColors.primary, Color(0xFF60A5FA)],
        child: Text(
          glyph.isEmpty ? '✦' : glyph,
          maxLines: 1,
          overflow: TextOverflow.clip,
          style: TextStyle(
            fontSize: size * 0.44,
            fontWeight: FontWeight.w900,
            height: 1,
            color: Colors.white,
          ),
        ),
      );
    }
    return _presetBody(CopilotAvatarCatalog.presetOf(value));
  }

  Widget _presetBody(CopilotAvatarPreset preset) {
    return _gradientBody(
      colors: preset.colors,
      child: Icon(preset.icon, color: Colors.white, size: size * 0.5),
    );
  }

  Widget _gradientBody({required List<Color> colors, required Widget child}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Center(child: child),
    );
  }
}
