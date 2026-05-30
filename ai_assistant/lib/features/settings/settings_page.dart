import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/security/keychain_service.dart';
import '../../data/datasources/webdav_datasource.dart';
import '../../shared/widgets/app_controls.dart';
import '../sync/providers/sync_provider.dart';
import '../../core/providers/core_providers.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});
  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _syncing = false;
  String _syncMessage = '';
  String _webdavUrl = '';
  String _webdavUser = '';
  String _webdavRoot = '';
  bool _webdavLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadWebdavInfo();
  }

  Future<void> _loadWebdavInfo() async {
    final keychain = KeychainService();
    final lastUrl = await keychain.getLastServerUrl();
    if (lastUrl != null && lastUrl.isNotEmpty) {
      final creds = await keychain.getCredentials(lastUrl);
      if (creds != null && mounted) {
        final root = await keychain.getSyncRootDirectory();
        setState(() {
          _webdavUrl = lastUrl;
          _webdavUser = creds['username'] ?? '';
          _webdavRoot = root;
          _webdavLoaded = true;
        });
        return;
      }
    }
    if (mounted) {
      setState(() {
        _webdavUrl = '';
        _webdavUser = '';
        _webdavRoot = '';
        _webdavLoaded = false;
      });
    }
  }

  /// 找最近 N 天的待办目录并拉取
  Future<void> _syncWebdav() async {
    if (!_webdavLoaded) {
      setState(() => _syncMessage = '未配置 WebDAV，当前仅使用本地存储');
      return;
    }
    setState(() {
      _syncing = true;
      _syncMessage = '';
    });
    try {
      final result = await ref
          .read(dataSyncServiceProvider)
          .manualSync(full: false);
      if (result == null) {
        setState(() => _syncMessage = '未配置 WebDAV，已跳过同步');
        return;
      }

      setState(
        () => _syncMessage =
            '同步完成：拉取 ${result.pullCount} 条，推送 ${result.pushCount} 条',
      );
    } catch (e) {
      setState(() => _syncMessage = '同步异常: $e');
    } finally {
      setState(() => _syncing = false);
    }
  }

  Future<void> _fullSync() async {
    if (!_webdavLoaded) {
      setState(() => _syncMessage = '未配置 WebDAV，当前仅使用本地存储');
      return;
    }
    setState(() {
      _syncing = true;
      _syncMessage = '';
    });
    try {
      final result = await ref
          .read(dataSyncServiceProvider)
          .manualSync(full: true);
      if (result == null) {
        setState(() => _syncMessage = '未配置 WebDAV，已跳过同步');
        return;
      }
      final msg = StringBuffer();
      msg.writeln('全量同步完成');
      msg.writeln('拉取 ${result.pullCount} 条 | 推送 ${result.pushCount} 条');
      msg.writeln(
        'todos索引=${result.todosIndexCount}条 routines=${result.routinesIndexCount}条',
      );
      setState(() => _syncMessage = msg.toString());
    } catch (e) {
      setState(() => _syncMessage = '同步异常: $e');
    } finally {
      setState(() => _syncing = false);
    }
  }

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 56,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, color: AppColors.text),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _formatSyncTime(DateTime time) {
    return '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} '
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _pendingLabel(String key) {
    return switch (key) {
      'todos' => '待办',
      'routines' => '例行代办',
      'tags' => '标签',
      'metadata_options' => '元数据',
      'sync' => '同步索引',
      _ => key,
    };
  }

  Future<void> _openWebdavEditor() async {
    final keychain = KeychainService();
    final lastUrl = await keychain.getLastServerUrl();
    final creds = lastUrl == null || lastUrl.isEmpty
        ? null
        : await keychain.getCredentials(lastUrl);
    final rootDirectory = await keychain.getSyncRootDirectory();
    if (!mounted) return;
    final result = await Navigator.of(context).push<_WebDavEditResult>(
      _RightSlidePageRoute(
        child: _WebDavConfigPage(
          initialUrl: lastUrl ?? '',
          initialUsername: creds?['username'] ?? '',
          initialPassword: creds?['password'] ?? '',
          initialRootDirectory: rootDirectory,
        ),
      ),
    );
    if (result == null) return;
    ref.invalidate(syncEngineProvider);
    await _loadWebdavInfo();
    if (!mounted) return;
    setState(() => _syncMessage = result.message);
    if (result.runInitialSync && _webdavLoaded) {
      await _syncWebdav();
    }
  }

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(syncNotifierProvider);
    final pendingCountsFuture = ref
        .watch(localSyncDsProvider)
        .getPendingCountsByType();
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('设置'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'WebDAV 云同步',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              '点击同步将拉取云端数据到本地，再推送本地数据到云端（双向同步）。',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),

            // WebDAV 信息卡片
            if (_webdavLoaded) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.inputBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.cloud_outlined,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'WebDAV 配置',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _openWebdavEditor,
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: const Text('修改'),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '已配置',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF2E7D32),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _infoRow('服务器', _webdavUrl),
                    const SizedBox(height: 6),
                    _infoRow('用户名', _webdavUser),
                    const SizedBox(height: 6),
                    _infoRow('目录', _webdavRoot.isEmpty ? '/' : _webdavRoot),
                    const SizedBox(height: 6),
                    _infoRow('密码', '••••••••'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.inputBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 18,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        '未配置 WebDAV，自动同步会保持关闭。',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _openWebdavEditor,
                      child: const Text('去配置'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _syncing ? null : _openWebdavEditor,
                icon: const Icon(Icons.settings_outlined, size: 18),
                label: Text(_webdavLoaded ? '修改 WebDAV' : '配置 WebDAV'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.4),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 同步状态
            FutureBuilder<Map<String, int>>(
              future: pendingCountsFuture,
              builder: (context, snapshot) {
                final counts = snapshot.data ?? const <String, int>{};
                if (counts.isEmpty) return const SizedBox.shrink();
                final labels = counts.entries
                    .where((entry) => entry.value > 0)
                    .map(
                      (entry) => '${_pendingLabel(entry.key)} ${entry.value}',
                    )
                    .join('  ·  ');
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.12),
                      ),
                    ),
                    child: _infoRow('待同步', labels),
                  ),
                );
              },
            ),

            if (syncState.lastSyncTime != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.inputBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          syncState.syncing
                              ? Icons.sync
                              : Icons.check_circle_outline,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          '同步状态',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _infoRow('上次同步', _formatSyncTime(syncState.lastSyncTime!)),
                    const SizedBox(height: 6),
                    _infoRow(
                      '拉取/推送',
                      '↓${syncState.lastPullCount} / ↑${syncState.lastPushCount}',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _syncing || !_webdavLoaded ? null : _syncWebdav,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.primary.withValues(
                    alpha: 0.5,
                  ),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _syncing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(_webdavLoaded ? '增量同步' : '配置 WebDAV 后同步'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _syncing || !_webdavLoaded ? null : _fullSync,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _syncing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    : Text(_webdavLoaded ? '全量同步' : '配置 WebDAV 后全量同步'),
              ),
            ),
            if (_syncMessage.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:
                      _syncMessage.contains('失败') ||
                          _syncMessage.contains('异常') ||
                          _syncMessage.contains('丢失')
                      ? const Color(0xFFFFEBEE)
                      : const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _syncMessage,
                  style: TextStyle(
                    fontSize: 14,
                    color:
                        _syncMessage.contains('失败') ||
                            _syncMessage.contains('异常') ||
                            _syncMessage.contains('丢失')
                        ? const Color(0xFFC62828)
                        : const Color(0xFF2E7D32),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            const Text(
              'MyAssistant v0.1.0',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _WebDavEditResult {
  final String message;
  final bool runInitialSync;

  const _WebDavEditResult(this.message, {this.runInitialSync = false});
}

class _RightSlidePageRoute<T> extends PageRouteBuilder<T> {
  final Widget child;

  _RightSlidePageRoute({required this.child})
    : super(
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (context, animation, secondaryAnimation) => child,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          );
        },
      );
}

class _WebDavConfigPage extends StatefulWidget {
  final String initialUrl;
  final String initialUsername;
  final String initialPassword;
  final String initialRootDirectory;

  const _WebDavConfigPage({
    required this.initialUrl,
    required this.initialUsername,
    required this.initialPassword,
    required this.initialRootDirectory,
  });

  @override
  State<_WebDavConfigPage> createState() => _WebDavConfigPageState();
}

class _WebDavConfigPageState extends State<_WebDavConfigPage> {
  late final TextEditingController _urlController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _rootController;
  bool _saving = false;
  bool _testing = false;
  bool _obscurePassword = true;
  String _message = '';
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.initialUrl);
    _usernameController = TextEditingController(text: widget.initialUsername);
    _passwordController = TextEditingController(text: widget.initialPassword);
    _rootController = TextEditingController(text: widget.initialRootDirectory);
  }

  @override
  void dispose() {
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _rootController.dispose();
    super.dispose();
  }

  String _normalizeUrl(String value) {
    var url = value.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  String _normalizeRoot(String value) {
    var path = value.trim().replaceAll('\\', '/');
    while (path.startsWith('/')) {
      path = path.substring(1);
    }
    while (path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    return path;
  }

  String? _validate() {
    final url = _normalizeUrl(_urlController.text);
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    final root = _normalizeRoot(_rootController.text);
    if (url.isEmpty) return '请填写 WebDAV 服务器地址';
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return '服务器地址格式不正确';
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return '服务器地址需要以 http 或 https 开头';
    }
    if (username.isEmpty) return '请填写用户名';
    if (password.isEmpty) return '请填写密码或授权码';
    if (root.isEmpty) return '请填写同步数据存放目录';
    return null;
  }

  void _showMessage(String message, {bool isError = false}) {
    setState(() {
      _message = message;
      _isError = isError;
    });
  }

  Future<void> _testConnection() async {
    final error = _validate();
    if (error != null) {
      _showMessage(error, isError: true);
      return;
    }
    setState(() {
      _testing = true;
      _message = '';
    });
    try {
      final webdav = WebDavDatasource();
      await webdav.initialize(
        baseUrl: _normalizeUrl(_urlController.text),
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );
      try {
        final root = _normalizeRoot(_rootController.text);
        try {
          await webdav.createDirectory(root);
        } catch (_) {}
        await webdav.exists(root);
      } finally {
        webdav.dispose();
      }
      _showMessage('连接验证通过，可以保存配置');
    } catch (e) {
      _showMessage('连接验证失败: $e', isError: true);
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _save() async {
    final error = _validate();
    if (error != null) {
      _showMessage(error, isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final keychain = KeychainService();
      final oldUrl = widget.initialUrl.trim();
      final nextUrl = _normalizeUrl(_urlController.text);
      if (oldUrl.isNotEmpty && oldUrl != nextUrl) {
        await keychain.deleteCredentials(oldUrl);
      }
      await keychain.saveCredentials(
        nextUrl,
        _usernameController.text.trim(),
        _passwordController.text,
      );
      final root = _normalizeRoot(_rootController.text);
      await keychain.setSyncRootDirectory(root);
      await keychain.setLastServerUrl(nextUrl);
      if (!mounted) return;
      Navigator.of(context).pop(
        const _WebDavEditResult('WebDAV 配置已保存，正在执行首次同步', runInitialSync: true),
      );
    } catch (e) {
      _showMessage('保存失败: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除 WebDAV 配置'),
        content: const Text('清除后自动同步会停止，本地数据不会删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('清除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _saving = true);
    try {
      final keychain = KeychainService();
      final currentUrl = _normalizeUrl(_urlController.text);
      final oldUrl = widget.initialUrl.trim();
      if (oldUrl.isNotEmpty) await keychain.deleteCredentials(oldUrl);
      if (currentUrl.isNotEmpty && currentUrl != oldUrl) {
        await keychain.deleteCredentials(currentUrl);
      }
      await keychain.setSyncRootDirectory('');
      await keychain.setLastServerUrl('');
      if (!mounted) return;
      Navigator.of(
        context,
      ).pop(const _WebDavEditResult('WebDAV 配置已清除，自动同步已关闭'));
    } catch (e) {
      _showMessage('清除失败: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final busy = _saving || _testing;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
              child: Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: busy ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'WebDAV 配置',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: busy ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 120),
                children: [
                  Text(
                    '保存配置后会在指定目录下使用 MyAssistant 数据目录；目录已存在时拉取并合并数据，不存在时由首次同步自动创建。本地表数据变化会自动排队同步，并每 10 分钟检查一次云端更新。',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _urlController,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.next,
                    decoration: appInputDecoration(
                      context: context,
                      label: '服务器地址',
                      hintText: 'https://example.com/dav',
                      suffixIcon: const Icon(Icons.cloud_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _usernameController,
                    textInputAction: TextInputAction.next,
                    decoration: appInputDecoration(
                      context: context,
                      label: '用户名',
                      hintText: 'WebDAV 用户名',
                      suffixIcon: const Icon(Icons.person_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: appInputDecoration(
                      context: context,
                      label: '密码 / 授权码',
                      hintText: 'WebDAV 密码或应用授权码',
                      suffixIcon: IconButton(
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _rootController,
                    textInputAction: TextInputAction.done,
                    decoration: appInputDecoration(
                      context: context,
                      label: '同步目录',
                      hintText: '例如 Documents/AI 或 MyData',
                      suffixIcon: const Icon(Icons.folder_open_rounded),
                    ),
                  ),
                  if (_message.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _isError
                            ? scheme.errorContainer
                            : scheme.primaryContainer.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        _message,
                        style: TextStyle(
                          fontSize: 14,
                          color: _isError
                              ? scheme.onErrorContainer
                              : scheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
              decoration: BoxDecoration(
                color: Color.alphaBlend(
                  scheme.surface.withValues(alpha: 0.86),
                  theme.scaffoldBackgroundColor,
                ),
                border: Border(
                  top: BorderSide(
                    color: scheme.outline.withValues(alpha: 0.12),
                  ),
                ),
              ),
              child: Row(
                children: [
                  if (widget.initialUrl.trim().isNotEmpty) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: busy ? null : _clear,
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: const Text('清除'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: scheme.error,
                          side: BorderSide(
                            color: scheme.error.withValues(alpha: 0.35),
                          ),
                          minimumSize: const Size(0, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: busy ? null : _testConnection,
                      icon: _testing
                          ? const SizedBox(
                              width: 17,
                              height: 17,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.wifi_tethering_rounded),
                      label: const Text('验证'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: busy ? null : _save,
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('保存配置'),
                      style:
                          appControlButtonStyle(
                            background: scheme.primary,
                            foreground: scheme.onPrimary,
                          ).copyWith(
                            minimumSize: const WidgetStatePropertyAll(
                              Size(0, 48),
                            ),
                            fixedSize: const WidgetStatePropertyAll(
                              Size.fromHeight(48),
                            ),
                            shape: WidgetStatePropertyAll(
                              RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
