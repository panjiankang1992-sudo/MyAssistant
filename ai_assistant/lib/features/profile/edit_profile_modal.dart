import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_controls.dart';
import '../../shared/widgets/edge_swipe_pop.dart';
import '../copilot/copilot_avatar.dart';
import '../copilot/copilot_avatar_picker.dart';
import 'profile_provider.dart';

void showEditProfileModal(BuildContext context) {
  Navigator.of(context).push(profileSidePageRoute(const _EditProfileContent()));
}

PageRoute<T> profileSidePageRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) =>
        EdgeSwipePop(child: page),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final offset = Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
      return SlideTransition(position: offset, child: child);
    },
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 240),
  );
}

class _EditProfileContent extends ConsumerStatefulWidget {
  const _EditProfileContent();
  @override
  ConsumerState<_EditProfileContent> createState() =>
      _EditProfileContentState();
}

class _EditProfileContentState extends ConsumerState<_EditProfileContent> {
  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  String? _saveError;

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
    final p = ref.read(profileProvider);
    _nameCtrl = TextEditingController(text: p.name);
    _emailCtrl = TextEditingController(text: p.email);
    _phoneCtrl = TextEditingController(text: p.phone);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    ref
        .read(profileProvider.notifier)
        .updateProfile(
          name: _nameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
        );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _openAvatarPicker() async {
    final profile = ref.read(profileProvider);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => CopilotAvatarPickerDialog(
        value: _avatarValueOf(profile),
        title: '选择个人头像',
      ),
    );
    if (value == null || value.trim().isEmpty) return;
    ref.read(profileProvider.notifier).setAvatarValue(value);
  }

  String _avatarValueOf(UserProfile p) {
    final saved = p.avatarValue?.trim() ?? '';
    if (saved.isNotEmpty) return saved;
    if ((p.avatarPath ?? '').trim().isNotEmpty) {
      return CopilotAvatarCatalog.fileValue(p.avatarPath!);
    }
    if ((p.avatarEmoji ?? '').trim().isNotEmpty) {
      return 'emoji:${p.avatarEmoji}';
    }
    return CopilotAvatarCatalog.defaultValue;
  }

  Widget _avatarWidget(UserProfile p) {
    final saved = p.avatarValue?.trim() ?? '';
    if (saved.isNotEmpty) {
      return CopilotAvatarView(value: saved, size: 72);
    }
    if (p.hasServerAvatar) {
      final url = p.serverAvatarUrl!;
      if (url.startsWith('data:')) {
        final base64Str = url.split(',').last;
        try {
          final bytes = base64Decode(base64Str);
          return ClipOval(
            child: Image.memory(
              bytes,
              width: 72,
              height: 72,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _gradientAvatar(p),
            ),
          );
        } catch (_) {
          return _gradientAvatar(p);
        }
      }
      return ClipOval(
        child: Image.network(
          url,
          width: 72,
          height: 72,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _gradientAvatar(p),
        ),
      );
    }
    if (p.hasCustomAvatar) {
      return CopilotAvatarView(
        value: CopilotAvatarCatalog.fileValue(p.avatarPath!),
        size: 72,
      );
    }
    return const CopilotAvatarView(
      value: CopilotAvatarCatalog.defaultValue,
      size: 72,
    );
  }

  Widget _gradientAvatar(UserProfile p) {
    final colors =
        _avatarColors[p.avatarColorIndex.clamp(0, _avatarColors.length - 1)];
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          p.avatarLetter,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('个人信息'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            24 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: GestureDetector(
                    onTap: _openAvatarPicker,
                    child: Consumer(
                      builder: (context, ref, child) =>
                          _avatarWidget(ref.watch(profileProvider)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: OutlinedButton.icon(
                    onPressed: _openAvatarPicker,
                    icon: const Icon(Icons.face_retouching_natural, size: 16),
                    label: const Text('更换头像'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.border),
                      backgroundColor: AppColors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      _field(
                        '姓名',
                        _nameCtrl,
                        '请输入姓名',
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? '不能为空' : null,
                      ),
                      const SizedBox(height: 14),
                      _field(
                        '邮箱',
                        _emailCtrl,
                        '请输入邮箱',
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return '不能为空';
                          if (!v.contains('@')) return '格式不正确';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      _field(
                        '手机号',
                        _phoneCtrl,
                        '请输入手机号',
                        keyboardType: TextInputType.phone,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: AppDialogActionButton(
                        label: '取消',
                        onPressed: _saving
                            ? null
                            : () => Navigator.pop(context),
                        tone: AppActionButtonTone.neutral,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppDialogActionButton(
                        label: _saving ? '保存中' : '保存',
                        onPressed: _saving ? null : _save,
                        filled: true,
                      ),
                    ),
                  ],
                ),
                if (_saveError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      _saveError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl,
    String hint, {
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            filled: false,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }
}
