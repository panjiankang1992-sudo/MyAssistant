import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart' as path_provider;

/// Centralized app data paths.
///
/// Flutter OHOS currently does not register path_provider for this project, so
/// direct calls to path_provider throw MissingPluginException on HarmonyOS.
/// Keep the normal plugin paths on supported platforms and fall back to known
/// writable app-sandbox locations when the plugin is unavailable.
class AppPaths {
  const AppPaths._();

  static bool get _isOhos =>
      defaultTargetPlatform.name.toLowerCase() == 'ohos' ||
      Platform.operatingSystem == 'ohos';

  static Future<Directory> supportDirectory() async {
    return _withFallback(
      preferred: path_provider.getApplicationSupportDirectory,
      child: 'support',
    );
  }

  static Future<Directory> documentsDirectory() async {
    return _withFallback(
      preferred: path_provider.getApplicationDocumentsDirectory,
      child: 'documents',
    );
  }

  static Future<Directory> _withFallback({
    required Future<Directory> Function() preferred,
    required String child,
  }) async {
    if (_isOhos) {
      return _fallback(child);
    }
    try {
      final dir = await preferred();
      return _ensure(dir);
    } on MissingPluginException {
      return _fallback(child);
    } on PlatformException {
      return _fallback(child);
    } on UnsupportedError {
      return _fallback(child);
    }
  }

  static Future<Directory> _fallback(String child) async {
    final base = await _firstWritableBase();
    return _ensure(Directory('${base.path}/MyAssistant/$child'));
  }

  static Future<Directory> _firstWritableBase() async {
    final candidates = <String>[
      if ((Platform.environment['MY_ASSISTANT_DATA_DIR'] ?? '').isNotEmpty)
        Platform.environment['MY_ASSISTANT_DATA_DIR']!,
      if (_isOhos) '/data/storage/el2/base/files',
      if (_isOhos) '/data/storage/el2/base',
      '${Directory.systemTemp.path}/my_assistant',
      if ((Platform.environment['HOME'] ?? '').isNotEmpty)
        '${Platform.environment['HOME']}/.my_assistant',
      '${Directory.current.path}/.my_assistant',
    ];

    for (final path in candidates) {
      final dir = Directory(path);
      if (await _canUse(dir)) return dir;
    }
    throw const FileSystemException('No writable app data directory found');
  }

  static Future<bool> _canUse(Directory dir) async {
    try {
      await dir.create(recursive: true);
      final probe = File('${dir.path}/.write_test');
      await probe.writeAsString('ok', flush: true);
      if (await probe.exists()) await probe.delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<Directory> _ensure(Directory dir) async {
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }
}

Future<Directory> getAppSupportDirectory() => AppPaths.supportDirectory();

Future<Directory> getAppDocumentsDirectory() => AppPaths.documentsDirectory();
