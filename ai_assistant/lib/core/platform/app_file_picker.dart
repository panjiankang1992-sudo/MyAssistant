import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';

class AppPickedFile {
  final String name;
  final String path;
  final int? size;

  const AppPickedFile({required this.name, required this.path, this.size});
}

class AppFilePicker {
  static const _channel = MethodChannel('my_assistant/file_picker');

  const AppFilePicker._();

  static bool get _isOhos =>
      defaultTargetPlatform.name.toLowerCase() == 'ohos' ||
      Platform.operatingSystem == 'ohos';

  static Future<List<AppPickedFile>> pickImages({
    bool allowMultiple = true,
    int maxSelectNumber = 20,
  }) async {
    if (_isOhos) {
      return _pickOhos(
        'pickImages',
        allowMultiple: allowMultiple,
        maxSelectNumber: maxSelectNumber,
      );
    }
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: allowMultiple,
    );
    return _fromPlatformFiles(result?.files);
  }

  static Future<List<AppPickedFile>> pickFiles({
    bool allowMultiple = true,
    int maxSelectNumber = 20,
  }) async {
    if (_isOhos) {
      return _pickOhos(
        'pickFiles',
        allowMultiple: allowMultiple,
        maxSelectNumber: maxSelectNumber,
      );
    }
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: allowMultiple,
    );
    return _fromPlatformFiles(result?.files);
  }

  static Future<bool> openFile(String path, {String? mimeType}) async {
    final normalizedPath = path.trim();
    if (normalizedPath.isEmpty) return false;
    if (_isOhos) {
      try {
        final opened = await _channel
            .invokeMethod<bool>('openFile', <String, Object?>{
              'path': normalizedPath,
              if (mimeType != null && mimeType.trim().isNotEmpty)
                'mimeType': mimeType.trim(),
            });
        return opened ?? true;
      } on MissingPluginException {
        return false;
      } on PlatformException {
        return false;
      }
    }
    final result = await OpenFilex.open(normalizedPath);
    return result.type == ResultType.done;
  }

  static List<AppPickedFile> _fromPlatformFiles(List<PlatformFile>? files) {
    return (files ?? const <PlatformFile>[])
        .where((file) => file.path != null && file.path!.trim().isNotEmpty)
        .map(
          (file) =>
              AppPickedFile(name: file.name, path: file.path!, size: file.size),
        )
        .toList();
  }

  static Future<List<AppPickedFile>> _pickOhos(
    String method, {
    required bool allowMultiple,
    required int maxSelectNumber,
  }) async {
    final raw = await _channel.invokeListMethod<Object?>(
      method,
      <String, Object?>{'maxSelectNumber': allowMultiple ? maxSelectNumber : 1},
    );
    return (raw ?? const <Object?>[])
        .whereType<Map<Object?, Object?>>()
        .map((item) {
          final path = (item['path'] as String?)?.trim() ?? '';
          final name = (item['name'] as String?)?.trim();
          final size = item['size'];
          if (path.isEmpty) return null;
          return AppPickedFile(
            name: name?.isNotEmpty == true ? name! : path.split('/').last,
            path: path,
            size: size is num ? size.toInt() : null,
          );
        })
        .whereType<AppPickedFile>()
        .toList();
  }
}
