import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../auth/auth_provider.dart';
import '../settings/settings_page.dart';
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
    _controller.reverse().then((_) => widget.onClose());
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
            width: 80, height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border, width: 2),
            ),
            child: ClipOval(
              child: Image.memory(bytes, width: 80, height: 80, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildGradientAvatar(profile)),
            ),
          );
        } catch (_) {
          return _buildGradientAvatar(profile);
        }
      }
      return Container(
        width: 80, height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border, width: 2),
        ),
        child: ClipOval(
          child: Image.network(
            avatarUrl,
            width: 80, height: 80, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildGradientAvatar(profile),
          ),
        ),
      );
    }
    if (profile.hasCustomAvatar) {
      return Container(
        width: 80, height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border, width: 2),
        ),
        child: ClipOval(
          child: Image.file(File(profile.avatarPath!), width: 80, height: 80, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildGradientAvatar(profile)),
        ),
      );
    }
    return _buildGradientAvatar(profile);
  }

  Widget _buildGradientAvatar(UserProfile profile) {
    return Container(
      width: 80, height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: _avatarColors[profile.avatarColorIndex.clamp(0, _avatarColors.length - 1)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _avatarColors[profile.avatarColorIndex.clamp(0, _avatarColors.length - 1)].last.withOpacity(0.3),
            blurRadius: 12, offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(profile.avatarLetter, style: const TextStyle(
          fontFamily: 'PingFang SC',
          fontSize: 28, fontWeight: FontWeight.w600, color: Colors.white,
        )),
      ),
    );
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _closePanel,
      child: Container(
        color: Colors.black.withOpacity(0.4),
        child: Stack(
          children: [
            Positioned(
              right: 0, top: 0, bottom: 0,
              child: GestureDetector(
                onTap: () {},
                child: SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Container(
                      width: 300,
                      decoration: BoxDecoration(
                        color: AppColors.scaffoldBg,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 24, offset: const Offset(-4, 0),
                          ),
                        ],
                      ),
                      child: SafeArea(
                        child: Consumer(
                          builder: (context, ref, child) {
                            final profile = ref.watch(profileProvider);
                            return Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      GestureDetector(
                                        onTap: _closePanel,
                                        child: Container(
                                          width: 32, height: 32,
                                          decoration: BoxDecoration(
                                            color: AppColors.chipBg,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.close, size: 18, color: AppColors.textSecondary),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                                GestureDetector(
                                  onTap: () => showEditProfileModal(context),
                                  child: _buildAvatar(profile),
                                ),
                                const SizedBox(height: 14),
                                Text(profile.name.isEmpty ? '未设置昵称' : profile.name,
                                  style: const TextStyle(
                                    fontFamily: 'PingFang SC',
                                    fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.text,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(profile.email.isEmpty ? '' : profile.email,
                                  style: const TextStyle(
                                    fontFamily: 'PingFang SC',
                                    fontSize: 13, fontWeight: FontWeight.w400, color: AppColors.textTertiary,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 16),
                                  height: 0.5, color: AppColors.border,
                                ),
                                const SizedBox(height: 12),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Column(
                                    children: [
                                      _MenuItemCard(icon: Icons.person_outline, label: '个人信息', onTap: () => showEditProfileModal(context)),
                                      const SizedBox(height: 8),
                                      _MenuItemCard(icon: Icons.lock_outline, label: '修改密码', onTap: () {
                                        _closePanel();
                                        showPasswordChangeModal(context);
                                      }),
                                      const SizedBox(height: 8),
                                      _MenuItemCard(icon: Icons.palette_outlined, label: '主题设置', onTap: () => _showToast('功能开发中')),
                                      const SizedBox(height: 8),
                                      _MenuItemCard(icon: Icons.storage_outlined, label: '数据管理', onTap: () {
                                        _closePanel();
                                        Navigator.of(context).push(
                                          MaterialPageRoute(builder: (_) => const SettingsPage()),
                                        );
                                      }),
                                      const SizedBox(height: 8),
                                      _MenuItemCard(icon: Icons.help_outline, label: '帮助与反馈', onTap: () => _showToast('功能开发中')),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 16),
                                  height: 0.5, color: AppColors.border,
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 40, top: 16),
                                  child: GestureDetector(
                                    onTap: () {
                                      _closePanel();
                                      ref.read(authProvider.notifier).logout();
                                    },
                                    child: const Text(
                                      '退出登录',
                                      style: TextStyle(
                                        fontFamily: 'PingFang SC',
                                        fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.danger,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
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
  const _MenuItemCard({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8, offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: const TextStyle(
                fontFamily: 'PingFang SC',
                fontSize: 15, fontWeight: FontWeight.w400, color: AppColors.text,
              )),
            ),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}