import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/security/keychain_service.dart';
import '../sync/data_sync_service.dart';
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
        setState(() {
          _webdavUrl = lastUrl;
          _webdavUser = creds['username'] ?? '';
          _webdavLoaded = true;
        });
      }
    }
  }

  /// 找最近 N 天的待办目录并拉取
  Future<void> _syncWebdav() async {
    setState(() {
      _syncing = true;
      _syncMessage = '';
    });
    try {
      final result = await ref
          .read(dataSyncServiceProvider)
          .manualSync(full: false);
      if (result == null || result.error == '未配置 WebDAV') {
        setState(() => _syncMessage = '未配置 WebDAV，请确保服务器已配置 WebDAV 账号并重新登录');
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
    setState(() {
      _syncing = true;
      _syncMessage = '';
    });
    try {
      final result = await ref
          .read(dataSyncServiceProvider)
          .manualSync(full: true);
      if (result == null || result.error == '未配置 WebDAV') {
        setState(() => _syncMessage = '未配置 WebDAV');
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

            // WebDAV 信息卡片（只读）
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
                child: const Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 18,
                      color: AppColors.textTertiary,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '未配置 WebDAV，请确保服务器已配置并重新登录',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 同步状态
            FutureBuilder<Map<String, int>>(
              future: pendingCountsFuture,
              builder: (context, snapshot) {
                final counts = snapshot.data ?? const <String, int>{};
                if (counts.isEmpty) return const SizedBox.shrink();
                final labels = DataSyncType.values
                    .where((type) => (counts[type.key] ?? 0) > 0)
                    .map((type) => '${type.label} ${counts[type.key]}')
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
                onPressed: _syncing ? null : _syncWebdav,
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
                    : const Text('增量同步'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _syncing ? null : _fullSync,
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
                    : const Text('全量同步'),
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
                          _syncMessage.contains('未配置') ||
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
                            _syncMessage.contains('未配置') ||
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
