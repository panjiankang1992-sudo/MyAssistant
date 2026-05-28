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
        shape: BoxShape.circle,
        color: selected ? AppColors.primary.withValues(alpha: 0.12) : null,
        border: selected ? Border.all(color: borderColor, width: 1.5) : null,
      ),
      child: ClipOval(child: _avatarBody(normalized)),
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
    return CustomPaint(
      size: Size.square(size),
      painter: _CartoonAvatarPainter(preset),
    );
  }
}

class _CartoonAvatarPainter extends CustomPainter {
  final CopilotAvatarPreset preset;

  const _CartoonAvatarPainter(this.preset);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final center = Offset(size.width / 2, size.height / 2);
    final bgPaint = Paint()
      ..shader = LinearGradient(
        colors: preset.colors,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Offset.zero & size);
    canvas.drawCircle(center, s / 2, bgPaint);
    _drawPattern(canvas, size);
    if (preset.kind == CopilotAvatarKind.animal) {
      _drawAnimal(canvas, size);
    } else {
      _drawPerson(canvas, size);
    }
  }

  void _drawPattern(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final glow = Paint()..color = Colors.white.withValues(alpha: 0.18);
    canvas.drawCircle(Offset(s * 0.22, s * 0.24), s * 0.08, glow);
    canvas.drawCircle(Offset(s * 0.82, s * 0.18), s * 0.035, glow);
    if (preset.variant.isEven) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(s * 0.64, s * 0.72, s * 0.18, s * 0.08),
          Radius.circular(s * 0.04),
        ),
        glow,
      );
    }
  }

  void _drawPerson(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final skin = _skinColor();
    final hair = _hairColor();
    final outfit = _outfitColor();
    final faceCenter = Offset(s * 0.5, s * 0.48);
    final faceRadius = _faceRadius(s);
    final neck = Paint()..color = skin;
    final shirt = Paint()..color = outfit;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(s * 0.38, s * 0.68, s * 0.24, s * 0.18),
        Radius.circular(s * 0.08),
      ),
      neck,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(s * 0.5, s * 0.9),
        width: s * 0.7,
        height: s * 0.36,
      ),
      shirt,
    );
    _drawHairBack(canvas, s, hair);
    canvas.drawCircle(faceCenter, faceRadius, Paint()..color = skin);
    _drawHairFront(canvas, s, hair);
    _drawFace(canvas, s);
    _drawAccessories(canvas, s);
  }

  void _drawHairBack(Canvas canvas, double s, Color hair) {
    final paint = Paint()..color = hair;
    switch (preset.kind) {
      case CopilotAvatarKind.girl:
      case CopilotAvatarKind.teenGirl:
      case CopilotAvatarKind.youngWoman:
      case CopilotAvatarKind.youngMom:
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(s * 0.5, s * 0.48),
            width: s * 0.66,
            height: s * 0.68,
          ),
          paint,
        );
      case CopilotAvatarKind.middleMan:
      case CopilotAvatarKind.youngMan:
      case CopilotAvatarKind.teenBoy:
      case CopilotAvatarKind.boy:
      case CopilotAvatarKind.animal:
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(s * 0.5, s * 0.38),
            width: s * 0.55,
            height: s * 0.32,
          ),
          paint,
        );
    }
  }

  void _drawHairFront(Canvas canvas, double s, Color hair) {
    final paint = Paint()..color = hair;
    final path = Path();
    if (preset.variant == 1) {
      path
        ..moveTo(s * 0.23, s * 0.39)
        ..quadraticBezierTo(s * 0.42, s * 0.15, s * 0.73, s * 0.34)
        ..quadraticBezierTo(s * 0.56, s * 0.29, s * 0.43, s * 0.42)
        ..quadraticBezierTo(s * 0.34, s * 0.34, s * 0.23, s * 0.39);
    } else if (preset.variant == 2) {
      path
        ..moveTo(s * 0.24, s * 0.36)
        ..quadraticBezierTo(s * 0.48, s * 0.17, s * 0.76, s * 0.37)
        ..lineTo(s * 0.76, s * 0.45)
        ..quadraticBezierTo(s * 0.52, s * 0.34, s * 0.24, s * 0.45)
        ..close();
    } else if (preset.variant == 3) {
      path
        ..moveTo(s * 0.22, s * 0.4)
        ..quadraticBezierTo(s * 0.34, s * 0.18, s * 0.52, s * 0.28)
        ..quadraticBezierTo(s * 0.68, s * 0.2, s * 0.78, s * 0.4)
        ..quadraticBezierTo(s * 0.54, s * 0.32, s * 0.22, s * 0.4);
    } else {
      path
        ..moveTo(s * 0.25, s * 0.37)
        ..quadraticBezierTo(s * 0.48, s * 0.13, s * 0.75, s * 0.38)
        ..quadraticBezierTo(s * 0.62, s * 0.43, s * 0.5, s * 0.33)
        ..quadraticBezierTo(s * 0.39, s * 0.45, s * 0.25, s * 0.37);
    }
    canvas.drawPath(path, paint);

    if (_isFeminine) {
      final sidePaint = Paint()..color = hair;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(s * 0.22, s * 0.52),
          width: s * 0.16,
          height: s * 0.34,
        ),
        sidePaint,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(s * 0.78, s * 0.52),
          width: s * 0.16,
          height: s * 0.34,
        ),
        sidePaint,
      );
    }
  }

  void _drawFace(Canvas canvas, double s) {
    final eye = Paint()..color = const Color(0xFF1F2937);
    canvas.drawCircle(Offset(s * 0.4, s * 0.49), s * 0.028, eye);
    canvas.drawCircle(Offset(s * 0.6, s * 0.49), s * 0.028, eye);
    final blush = Paint()
      ..color = const Color(0xFFFF7A90).withValues(alpha: 0.28);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(s * 0.34, s * 0.56),
        width: s * 0.08,
        height: s * 0.035,
      ),
      blush,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(s * 0.66, s * 0.56),
        width: s * 0.08,
        height: s * 0.035,
      ),
      blush,
    );
    final smile = Paint()
      ..color = const Color(0xFF1F2937)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.018
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(s * 0.5, s * 0.57),
        width: s * 0.17,
        height: s * 0.11,
      ),
      0.2,
      2.75,
      false,
      smile,
    );
    if (preset.kind == CopilotAvatarKind.middleMan && preset.variant.isOdd) {
      final moustache = Paint()
        ..color = _hairColor()
        ..strokeWidth = s * 0.018
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(s * 0.44, s * 0.56),
        Offset(s * 0.5, s * 0.55),
        moustache,
      );
      canvas.drawLine(
        Offset(s * 0.5, s * 0.55),
        Offset(s * 0.56, s * 0.56),
        moustache,
      );
    }
  }

  void _drawAccessories(Canvas canvas, double s) {
    final accent = Paint()
      ..color = Colors.white.withValues(alpha: 0.82)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.018
      ..strokeCap = StrokeCap.round;
    if (preset.kind == CopilotAvatarKind.teenBoy && preset.variant == 1) {
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(s * 0.5, s * 0.49),
          width: s * 0.58,
          height: s * 0.5,
        ),
        3.35,
        2.75,
        false,
        accent,
      );
      canvas.drawCircle(
        Offset(s * 0.27, s * 0.52),
        s * 0.055,
        Paint()..color = Colors.white,
      );
      canvas.drawCircle(
        Offset(s * 0.73, s * 0.52),
        s * 0.055,
        Paint()..color = Colors.white,
      );
    }
    if ((_isFeminine && preset.variant == 2) ||
        preset.kind == CopilotAvatarKind.girl) {
      final bow = Paint()..color = const Color(0xFFFF4D8D);
      canvas.drawCircle(Offset(s * 0.69, s * 0.31), s * 0.035, bow);
      canvas.drawCircle(Offset(s * 0.76, s * 0.31), s * 0.035, bow);
      canvas.drawCircle(
        Offset(s * 0.725, s * 0.32),
        s * 0.02,
        Paint()..color = Colors.white,
      );
    }
    if (preset.kind == CopilotAvatarKind.youngMan && preset.variant == 2) {
      final glasses = Paint()
        ..color = const Color(0xFF111827)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.015;
      canvas.drawCircle(Offset(s * 0.4, s * 0.49), s * 0.055, glasses);
      canvas.drawCircle(Offset(s * 0.6, s * 0.49), s * 0.055, glasses);
      canvas.drawLine(
        Offset(s * 0.455, s * 0.49),
        Offset(s * 0.545, s * 0.49),
        glasses,
      );
    }
  }

  void _drawAnimal(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final animalColor = switch (preset.variant) {
      1 => const Color(0xFFFFF1D6),
      2 => const Color(0xFFB7794B),
      3 => const Color(0xFFE9D5B5),
      _ => const Color(0xFFF97316),
    };
    final dark = switch (preset.variant) {
      1 => const Color(0xFF5B4033),
      2 => const Color(0xFF3B2617),
      3 => const Color(0xFF4B3427),
      _ => const Color(0xFF7C2D12),
    };
    final face = Paint()..color = animalColor;
    final feature = Paint()..color = dark;
    if (preset.variant == 1 || preset.variant == 4) {
      final earPaint = Paint()..color = animalColor;
      final left = Path()
        ..moveTo(s * 0.25, s * 0.36)
        ..lineTo(s * 0.34, s * 0.16)
        ..lineTo(s * 0.46, s * 0.34)
        ..close();
      final right = Path()
        ..moveTo(s * 0.54, s * 0.34)
        ..lineTo(s * 0.67, s * 0.16)
        ..lineTo(s * 0.75, s * 0.36)
        ..close();
      canvas.drawPath(left, earPaint);
      canvas.drawPath(right, earPaint);
    } else {
      canvas.drawCircle(Offset(s * 0.31, s * 0.3), s * 0.13, face);
      canvas.drawCircle(Offset(s * 0.69, s * 0.3), s * 0.13, face);
    }
    canvas.drawCircle(Offset(s * 0.5, s * 0.5), s * 0.31, face);
    canvas.drawCircle(Offset(s * 0.4, s * 0.47), s * 0.032, feature);
    canvas.drawCircle(Offset(s * 0.6, s * 0.47), s * 0.032, feature);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(s * 0.5, s * 0.58),
        width: s * 0.22,
        height: s * 0.16,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.78),
    );
    canvas.drawCircle(Offset(s * 0.5, s * 0.55), s * 0.025, feature);
    final smile = Paint()
      ..color = feature.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.014
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(s * 0.46, s * 0.58),
        width: s * 0.08,
        height: s * 0.07,
      ),
      0,
      2.4,
      false,
      smile,
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(s * 0.54, s * 0.58),
        width: s * 0.08,
        height: s * 0.07,
      ),
      0.7,
      2.4,
      false,
      smile,
    );
  }

  Color _skinColor() {
    return switch (preset.kind) {
      CopilotAvatarKind.boy => const Color(0xFFFFD8B5),
      CopilotAvatarKind.girl => const Color(0xFFFFD7C2),
      CopilotAvatarKind.teenBoy => const Color(0xFFFFD1A8),
      CopilotAvatarKind.teenGirl => const Color(0xFFFFD4BA),
      CopilotAvatarKind.youngMan => const Color(0xFFF5C7A5),
      CopilotAvatarKind.youngWoman => const Color(0xFFFFD6C0),
      CopilotAvatarKind.middleMan => const Color(0xFFE8B78F),
      CopilotAvatarKind.youngMom => const Color(0xFFFFD6C0),
      CopilotAvatarKind.animal => const Color(0xFFFFD8B5),
    };
  }

  Color _hairColor() {
    if (preset.kind == CopilotAvatarKind.middleMan) {
      return preset.variant.isEven
          ? const Color(0xFF374151)
          : const Color(0xFF5B4A3A);
    }
    if (_isFeminine) {
      return preset.variant == 3
          ? const Color(0xFF7C3AED)
          : const Color(0xFF4A2D23);
    }
    return preset.variant == 2
        ? const Color(0xFF1F2937)
        : const Color(0xFF6B3F2A);
  }

  Color _outfitColor() {
    return preset.colors.last.withValues(alpha: 0.88);
  }

  double _faceRadius(double s) {
    return switch (preset.kind) {
      CopilotAvatarKind.boy || CopilotAvatarKind.girl => s * 0.25,
      CopilotAvatarKind.middleMan => s * 0.27,
      _ => s * 0.255,
    };
  }

  bool get _isFeminine {
    return switch (preset.kind) {
      CopilotAvatarKind.girl ||
      CopilotAvatarKind.teenGirl ||
      CopilotAvatarKind.youngWoman ||
      CopilotAvatarKind.youngMom => true,
      _ => false,
    };
  }

  @override
  bool shouldRepaint(covariant _CartoonAvatarPainter oldDelegate) {
    return oldDelegate.preset != preset;
  }
}
