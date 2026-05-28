import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

enum CopilotAvatarKind {
  boy,
  girl,
  teenBoy,
  teenGirl,
  youngMan,
  youngWoman,
  middleMan,
  youngMom,
  animal,
}

class CopilotAvatarPreset {
  final String id;
  final String label;
  final CopilotAvatarKind kind;
  final int variant;
  final List<Color> colors;

  const CopilotAvatarPreset({
    required this.id,
    required this.label,
    required this.kind,
    required this.variant,
    required this.colors,
  });

  String get value => 'preset:$id';

  String get assetPath => 'assets/avatars/copilot_$id.png';
}

class CopilotAvatarGroup {
  final String label;
  final CopilotAvatarKind kind;

  const CopilotAvatarGroup(this.label, this.kind);
}

class CopilotAvatarCatalog {
  static const defaultValue = 'preset:young_man_1';

  static const groups = [
    CopilotAvatarGroup('小男孩', CopilotAvatarKind.boy),
    CopilotAvatarGroup('小女孩', CopilotAvatarKind.girl),
    CopilotAvatarGroup('少年', CopilotAvatarKind.teenBoy),
    CopilotAvatarGroup('少女', CopilotAvatarKind.teenGirl),
    CopilotAvatarGroup('青年男性', CopilotAvatarKind.youngMan),
    CopilotAvatarGroup('青年女性', CopilotAvatarKind.youngWoman),
    CopilotAvatarGroup('中年男性', CopilotAvatarKind.middleMan),
    CopilotAvatarGroup('少妇', CopilotAvatarKind.youngMom),
    CopilotAvatarGroup('动物', CopilotAvatarKind.animal),
  ];

