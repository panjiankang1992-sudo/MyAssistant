import 'dart:io';

import 'package:flutter/services.dart';

enum AppPermissionKind {
  calendar('calendar'),
  reminders('reminders'),
  sms('sms'),
  notifications('notifications'),
  exactAlarm('exact_alarm'),
  voice('voice');

  final String channelValue;

  const AppPermissionKind(this.channelValue);
}

class PermissionAuthorizationService {
  static const _channel = MethodChannel('my_assistant/permissions');

  const PermissionAuthorizationService();

  static List<AppPermissionKind> requiredPermissionKinds() {
    if (Platform.isAndroid) {
      return const [
        AppPermissionKind.calendar,
        AppPermissionKind.sms,
        AppPermissionKind.notifications,
        AppPermissionKind.exactAlarm,
        AppPermissionKind.voice,
      ];
    }
    if (Platform.isMacOS) {
      return const [
        AppPermissionKind.calendar,
        AppPermissionKind.reminders,
        AppPermissionKind.notifications,
        AppPermissionKind.voice,
      ];
    }
    if (Platform.operatingSystem == 'ohos') {
      return const [AppPermissionKind.notifications];
    }
    return const [];
  }

  Future<bool> openPlatformAuthorization() async {
    var opened = false;
    for (final kind in requiredPermissionKinds()) {
      opened = await openPermission(kind) || opened;
    }
    return opened;
  }

  Future<bool> openPermission(AppPermissionKind kind) async {
    try {
      final opened = await _channel.invokeMethod<bool>(
        'openPermissionSettings',
        {'target': kind.channelValue},
      );
      return opened ?? true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
