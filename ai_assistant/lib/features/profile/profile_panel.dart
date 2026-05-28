import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../auth/auth_provider.dart';
import '../copilot/copilot_settings_page.dart';
import '../settings/settings_page.dart';
import '../settings/theme_settings_page.dart';
import '../tags/tag_manage_page.dart';
import '../help/help_feedback_page.dart';
import 'edit_profile_modal.dart';
import 'password_change_modal.dart';
import 'profile_provider.dart';

class ProfilePanel extends StatefulWidget {
  final VoidCallback onClose;
  const ProfilePanel({super.key, required this.onClose});

  @override
  State<ProfilePanel> createState() => _ProfilePanelState();
}

class _ProfilePanelState extends State<ProfilePanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  static const _avatarColors = [
    [Color(0xFF667EEA), Color(0xFF764BA2)],
    [Color(0xFF0071E3), Color(0xFF00C6FF)],
    [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
    [Color(0xFF34C759), Color(0xFF30D5C8)],
    [Color(0xFFFF9500), Color(0xFFFF5E3A)],
    [Color(0xFFAF52DE), Color(0xFF5856D6)],
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _closePanel() {
    _controller.reverse().then((value) => widget.onClose());
  }

  Widget _buildAvatar(UserProfile profile) {
    if (profile.hasServerAvatar) {
      final avatarUrl = profile.serverAvatarUrl!;
      // 后端返回 data:image/...;base64,... 格式的数据URI
      if (avatarUrl.startsWith('data:')) {
        final base64Str = avatarUrl.split(',').last;
        try {
          final bytes = base64Decode(base64Str);
          return Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border, width: 2),
            ),
            child: ClipOval(
              child: Image.memory(
                bytes,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _buildGradientAvatar(profile),
              ),
            ),
          );
        } catch (_) {
          return _buildGradientAvatar(profile);
        }
      }
      return Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border, width: 2),
        ),
        child: ClipOval(
          child: Image.network(
            avatarUrl,
            width: 80,
            height: 80,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                _buildGradientAvatar(profile),
          ),
        ),
      );
    }
    if (profile.hasCustomAvatar) {
      return Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border, width: 2),
        ),
        child: ClipOval(
          child: Image.file(
            File(profile.avatarPath!),
            width: 80,
            height: 80,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                _buildGradientAvatar(profile),
          ),
        ),
      );
    }
    return _buildGradientAvatar(profile);
  }

  Widget _buildGradientAvatar(UserProfile profile) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors:
              _avatarColors[profile.avatarColorIndex.clamp(
                0,
                _avatarColors.length - 1,
              )],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color:
                _avatarColors[profile.avatarColorIndex.clamp(
                      0,
                      _avatarColors.length - 1,
                    )]
                    .last
                    .withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          profile.avatarLetter,
          style: const TextStyle(
            fontFamily: 'PingFang SC',
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  void _afterClose(VoidCallback action) {
    _controller.reverse().then((_) {
      widget.onClose();
      if (mounted) action();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _closePanel,
      child: Container(
        color: Colors.black.withValues(alpha: 0.4),
        child: Stack(
          children: [
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: GestureDetector(
                onTap: () {},
                child: SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Container(
                      width: 320,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 24,
                            offset: const Offset(-4, 0),
                          ),
                        ],
                      ),
                      child: SafeArea(
                        child: Consumer(
                          builder: (context, ref, child) {
                            final profile = ref.watch(profileProvider);
                            return DefaultTextStyle.merge(
                              style: const TextStyle(
                                decoration: TextDecoration.none,
                              ),
                              child: Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      18,
                                      14,
                                      18,
                                      0,
                                    ),
                                    child: Row(
                                      children: [
                                        const Spacer(),
                                        GestureDetector(
                                          onTap: _closePanel,
                                          child: Container(
                                            width: 30,
                                            height: 30,
                                            decoration: BoxDecoration(
                                              color: AppColors.inputBg,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: AppColors.border,
                                              ),
                                            ),
                                            child: const Icon(
                                              Icons.close_rounded,
                                              size: 17,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  GestureDetector(
                                    onTap: () => _afterClose(
                                      () => showEditProfileModal(context),
                                    ),
                                    child: _buildAvatar(profile),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    profile.name.isEmpty
                                        ? '未设置昵称'
                                        : profile.name,
                                    style: const TextStyle(
                                      fontFamily: 'PingFang SC',
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.text,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    profile.email.isEmpty ? '' : profile.email,
                                    style: const TextStyle(
                                      fontFamily: 'PingFang SC',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w400,
                                      color: AppColors.textTertiary,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                  const SizedBox(height: 22),
                                  Container(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                    ),
                                    height: 1,
                                    color: AppColors.border,
                                  ),
                                  const SizedBox(height: 10),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                    ),
                                    child: Column(
                                      children: [
                                        _MenuItemCard(
                                          icon: Icons.person_outline_rounded,
                                          label: '个人信息',
                                          onTap: () => _afterClose(
                                            () => showEditProfileModal(context),
                                          ),
                                        ),
                                        _MenuItemCard(
                                          icon: Icons.lock_outline_rounded,
                                          label: '修改密码',
                                          onTap: () => _afterClose(
                                            () => showPasswordChangeModal(
                                              context,
                                            ),
                                          ),
                                        ),
                                        _MenuItemCard(
                                          icon: Icons.palette_outlined,
                                          label: '主题设置',
                                          onTap: () => _afterClose(() {
                                            Navigator.of(context).push(
                                              profileSidePageRoute(
                                                const ThemeSettingsPage(),
                                              ),
                                            );
                                          }),
                                        ),
                                        _MenuItemCard(
                                          icon: Icons.auto_awesome_rounded,
                                          label: 'Copilot 设置',
                                          onTap: () => _afterClose(() {
                                            Navigator.of(context).push(
                                              profileSidePageRoute(
                                                const CopilotSettingsPage(),
                                              ),
                                            );
                                          }),
                                        ),
                                        _MenuItemCard(
                                          icon: Icons.storage_outlined,
                                          label: '数据管理',
                                          onTap: () => _afterClose(() {
                                            Navigator.of(context).push(
                                              profileSidePageRoute(
                                                const SettingsPage(),
                                              ),
                                            );
                                          }),
                                        ),
                                        _MenuItemCard(
                                          icon: Icons.sell_outlined,
                                          label: '标签管理',
                                          onTap: () => _afterClose(() {
                                            Navigator.of(context).push(
                                              profileSidePageRoute(
                                                const TagManagePage(),
                                              ),
                                            );
                                          }),
                                        ),
                                        _MenuItemCard(
                                          icon: Icons.help_outline_rounded,
                                          label: '帮助与反馈',
                                          onTap: () => _afterClose(() {
                                            Navigator.of(context).push(
                                              profileSidePageRoute(
                                                const HelpFeedbackPage(),
                                              ),
                                            );
                                          }),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                    ),
                                    height: 1,
                                    color: AppColors.border,
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: 40,
                                      top: 16,
                                    ),
                                    child: GestureDetector(
                                      onTap: () {
                                        _closePanel();
                                        ref
                                            .read(authProvider.notifier)
                                            .logout();
                                      },
                                      child: Container(
                                        height: 40,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 18,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.danger.withValues(
                                            alpha: 0.08,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          border: Border.all(
                                            color: AppColors.danger.withValues(
                                              alpha: 0.14,
                                            ),
                                          ),
                                        ),
                                        child: const Center(
                                          child: Text(
                                            '退出登录',
                                            style: TextStyle(
                                              fontFamily: 'PingFang SC',
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.danger,
                                              decoration: TextDecoration.none,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuItemCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MenuItemCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppColors.inputBg,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(icon, size: 17, color: AppColors.textSecondary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: 'PingFang SC',
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.text,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
