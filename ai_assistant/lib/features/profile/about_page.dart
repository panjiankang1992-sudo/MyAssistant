import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/security/keychain_service.dart';
import '../../core/theme/app_theme.dart';
import 'profile_provider.dart';

class AboutPage extends ConsumerStatefulWidget {
  const AboutPage({super.key});

  @override
  ConsumerState<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends ConsumerState<AboutPage> {
  static const _appName = '我的助手';
  static const _version = '0.1.0';
  static const _buildNumber = '1';

  bool _syncLoaded = false;
  bool _webDavConfigured = false;
  String _syncRoot = '';

  @override
  void initState() {
    super.initState();
    _loadSyncState();
  }

  Future<void> _loadSyncState() async {
    final keychain = KeychainService();
    final lastUrl = await keychain.getLastServerUrl();
    var configured = false;
    var root = '';
    if (lastUrl != null && lastUrl.isNotEmpty) {
      final creds = await keychain.getCredentials(lastUrl);
      configured = creds != null;
      root = await keychain.getSyncRootDirectory();
    }
    if (!mounted) return;
    setState(() {
      _webDavConfigured = configured;
      _syncRoot = root.trim();
      _syncLoaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final scheme = Theme.of(context).colorScheme;
    final displayName = profile.name.trim().isEmpty ? '本地用户' : profile.name;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('关于')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 36),
        children: [
          const _HeroHeader(
            appName: _appName,
            version: _version,
            buildNumber: _buildNumber,
          ),
          const SizedBox(height: 22),
          const _SectionHeader(title: '应用信息'),
          const SizedBox(height: 10),
          _InfoPanel(
            children: [
              const _InfoRow(
                icon: Icons.badge_outlined,
                label: '应用名称',
                value: _appName,
              ),
              const _InfoRow(
                icon: Icons.verified_outlined,
                label: '版本',
                value: '$_version ($_buildNumber)',
              ),
              _InfoRow(
                icon: Icons.devices_rounded,
                label: '当前平台',
                value: _platformLabel(),
              ),
              _InfoRow(
                icon: Icons.person_outline_rounded,
                label: '当前用户',
                value: displayName,
              ),
            ],
          ),
          const SizedBox(height: 24),
          const _SectionHeader(title: '核心能力'),
          const SizedBox(height: 10),
          const _ModuleGrid(),
          const SizedBox(height: 24),
          const _SectionHeader(title: '数据与同步'),
          const SizedBox(height: 10),
          _InfoPanel(
            children: [
              const _InfoRow(
                icon: Icons.storage_outlined,
                label: '数据模式',
                value: '本地优先存储，按配置同步到 WebDAV',
              ),
              _InfoRow(
                icon: _webDavConfigured
                    ? Icons.cloud_done_outlined
                    : Icons.cloud_off_outlined,
                label: 'WebDAV',
                value: !_syncLoaded
                    ? '读取中'
                    : (_webDavConfigured ? '已配置' : '未配置'),
              ),
              _InfoRow(
                icon: Icons.folder_outlined,
                label: '同步目录',
                value: !_syncLoaded
                    ? '读取中'
                    : (_syncRoot.isEmpty ? '未选择' : '$_syncRoot/MyAssistant'),
              ),
              const _InfoRow(
                icon: Icons.lock_outline_rounded,
                label: '隐私',
                value: '通知、短信、日历、账单、随手记和 Copilot 数据仅按你的配置处理',
              ),
            ],
          ),
          const SizedBox(height: 24),
          const _SectionHeader(title: '说明'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: scheme.outline.withValues(alpha: 0.42)),
            ),
            child: Text(
              '$_appName 用于整理待办、记账、随手记和智能助手对话。AI 分析会使用你在 Copilot 设置中配置的模型服务；同步会使用你在数据管理中配置的 WebDAV 目录。',
              style: TextStyle(
                height: 1.6,
                fontSize: 14,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _platformLabel() {
    if (Platform.isAndroid) return 'Android';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.operatingSystem == 'ohos') return '鸿蒙 NEXT';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isLinux) return 'Linux';
    return Platform.operatingSystem;
  }
}

class _HeroHeader extends StatelessWidget {
  final String appName;
  final String version;
  final String buildNumber;

  const _HeroHeader({
    required this.appName,
    required this.version,
    required this.buildNumber,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          scheme.primary.withValues(alpha: 0.055),
          scheme.surface,
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.42)),
        boxShadow: AppAnimations.cardShadow(),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              color: scheme.onPrimary,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appName,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'AI 个人助手 · v$version ($buildNumber)',
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: scheme.onSurface,
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  final List<Widget> children;

  const _InfoPanel({required this.children});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.42)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              Divider(
                height: 1,
                indent: 54,
                color: scheme.outline.withValues(alpha: 0.28),
              ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: scheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                height: 1.35,
                fontSize: 13,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModuleGrid extends StatelessWidget {
  const _ModuleGrid();

  static const _items = [
    _AboutModule(Icons.check_circle_outline_rounded, '待办', '日程、消息、例行事项'),
    _AboutModule(Icons.receipt_long_outlined, '记账', '收支记录与分类'),
    _AboutModule(Icons.note_alt_outlined, '随手记', '日记、文档、归档'),
    _AboutModule(Icons.smart_toy_outlined, 'Copilot', '对话、记忆、模型配置'),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 520 ? 1 : 2;
        return GridView.count(
          crossAxisCount: columns,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: columns == 1 ? 4.6 : 2.8,
          children: [for (final item in _items) _ModuleTile(item: item)],
        );
      },
    );
  }
}

class _AboutModule {
  final IconData icon;
  final String title;
  final String subtitle;

  const _AboutModule(this.icon, this.title, this.subtitle);
}

class _ModuleTile extends StatelessWidget {
  final _AboutModule item;

  const _ModuleTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.42)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(item.icon, size: 19, color: scheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