  static const presets = [
    CopilotAvatarPreset(
      id: 'boy_1',
      label: '暖阳',
      kind: CopilotAvatarKind.boy,
      variant: 1,
      colors: [Color(0xFFFFC857), Color(0xFFFF8A65)],
    ),
    CopilotAvatarPreset(
      id: 'boy_2',
      label: '蓝帽',
      kind: CopilotAvatarKind.boy,
      variant: 2,
      colors: [Color(0xFF60A5FA), Color(0xFF2563EB)],
    ),
    CopilotAvatarPreset(
      id: 'boy_3',
      label: '绿野',
      kind: CopilotAvatarKind.boy,
      variant: 3,
      colors: [Color(0xFF86EFAC), Color(0xFF16A34A)],
    ),
    CopilotAvatarPreset(
      id: 'boy_4',
      label: '星星',
      kind: CopilotAvatarKind.boy,
      variant: 4,
      colors: [Color(0xFF7DD3FC), Color(0xFF7C3AED)],
    ),
    CopilotAvatarPreset(
      id: 'girl_1',
      label: '花发',
      kind: CopilotAvatarKind.girl,
      variant: 1,
      colors: [Color(0xFFFFB7C5), Color(0xFFF472B6)],
    ),
    CopilotAvatarPreset(
      id: 'girl_2',
      label: '紫裙',
      kind: CopilotAvatarKind.girl,
      variant: 2,
      colors: [Color(0xFFC4B5FD), Color(0xFF8B5CF6)],
    ),
    CopilotAvatarPreset(
      id: 'girl_3',
      label: '青柠',
      kind: CopilotAvatarKind.girl,
      variant: 3,
      colors: [Color(0xFFA7F3D0), Color(0xFF10B981)],
    ),
    CopilotAvatarPreset(
      id: 'girl_4',
      label: '蝴蝶',
      kind: CopilotAvatarKind.girl,
      variant: 4,
      colors: [Color(0xFFFDE68A), Color(0xFFFB7185)],
    ),
    CopilotAvatarPreset(
      id: 'teen_boy_1',
      label: '耳机',
      kind: CopilotAvatarKind.teenBoy,
      variant: 1,
      colors: [Color(0xFF93C5FD), Color(0xFF1D4ED8)],
    ),
    CopilotAvatarPreset(
      id: 'teen_boy_2',
      label: '棒球',
      kind: CopilotAvatarKind.teenBoy,
      variant: 2,
      colors: [Color(0xFFFCA5A5), Color(0xFFEF4444)],
    ),
    CopilotAvatarPreset(
      id: 'teen_boy_3',
      label: '学院',
      kind: CopilotAvatarKind.teenBoy,
      variant: 3,
      colors: [Color(0xFFA5B4FC), Color(0xFF4F46E5)],
    ),
    CopilotAvatarPreset(
      id: 'teen_boy_4',
      label: '滑板',
      kind: CopilotAvatarKind.teenBoy,
      variant: 4,
      colors: [Color(0xFF67E8F9), Color(0xFF0891B2)],
    ),
    CopilotAvatarPreset(
      id: 'teen_girl_1',
      label: '短发',
      kind: CopilotAvatarKind.teenGirl,
      variant: 1,
      colors: [Color(0xFFF0ABFC), Color(0xFFC026D3)],
    ),
    CopilotAvatarPreset(
      id: 'teen_girl_2',
      label: '发夹',
      kind: CopilotAvatarKind.teenGirl,
      variant: 2,
      colors: [Color(0xFFF9A8D4), Color(0xFFEC4899)],
    ),
    CopilotAvatarPreset(
      id: 'teen_girl_3',
      label: '校服',
      kind: CopilotAvatarKind.teenGirl,
      variant: 3,
      colors: [Color(0xFFBFDBFE), Color(0xFF3B82F6)],
    ),
    CopilotAvatarPreset(
      id: 'teen_girl_4',
      label: '画笔',
      kind: CopilotAvatarKind.teenGirl,
      variant: 4,
      colors: [Color(0xFFFDE68A), Color(0xFFF97316)],
    ),
    CopilotAvatarPreset(
      id: 'young_man_1',
      label: '科技',
      kind: CopilotAvatarKind.youngMan,
      variant: 1,
      colors: [Color(0xFF0875E1), Color(0xFF60A5FA)],
    ),
    CopilotAvatarPreset(
      id: 'young_man_2',
      label: '商务',
      kind: CopilotAvatarKind.youngMan,
      variant: 2,
      colors: [Color(0xFF64748B), Color(0xFF111827)],
    ),
    CopilotAvatarPreset(
      id: 'young_man_3',
      label: '运动',
      kind: CopilotAvatarKind.youngMan,
      variant: 3,
      colors: [Color(0xFF34D399), Color(0xFF059669)],
    ),
    CopilotAvatarPreset(
      id: 'young_man_4',
      label: '创意',
      kind: CopilotAvatarKind.youngMan,
      variant: 4,
      colors: [Color(0xFFA78BFA), Color(0xFF7C3AED)],
    ),
    CopilotAvatarPreset(
      id: 'young_woman_1',
      label: '干练',
      kind: CopilotAvatarKind.youngWoman,
      variant: 1,
      colors: [Color(0xFF60A5FA), Color(0xFF8B5CF6)],
    ),
    CopilotAvatarPreset(
      id: 'young_woman_2',
      label: '温柔',
      kind: CopilotAvatarKind.youngWoman,
      variant: 2,
      colors: [Color(0xFFFFB4A2), Color(0xFFFB7185)],
    ),
    CopilotAvatarPreset(
      id: 'young_woman_3',
      label: '自然',
      kind: CopilotAvatarKind.youngWoman,
      variant: 3,
      colors: [Color(0xFF99F6E4), Color(0xFF0D9488)],
    ),
    CopilotAvatarPreset(
      id: 'young_woman_4',
      label: '艺术',
      kind: CopilotAvatarKind.youngWoman,
      variant: 4,
      colors: [Color(0xFFF0ABFC), Color(0xFFDB2777)],
    ),
    CopilotAvatarPreset(
      id: 'middle_man_1',
      label: '沉稳',
      kind: CopilotAvatarKind.middleMan,
      variant: 1,
      colors: [Color(0xFF94A3B8), Color(0xFF334155)],
    ),
    CopilotAvatarPreset(
      id: 'middle_man_2',
      label: '学者',
      kind: CopilotAvatarKind.middleMan,
      variant: 2,
      colors: [Color(0xFFFCD34D), Color(0xFF92400E)],
    ),
    CopilotAvatarPreset(
      id: 'middle_man_3',
      label: '导师',
      kind: CopilotAvatarKind.middleMan,
      variant: 3,
      colors: [Color(0xFFA7F3D0), Color(0xFF047857)],
    ),
    CopilotAvatarPreset(
      id: 'middle_man_4',
      label: '西装',
      kind: CopilotAvatarKind.middleMan,
      variant: 4,
      colors: [Color(0xFFC4B5FD), Color(0xFF4338CA)],
    ),
    CopilotAvatarPreset(
      id: 'young_mom_1',
      label: '生活',
      kind: CopilotAvatarKind.youngMom,
      variant: 1,
      colors: [Color(0xFFFBCFE8), Color(0xFFEC4899)],
    ),
    CopilotAvatarPreset(
      id: 'young_mom_2',
      label: '优雅',
      kind: CopilotAvatarKind.youngMom,
      variant: 2,
      colors: [Color(0xFFDDD6FE), Color(0xFF8B5CF6)],
    ),
    CopilotAvatarPreset(
      id: 'young_mom_3',
      label: '亲和',
      kind: CopilotAvatarKind.youngMom,
      variant: 3,
      colors: [Color(0xFFFED7AA), Color(0xFFEA580C)],
    ),
    CopilotAvatarPreset(
      id: 'young_mom_4',
      label: '柔光',
      kind: CopilotAvatarKind.youngMom,
      variant: 4,
      colors: [Color(0xFFBAE6FD), Color(0xFF0EA5E9)],
    ),
    CopilotAvatarPreset(
      id: 'animal_1',
      label: '猫咪',
      kind: CopilotAvatarKind.animal,
      variant: 1,
      colors: [Color(0xFFFFD6A5), Color(0xFFFF8A65)],
    ),
    CopilotAvatarPreset(
      id: 'animal_2',
      label: '小熊',
      kind: CopilotAvatarKind.animal,
      variant: 2,
      colors: [Color(0xFFFDE68A), Color(0xFFD97706)],
    ),
    CopilotAvatarPreset(
      id: 'animal_3',
      label: '小狗',
      kind: CopilotAvatarKind.animal,
      variant: 3,
      colors: [Color(0xFFA7F3D0), Color(0xFF059669)],
    ),
    CopilotAvatarPreset(
      id: 'animal_4',
      label: '狐狸',
      kind: CopilotAvatarKind.animal,
      variant: 4,
      colors: [Color(0xFFFCA5A5), Color(0xFFEA580C)],
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
      orElse: () => presets.firstWhere((item) => item.value == defaultValue),
    );
  }

