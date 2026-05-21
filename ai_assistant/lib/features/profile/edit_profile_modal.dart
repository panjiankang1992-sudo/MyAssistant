import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/theme/app_theme.dart';
import 'profile_provider.dart';

void showEditProfileModal(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (context) => const _EditProfileContent(),
  );
}

class _EditProfileContent extends ConsumerStatefulWidget {
  const _EditProfileContent();
  @override
  ConsumerState<_EditProfileContent> createState() => _EditProfileContentState();
}

class _EditProfileContentState extends ConsumerState<_EditProfileContent> {
  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  final _formKey = GlobalKey<FormState>();

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

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    ref.read(profileProvider.notifier).updateProfile(
      name: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
    );
    Navigator.of(context).pop();
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      ref.read(profileProvider.notifier).setAvatarPath(result.files.single.path!);
    }
  }

  Widget _avatarWidget(UserProfile p) {
    if (p.hasServerAvatar) {
      final url = p.serverAvatarUrl!;
      if (url.startsWith('data:')) {
        final base64Str = url.split(',').last;
        try {
          final bytes = base64Decode(base64Str);
          return ClipOval(
            child: Image.memory(bytes, width: 72, height: 72, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _gradientAvatar(p)),
          );
        } catch (_) {
          return _gradientAvatar(p);
        }
      }
      return ClipOval(
        child: Image.network(url, width: 72, height: 72, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _gradientAvatar(p)),
      );
    }
    if (p.hasCustomAvatar) {
      return ClipOval(
        child: Image.file(File(p.avatarPath!), width: 72, height: 72, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _gradientAvatar(p)),
      );
    }
    return _gradientAvatar(p);
  }

  Widget _gradientAvatar(UserProfile p) {
    final colors = _avatarColors[p.avatarColorIndex.clamp(0, _avatarColors.length - 1)];
    return Container(
      width: 72, height: 72,
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight)),
      child: Center(child: Text(p.avatarLetter, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: Colors.white))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(height: 8),
              Center(child: Container(width: 36, height: 5, decoration: BoxDecoration(color: const Color(0xFFD1D1D6), borderRadius: BorderRadius.circular(3)))),
              const SizedBox(height: 16),
              const Text('个人信息', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Form(
                  key: _formKey,
                  child: Column(children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: Consumer(builder: (_, ref, __) => _avatarWidget(ref.watch(profileProvider))),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(16)),
                        child: const Text('选择图片', style: TextStyle(fontSize: 12, color: AppColors.primary)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _field('姓名', _nameCtrl, '请输入姓名', validator: (v) => (v == null || v.trim().isEmpty) ? '不能为空' : null),
                    const SizedBox(height: 14),
                    _field('邮箱', _emailCtrl, '请输入邮箱', keyboardType: TextInputType.emailAddress, validator: (v) {
                      if (v == null || v.trim().isEmpty) return '不能为空';
                      if (!v.contains('@')) return '格式不正确';
                      return null;
                    }),
                    const SizedBox(height: 14),
                    _field('手机号', _phoneCtrl, '请输入手机号', keyboardType: TextInputType.phone),
                    const SizedBox(height: 28),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(foregroundColor: AppColors.text, side: const BorderSide(color: AppColors.border), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)), padding: const EdgeInsets.symmetric(vertical: 14)),
                          child: const Text('取消'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _save,
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)), padding: const EdgeInsets.symmetric(vertical: 14)),
                          child: const Text('保存'),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 24),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, String hint, {TextInputType? keyboardType, String? Function(String?)? validator}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
      const SizedBox(height: 6),
      TextFormField(
        controller: ctrl, keyboardType: keyboardType, validator: validator,
        decoration: InputDecoration(
          hintText: hint, filled: true, fillColor: const Color(0xFFF9F9FB),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    ]);
  }
}
