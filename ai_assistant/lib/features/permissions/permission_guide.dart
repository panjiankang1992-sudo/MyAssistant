import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/storage/app_paths.dart';
import 'permission_authorization_service.dart';

class PermissionGuideStore {
  const PermissionGuideStore();

  Future<File> _file() async {
    final dir = await getAppSupportDirectory();
    final settingsDir = Directory('${dir.path}/settings');
    if (!await settingsDir.exists()) {
      await settingsDir.create(recursive: true);
    }
    return File('${settingsDir.path}/permission_guide.json');
  }

  Future<bool> hasAccepted() async {
    if (PermissionAuthorizationService.requiredPermissionKinds().isEmpty) {
      return true;
    }
    try {
      final file = await _file();
      if (!await file.exists()) return false;
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return false;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return json['accepted'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> accept() async {
    final file = await _file();
    await file.writeAsString(
      jsonEncode({
        'accepted': true,
        'acceptedAt': DateTime.now().toIso8601String(),
        'platform': kIsWeb ? 'web' : Platform.operatingSystem,
      }),
      flush: true,
    );
  }
}

Future<bool> showAppPermissionGuideIfNeeded(BuildContext context) async {
  const store = PermissionGuideStore();
  if (PermissionGuideItem.forCurrentPlatform().isEmpty) return true;
  if (await store.hasAccepted()) return true;
  if (!context.mounted) return false;
  final accepted =
      await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (_) => const _PermissionGuideDialog(),
      ) ??
      false;
  if (accepted) {
    await store.accept();
  }
  return accepted;
}

class _PermissionGuideDialog extends StatelessWidget {
  const _PermissionGuideDialog();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final items = PermissionGuideItem.forCurrentPlatform();
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: scheme.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 28,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(
                        Icons.verified_user_rounded,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '开启必要权限',
                            style: text.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '授权前先说明用途，后续可在系统设置中关闭。',
                            style: text.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        for (final item in items) ...[
                          _PermissionGuideTile(item: item),
                          const SizedBox(height: 10),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.42),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    '这里只展示当前平台实际接入且需要系统授权的能力。点击“开始授权”后，会按上方项目打开对应授权窗口或系统设置页。',
                    style: text.bodyMedium?.copyWith(
                      color: scheme.onSurface,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _GuideButton(
                        label: '稍后',
                        foreground: scheme.onSurface,
                        background: scheme.surfaceContainerHighest,
                        onPressed: () => Navigator.of(context).pop(false),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: _GuideButton(
                        label: '开始授权',
                        icon: Icons.check_rounded,
                        foreground: scheme.onPrimary,
                        background: scheme.primary,
                        onPressed: () => Navigator.of(context).pop(true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PermissionGuideTile extends StatelessWidget {
  final PermissionGuideItem item;

  const _PermissionGuideTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(item.icon, color: item.color, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.description,
                  style: text.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.35,
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

class _GuideButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color foreground;
  final Color background;
  final VoidCallback onPressed;

  const _GuideButton({
    required this.label,
    this.icon,
    required this.foreground,
    required this.background,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 20),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          elevation: 0,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}

class PermissionGuideItem {
  final AppPermissionKind kind;
  final IconData icon;
  final Color color;
  final String title;
  final String description;

  const PermissionGuideItem({
    required this.kind,
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });

  static List<PermissionGuideItem> forCurrentPlatform() {
    return [
      for (final kind
          in PermissionAuthorizationService.requiredPermissionKinds())
        _byKind[kind]!,
    ];
  }

  static const _byKind = <AppPermissionKind, PermissionGuideItem>{
    AppPermissionKind.calendar: PermissionGuideItem(
      kind: AppPermissionKind.calendar,
      icon: Icons.calendar_month_rounded,
      color: Color(0xFF7C3AED),
      title: '日历读取',
      description: '读取系统日历和日程，自动生成来源为“日历”的代办。',
    ),
    AppPermissionKind.reminders: PermissionGuideItem(
      kind: AppPermissionKind.reminders,
      icon: Icons.task_alt_rounded,
      color: Color(0xFF2563EB),
      title: '提醒事项读取',
      description: '读取 macOS 提醒事项，在应用中合并展示为代办。',
    ),
    AppPermissionKind.sms: PermissionGuideItem(
      kind: AppPermissionKind.sms,
      icon: Icons.sms_rounded,
      color: Color(0xFF0F9F8F),
      title: '短信读取',
      description: '识别取件码、缴费和出行等常见短信，必要时调用 AI 分析生成代办。',
    ),
    AppPermissionKind.notifications: PermissionGuideItem(
      kind: AppPermissionKind.notifications,
      icon: Icons.notifications_active_rounded,
      color: Color(0xFFFF8A00),
      title: '系统通知',
      description: '用于代办到期提醒，授权后会通过当前设备系统通知弹出。',
    ),
    AppPermissionKind.exactAlarm: PermissionGuideItem(
      kind: AppPermissionKind.exactAlarm,
      icon: Icons.alarm_on_rounded,
      color: Color(0xFFE11D48),
      title: '精准提醒',
      description: 'Android 用于尽量准时触发代办提醒；不授权时会降级为普通系统提醒。',
    ),
    AppPermissionKind.voice: PermissionGuideItem(
      kind: AppPermissionKind.voice,
      icon: Icons.mic_rounded,
      color: Color(0xFF6366F1),
      title: '语音输入',
      description: '用于长按新增或输入区域时，将语音识别为待办、账单或随手记内容。',
    ),
  };
}