  static String descriptionOf(String value) {
    final normalized = normalize(value);
    if (normalized.startsWith('preset:')) {
      final preset = presetOf(normalized);
      final group = groups.firstWhere((item) => item.kind == preset.kind);
      return '默认卡通头像：${group.label} / ${preset.label}';
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
        borderRadius: BorderRadius.circular(size * 0.26),
        color: selected ? AppColors.primary.withValues(alpha: 0.12) : null,
        border: selected ? Border.all(color: borderColor, width: 1.5) : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.22),
        child: _avatarBody(normalized),
      ),
    );
  }

  Widget _avatarBody(String value) {
    if (isError) {
      return _errorBody();
    }
    if (value.startsWith('file:')) {
      final path = value.replaceFirst('file:', '');
      return Image.file(
        File(path),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _presetBody(
          CopilotAvatarCatalog.presetOf(CopilotAvatarCatalog.defaultValue),
        ),
      );
    }
    if (value.startsWith('emoji:')) {
      return _emojiBody(value.replaceFirst('emoji:', ''));
    }
    return _presetBody(CopilotAvatarCatalog.presetOf(value));
  }

  Widget _errorBody() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            AppColors.danger.withValues(alpha: 0.95),
            const Color(0xFFFF9B8F),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Icon(
        Icons.priority_high_rounded,
        color: Colors.white,
        size: 19,
      ),
    );
  }

  Widget _emojiBody(String text) {
    final glyph = String.fromCharCodes(text.runes.take(2));
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [AppColors.primary, Color(0xFF60A5FA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
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
      ),
    );
  }

  Widget _presetBody(CopilotAvatarPreset preset) {
    return Image.asset(
      preset.assetPath,
      width: size,
      height: size,
      fit: BoxFit.cover,
    );
  }
}
