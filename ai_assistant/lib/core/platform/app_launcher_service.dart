import 'dart:convert';

import 'package:flutter/services.dart';

class AppLaunchTarget {
  static const actionPrefix = 'open_app:';

  final String platform;
  final String id;
  final String label;
  final String? subtitle;
  final Map<String, Object?> payload;

  const AppLaunchTarget({
    required this.platform,
    required this.id,
    required this.label,
    this.subtitle,
    this.payload = const {},
  });

  String get actionValue {
    final encoded = base64Url.encode(utf8.encode(jsonEncode(toJson())));
    return '$actionPrefix$encoded';
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'platform': platform,
      'id': id,
      'label': label,
      if (subtitle != null && subtitle!.trim().isNotEmpty)
        'subtitle': subtitle!.trim(),
      ...payload,
    };
  }

  static bool isOpenAppAction(String value) {
    return value == 'open_app' || value.startsWith(actionPrefix);
  }

  static AppLaunchTarget? fromActionValue(String value) {
    if (!value.startsWith(actionPrefix)) return null;
    final encoded = value.substring(actionPrefix.length);
    if (encoded.trim().isEmpty) return null;
    try {
      final decoded = utf8.decode(base64Url.decode(encoded));
      final raw = jsonDecode(decoded);
      if (raw is! Map) return null;
      return fromMap(raw.cast<String, Object?>());
    } catch (_) {
      return null;
    }
  }

  static AppLaunchTarget? fromMap(Map<String, Object?> raw) {
    final platform = (raw['platform'] as String?)?.trim() ?? '';
    final id = (raw['id'] as String?)?.trim() ?? '';
    final label = (raw['label'] as String?)?.trim() ?? '';
    if (platform.isEmpty || id.isEmpty || label.isEmpty) return null;
    final subtitle = (raw['subtitle'] as String?)?.trim();
    return AppLaunchTarget(
      platform: platform,
      id: id,
      label: label,
      subtitle: subtitle?.isEmpty == true ? null : subtitle,
      payload: Map<String, Object?>.from(raw)
        ..remove('platform')
        ..remove('id')
        ..remove('label')
        ..remove('subtitle'),
    );
  }
}

class AppLauncherService {
  static const _channel = MethodChannel('my_assistant/app_launcher');

  const AppLauncherService._();

  static Future<List<AppLaunchTarget>> listApps() async {
    try {
      final raw = await _channel.invokeListMethod<Object?>('listApps');
      final apps = (raw ?? const <Object?>[])
          .whereType<Map<Object?, Object?>>()
          .map((item) {
            return AppLaunchTarget.fromMap(
              item.map((key, value) => MapEntry('$key', value)),
            );
          })
          .whereType<AppLaunchTarget>()
          .toList();
      apps.sort((a, b) => a.label.compareTo(b.label));
      return apps;
    } on MissingPluginException {
      return const [];
    } on PlatformException {
      return const [];
    }
  }

  static Future<bool> openAction(String value) async {
    final target = AppLaunchTarget.fromActionValue(value);
    if (target == null) return false;
    return openApp(target);
  }

  static Future<bool> openApp(AppLaunchTarget target) async {
    try {
      final opened = await _channel.invokeMethod<bool>(
        'openApp',
        target.toJson(),
      );
      return opened ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
