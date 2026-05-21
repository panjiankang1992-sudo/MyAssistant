import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webdav_plus/webdav_plus.dart';
import '../../core/theme/app_theme.dart';
import '../../core/security/keychain_service.dart';
import '../../data/datasources/webdav_datasource.dart';
import '../../domain/models/todo.dart';
import '../todo/providers/todo_provider.dart';
import '../sync/cloud_path_builder.dart';
import '../sync/providers/sync_provider.dart';

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
  static const _pullDays = 7; // 拉取最近一周 + 未来一周

  Future<void> _syncWebdav() async {
    setState(() { _syncing = true; _syncMessage = ''; });
    try {
      final keychain = KeychainService();
      final lastUrl = await keychain.getLastServerUrl();

      if (lastUrl == null || lastUrl.isEmpty) {
        setState(() => _syncMessage = '未配置 WebDAV，请确保服务器已配置 WebDAV 账号并重新登录');
        return;
      }

      final creds = await keychain.getCredentials(lastUrl);
      if (creds == null) {
        setState(() => _syncMessage = 'WebDAV 凭据丢失，请重新登录');
        return;
      }

      final webdav = WebDavDatasource();
      await webdav.initialize(baseUrl: lastUrl, username: creds['username']!, password: creds['password']!);

      // 1. 拉取：从云端下载待办并合并到本地
      int pulled = await _pullTodosFromWebdav(webdav);

      // 2. 推送：将本地待办上传到云端
      int pushed = await _pushTodosToWebdav(webdav);

      webdav.dispose();

      setState(() => _syncMessage = '同步完成：拉取 $pulled 条，推送 $pushed 条');
      await _loadWebdavInfo(); // 刷新信息
    } catch (e) {
      setState(() => _syncMessage = '同步异常: $e');
    } finally {
      setState(() => _syncing = false);
    }
  }

  /// 从 WebDAV 拉取最近 N 天的待办数据，以 id 去重合并到本地
  Future<int> _pullTodosFromWebdav(WebDavDatasource webdav) async {
    final now = DateTime.now();
    final existingTodos = ref.read(todoNotifierProvider);
    final existingIds = existingTodos.map((t) => t.id).toSet();
    final pathBuilder = CloudPathBuilder(_webdavUser);
    int pulled = 0;

    for (int offset = -_pullDays; offset <= _pullDays; offset++) {
      final date = now.add(Duration(days: offset));
      final y = date.year.toString();
      final ym = '${date.year}${date.month.toString().padLeft(2, '0')}';
      final ymd = '$ym${date.day.toString().padLeft(2, '0')}';
      final dirPath = 'MyAssistant/${pathBuilder.username}/todos/$y/$ym/$ymd';

      List<DavResource> files;
      try {
        files = await webdav.listDirectory(dirPath);
      } catch (_) {
        continue;
      }

      for (final file in files) {
        if (!file.name.endsWith('.json')) continue;
        try {
          final bytes = await webdav.getFile('$dirPath/${file.name}');
          final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
          final id = json['id'] as String;
          if (existingIds.contains(id)) continue;

          final todo = Todo(
            id: id,
            title: json['title'] as String,
            description: json['description'] as String?,
            source: json['source'] as String? ?? 'cloud',
            type: json['type'] as String? ?? 'personal',
            time: json['time'] as String? ?? '09:00',
            date: DateTime.parse(json['date'] as String),
            completed: json['completed'] as bool? ?? false,
            createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'] as String) : now,
            updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt'] as String) : now,
          );

          await ref.read(todoNotifierProvider.notifier).addTodo(todo);
          existingIds.add(id);
          pulled++;
        } catch (_) {}
      }
    }
    return pulled;
  }

  /// 将本地所有待办推送到 WebDAV
  Future<int> _pushTodosToWebdav(WebDavDatasource webdav) async {
    final pathBuilder = CloudPathBuilder(_webdavUser);
    for (final dir in pathBuilder.requiredDirectories) {
      try { await webdav.createDirectory(dir); } catch (_) {}
    }

    final todos = ref.read(todoNotifierProvider);
    int pushed = 0;
    for (final todo in todos) {
      final path = pathBuilder.buildFilePath('todo', todo.date.toIso8601String().split('T').first, todo.id);
      final parentDir = path.substring(0, path.lastIndexOf('/'));
      try { await webdav.createDirectory(parentDir); } catch (_) {}

      try {
        final data = jsonEncode({
          'id': todo.id,
          'title': todo.title,
          'description': todo.description,
          'source': todo.source,
          'type': todo.type,
          'time': todo.time,
          'date': todo.date.toIso8601String(),
          'completed': todo.completed,
          'createdAt': todo.createdAt.toIso8601String(),
          'updatedAt': todo.updatedAt.toIso8601String(),
        });
        await webdav.putFile(path, Uint8List.fromList(utf8.encode(data)));
        pushed++;
      } catch (_) {}
    }
    return pushed;
  }

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 56, child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13, color: AppColors.text), overflow: TextOverflow.ellipsis)),
      ],
    );
  }

  String _formatSyncTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    return '${diff.inDays}天前';
  }

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(syncNotifierProvider);
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(title: const Text('设置'), backgroundColor: Colors.transparent, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('WebDAV 云同步', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('点击同步将拉取云端数据到本地，再推送本地数据到云端（双向同步）。',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
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
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.cloud_outlined, size: 18, color: AppColors.primary),
                  const SizedBox(width: 6),
                  const Text('WebDAV 配置', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(4)),
                    child: const Text('已配置', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF2E7D32))),
                  ),
                ]),
                const SizedBox(height: 10),
                _infoRow('服务器', _webdavUrl),
                const SizedBox(height: 6),
                _infoRow('用户名', _webdavUser),
                const SizedBox(height: 6),
                _infoRow('密码', '••••••••'),
              ]),
            ),
            const SizedBox(height: 16),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFFE082)),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline, size: 18, color: Color(0xFFF57F17)),
                const SizedBox(width: 8),
                const Expanded(child: Text('未配置 WebDAV，请确保服务器已配置并重新登录', style: TextStyle(fontSize: 13, color: Color(0xFF5D4037)))),
              ]),
            ),
            const SizedBox(height: 16),
          ],

          // 同步状态
          if (syncState.lastSyncTime != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.inputBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(syncState.syncing ? Icons.sync : Icons.check_circle_outline, size: 18, color: AppColors.primary),
                  const SizedBox(width: 6),
                  const Text('同步状态', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 10),
                _infoRow('上次同步', _formatSyncTime(syncState.lastSyncTime!)),
                const SizedBox(height: 6),
                _infoRow('拉取/推送', '↓${syncState.lastPullCount} / ↑${syncState.lastPushCount}'),
              ]),
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
                disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _syncing
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('同步'),
            ),
          ),
          if (_syncMessage.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _syncMessage.contains('失败') || _syncMessage.contains('异常') || _syncMessage.contains('未配置') || _syncMessage.contains('丢失')
                  ? const Color(0xFFFFEBEE)
                  : const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_syncMessage, style: TextStyle(
                fontSize: 14,
                color: _syncMessage.contains('失败') || _syncMessage.contains('异常') || _syncMessage.contains('未配置') || _syncMessage.contains('丢失')
                  ? const Color(0xFFC62828)
                  : const Color(0xFF2E7D32),
              )),
            ),
          ],
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),
          const Text('MyAssistant v0.1.0', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        ]),
      ),
    );
  }
}