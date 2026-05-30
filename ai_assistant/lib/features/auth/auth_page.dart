import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../auth/auth_provider.dart';

class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key});

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  final _accountController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptedTerms = false;
  bool _isRegisterMode = false;
  bool _sendingCode = false;
  String? _termsError;
  String? _codeMessage;
  String? _codeError;

  @override
  void dispose() {
    _accountController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptedTerms) {
      setState(() => _termsError = '请先阅读并勾选用户须知与隐私政策');
      return;
    }
    setState(() => _termsError = null);
    final account = _accountController.text.trim();
    final password = _passwordController.text.trim();
    await ref.read(authProvider.notifier).login(account, password);
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptedTerms) {
      setState(() => _termsError = '请先阅读并勾选用户须知与隐私政策');
      return;
    }
    setState(() => _termsError = null);
    await ref
        .read(authProvider.notifier)
        .register(
          username: _accountController.text.trim(),
          password: _passwordController.text.trim(),
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
          verificationCode: _codeController.text.trim(),
        );
  }

  Future<void> _sendRegisterCode() async {
    final usernameError = _validateUsername(_accountController.text);
    final emailError = _validateEmail(_emailController.text);
    final phoneError = _validatePhone(_phoneController.text);
    if (usernameError != null || emailError != null || phoneError != null) {
      setState(() {
        _codeMessage = null;
        _codeError = usernameError ?? emailError ?? phoneError;
      });
      return;
    }
    setState(() {
      _sendingCode = true;
      _codeMessage = null;
      _codeError = null;
    });
    final ok = await ref
        .read(authProvider.notifier)
        .sendRegisterCode(
          username: _accountController.text.trim(),
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
        );
    if (!mounted) return;
    setState(() {
      _sendingCode = false;
      _codeMessage = ok ? '验证码已发送，请查看邮箱或短信' : null;
      _codeError = ok
          ? null
          : (ref.read(authProvider).error ?? '验证码发送失败，请稍后再试');
    });
  }

  void _toggleMode() {
    setState(() {
      _isRegisterMode = !_isRegisterMode;
      _termsError = null;
      _codeMessage = null;
      _codeError = null;
    });
  }

  String? _validateUsername(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return _isRegisterMode ? '请输入用户名' : '请输入用户名或邮箱';
    if (!_isRegisterMode) return null;
    if (!RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]{2,19}$').hasMatch(text)) {
      return '3-20位，需以字母或下划线开头';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return '请输入邮箱';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) {
      return '邮箱格式不正确';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return '请输入手机号';
    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(text)) return '手机号格式不正确';
    return null;
  }

  Future<void> _showNotice(String title, List<String> paragraphs) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return AlertDialog(
          backgroundColor: scheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
          ),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: paragraphs
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          item,
                          style: TextStyle(
                            height: 1.55,
                            fontSize: 14,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('我知道了'),
            ),
          ],
        );
      },
    );
  }

  void _openUserAgreement() {
    _showNotice('用户须知', const [
      '欢迎使用“我的助手”。本应用用于整理待办、记账、随手记和智能助手对话，帮助你在本地设备和已配置的同步服务之间管理个人数据。',
      '应用可能会在你授权后读取系统日历、通知、短信等内容，并仅用于识别与个人事务相关的信息，例如快递取件、行程提醒、账单事项等。',
      '自动分析生成的内容可能存在偏差，请以原始信息为准。涉及支付、出行、医疗、法律等重要事项时，请再次核对。',
      '你需要妥善保管账号、密码和 WebDAV 配置。若关闭权限或退出登录，对应的自动读取和同步能力会停止。',
    ]);
  }

  void _openPrivacyPolicy() {
    _showNotice('隐私政策', const [
      '我们遵循最小必要原则处理数据。日历、短信、通知等敏感信息仅在你授权后读取，并用于在本机生成待办、账单或分析结果。',
      'WebDAV 同步会把本地待办、记账、随手记、标签等数据同步到你配置的云端目录。请确认 WebDAV 服务由你信任并可控。',
      '当你启用 AI 分析时，相关文本可能会发送给你在 Copilot 设置中配置的模型服务商。请确认模型服务商的隐私条款。',
      '你可以在系统设置中撤回权限，也可以在应用中删除数据、退出登录或调整同步配置。',
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 80),
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Center(
                  child: Text(
                    'M',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'MyAssistant',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'AI 个人助手',
                style: TextStyle(fontSize: 15, color: AppColors.textTertiary),
              ),
              const SizedBox(height: 48),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _accountController,
                      keyboardType: TextInputType.visiblePassword,
                      autocorrect: false,
                      autofillHints: const [AutofillHints.username],
                      textInputAction: TextInputAction.next,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: _isRegisterMode ? '用户名' : '用户名或邮箱',
                        filled: true,
                        fillColor: const Color(0xFFF9F9FB),
                        prefixIcon: const Icon(
                          Icons.person_outline,
                          size: 20,
                          color: AppColors.textTertiary,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                      ),
                      validator: _validateUsername,
                    ),
                    if (_isRegisterMode) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          hintText: '邮箱',
                          filled: true,
                          fillColor: const Color(0xFFF9F9FB),
                          prefixIcon: const Icon(
                            Icons.mail_outline_rounded,
                            size: 20,
                            color: AppColors.textTertiary,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: AppColors.border,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: AppColors.border,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                        ),
                        validator: _validateEmail,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        autofillHints: const [AutofillHints.telephoneNumber],
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          hintText: '手机号',
                          filled: true,
                          fillColor: const Color(0xFFF9F9FB),
                          prefixIcon: const Icon(
                            Icons.phone_iphone_rounded,
                            size: 20,
                            color: AppColors.textTertiary,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: AppColors.border,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: AppColors.border,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                        ),
                        validator: _validatePhone,
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      autofillHints: const [AutofillHints.password],
                      textInputAction: _isRegisterMode
                          ? TextInputAction.next
                          : TextInputAction.done,
                      onFieldSubmitted: (_) {
                        if (!_isRegisterMode) _login();
                      },
                      decoration: InputDecoration(
                        hintText: '密码',
                        filled: true,
                        fillColor: const Color(0xFFF9F9FB),
                        prefixIcon: const Icon(
                          Icons.lock_outline,
                          size: 20,
                          color: AppColors.textTertiary,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            size: 20,
                            color: AppColors.textTertiary,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                      ),
                      validator: (v) {
                        final text = v?.trim() ?? '';
                        if (text.isEmpty) return '请输入密码';
                        if (_isRegisterMode && text.length < 6) {
                          return '密码至少 6 位';
                        }
                        if (_isRegisterMode && text.length > 20) {
                          return '密码最多 20 位';
                        }
                        return null;
                      },
                    ),
                    if (_isRegisterMode) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        autofillHints: const [AutofillHints.newPassword],
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          hintText: '确认密码',
                          filled: true,
                          fillColor: const Color(0xFFF9F9FB),
                          prefixIcon: const Icon(
                            Icons.lock_reset_rounded,
                            size: 20,
                            color: AppColors.textTertiary,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              size: 20,
                              color: AppColors.textTertiary,
                            ),
                            onPressed: () => setState(
                              () => _obscureConfirmPassword =
                                  !_obscureConfirmPassword,
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: AppColors.border,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: AppColors.border,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                        ),
                        validator: (v) {
                          if ((v ?? '').trim().isEmpty) return '请再次输入密码';
                          if (v!.trim() != _passwordController.text.trim()) {
                            return '两次密码不一致';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _codeController,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _register(),
                              decoration: InputDecoration(
                                hintText: '6 位验证码',
                                filled: true,
                                fillColor: const Color(0xFFF9F9FB),
                                prefixIcon: const Icon(
                                  Icons.verified_outlined,
                                  size: 20,
                                  color: AppColors.textTertiary,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: AppColors.border,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: AppColors.border,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: AppColors.primary,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 14,
                                ),
                              ),
                              validator: (v) {
                                if (!RegExp(
                                  r'^\d{6}$',
                                ).hasMatch((v ?? '').trim())) {
                                  return '请输入 6 位验证码';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            height: 50,
                            child: OutlinedButton(
                              onPressed: _sendingCode
                                  ? null
                                  : _sendRegisterCode,
                              child: _sendingCode
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('获取验证码'),
                            ),
                          ),
                        ],
                      ),
                      if (_codeMessage != null || _codeError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _codeError ?? _codeMessage!,
                              style: TextStyle(
                                color: _codeError == null
                                    ? AppColors.success
                                    : AppColors.danger,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                    const SizedBox(height: 24),
                    _TermsConsent(
                      checked: _acceptedTerms,
                      error: _termsError,
                      onChanged: (value) => setState(() {
                        _acceptedTerms = value;
                        if (value) _termsError = null;
                      }),
                      onUserAgreementTap: _openUserAgreement,
                      onPrivacyTap: _openPrivacyPolicy,
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: authState.isLoading
                            ? null
                            : (_isRegisterMode ? _register : _login),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        child: authState.isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _isRegisterMode ? '注册并登录' : '登录',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: authState.isLoading ? null : _toggleMode,
                      child: Text(
                        _isRegisterMode ? '已有账号？返回登录' : '没有账号？立即注册',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (authState.error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          authState.error!,
                          style: const TextStyle(
                            color: AppColors.danger,
                            fontSize: 13,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }
}

class _TermsConsent extends StatelessWidget {
  final bool checked;
  final String? error;
  final ValueChanged<bool> onChanged;
  final VoidCallback onUserAgreementTap;
  final VoidCallback onPrivacyTap;

  const _TermsConsent({
    required this.checked,
    required this.error,
    required this.onChanged,
    required this.onUserAgreementTap,
    required this.onPrivacyTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => onChanged(!checked),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 26,
                  height: 26,
                  child: Checkbox(
                    value: checked,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    side: BorderSide(color: scheme.outline),
                    onChanged: (value) => onChanged(value ?? false),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '我已阅读并同意',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.7,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      _NoticeLink(text: '《用户须知》', onTap: onUserAgreementTap),
                      Text(
                        '和',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.7,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      _NoticeLink(text: '《隐私政策》', onTap: onPrivacyTap),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(left: 34, top: 4),
            child: Text(
              error!,
              style: const TextStyle(fontSize: 12, color: AppColors.danger),
            ),
          ),
      ],
    );
  }
}

class _NoticeLink extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _NoticeLink({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            height: 1.7,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}
