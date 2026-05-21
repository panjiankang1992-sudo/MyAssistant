import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/api/password_service.dart';

void showPasswordChangeModal(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (context) => const _PasswordChangeContent(),
  );
}

class _PasswordChangeContent extends StatefulWidget {
  const _PasswordChangeContent();
  @override
  State<_PasswordChangeContent> createState() => _PasswordChangeContentState();
}

class _PasswordChangeContentState extends State<_PasswordChangeContent> {
  final _oldController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;

  @override
  void dispose() {
    _oldController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final result = await PasswordService.changePassword(_oldController.text, _newController.text);
    setState(() => _loading = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message), duration: const Duration(seconds: 2)),
      );
      if (result.success) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(width: 36, height: 5,
                margin: const EdgeInsets.only(top: 8, bottom: 16),
                decoration: BoxDecoration(color: const Color(0xFFD1D1D6), borderRadius: BorderRadius.circular(3)),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text('修改密码', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.text)),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Form(
                key: _formKey,
                child: Column(children: [
                  TextFormField(
                    controller: _oldController, obscureText: true,
                    decoration: _decoration('旧密码'),
                    validator: (v) => (v == null || v.isEmpty) ? '请输入旧密码' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _newController, obscureText: true,
                    decoration: _decoration('新密码（6-20位）'),
                    validator: (v) => (v == null || v.length < 6) ? '密码至少6位' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _confirmController, obscureText: true,
                    decoration: _decoration('确认新密码'),
                    validator: (v) => v != _newController.text ? '两次密码不一致' : null,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(width: double.infinity, height: 48,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary, foregroundColor: Colors.white, elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                      ),
                      child: _loading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('确认修改', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _decoration(String hint) => InputDecoration(
    hintText: hint, filled: true, fillColor: const Color(0xFFF9F9FB),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  );
}
