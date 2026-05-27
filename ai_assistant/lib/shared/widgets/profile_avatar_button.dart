import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/profile/profile_provider.dart';

class ProfileAvatarButton extends ConsumerStatefulWidget {
  final VoidCallback? onTap;

  const ProfileAvatarButton({super.key, this.onTap});

  @override
  ConsumerState<ProfileAvatarButton> createState() =>
      _ProfileAvatarButtonState();
}

class _ProfileAvatarButtonState extends ConsumerState<ProfileAvatarButton> {
  static const _avatarColors = [
    [Color(0xFF667EEA), Color(0xFF764BA2)],
    [Color(0xFF0071E3), Color(0xFF00C6FF)],
    [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
    [Color(0xFF34C759), Color(0xFF30D5C8)],
    [Color(0xFFFF9500), Color(0xFFFF5E3A)],
    [Color(0xFFAF52DE), Color(0xFF5856D6)],
  ];

  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final gradientColors =
        _avatarColors[profile.avatarColorIndex.clamp(
          0,
          _avatarColors.length - 1,
        )];
    final letter = profile.name.isNotEmpty ? profile.name[0] : '?';
    final avatarChild = _avatarChild(
      letter: letter,
      gradientColors: gradientColors,
      serverAvatarUrl: profile.serverAvatarUrl,
      localAvatarPath: profile.avatarPath,
    );

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: avatarChild,
      ),
    );
  }

  Widget _avatarChild({
    required String letter,
    required List<Color> gradientColors,
    required String? serverAvatarUrl,
    required String? localAvatarPath,
  }) {
    if (serverAvatarUrl != null && serverAvatarUrl.isNotEmpty) {
      if (serverAvatarUrl.startsWith('data:')) {
        try {
          final bytes = base64Decode(serverAvatarUrl.split(',').last);
          return ClipOval(
            child: Image.memory(
              bytes,
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  _gradientAvatar(letter, gradientColors),
            ),
          );
        } catch (_) {
          return _gradientAvatar(letter, gradientColors);
        }
      }
      return ClipOval(
        child: Image.network(
          serverAvatarUrl,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _gradientAvatar(letter, gradientColors),
        ),
      );
    }

    if (localAvatarPath != null && localAvatarPath.isNotEmpty) {
      return ClipOval(
        child: Image.file(
          File(localAvatarPath),
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _gradientAvatar(letter, gradientColors),
        ),
      );
    }

    return _gradientAvatar(letter, gradientColors);
  }

  Widget _gradientAvatar(String letter, List<Color> gradientColors) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33764BA2),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          letter,
          style: const TextStyle(
            fontFamily: 'PingFang SC',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
