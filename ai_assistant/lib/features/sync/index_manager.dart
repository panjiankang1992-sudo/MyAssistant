import 'dart:convert';
import '../../data/datasources/local_sync_datasource.dart';
import '../../data/datasources/webdav_datasource.dart';
import 'dart:typed_data';

class IndexManager {
  final LocalSyncDatasource _localDs;
  final WebDavDatasource _webdav;
  IndexManager(this._localDs, this._webdav);

  Future<Map<String, List<Map<String, dynamic>>>> compareVersions(String dataType) async {
    final local = await _localDs.getSyncIndexForType(dataType);
    final toUpload = <Map<String, dynamic>>[];
    final toDownload = <Map<String, dynamic>>[];

    try {
      final indexPath = 'MyAssistant/user/$dataType/${dataType}_index.json';
      final indexBytes = await _webdav.getFile(indexPath);
      final cloudIndex = jsonDecode(utf8.decode(indexBytes));
      final cloudEntries = (cloudIndex['entries'] as List?) ?? [];

      for (final localEntry in local) {
        final cloud = cloudEntries.where((e) => e['id'] == localEntry.dataId).firstOrNull;
        if (cloud == null) {
          toUpload.add({'id': localEntry.dataId, 'localVersion': localEntry.localVersion, 'cloudVersion': 0});
        } else if ((cloud['version'] as int) > localEntry.cloudVersion) {
          toDownload.add({'id': localEntry.dataId, 'cloudVersion': cloud['version']});
        } else if (localEntry.localVersion > (cloud['version'] as int)) {
          toUpload.add({'id': localEntry.dataId, 'localVersion': localEntry.localVersion, 'cloudVersion': cloud['version']});
        }
      }
    } catch (_) {}

    return {'toUpload': toUpload, 'toDownload': toDownload};
  }

  Future<void> updateIndex(String dataType) async {
    final entries = await _localDs.getSyncIndexForType(dataType);
    final index = {
      'type': dataType,
      'updatedAt': DateTime.now().toIso8601String(),
      'entries': entries.map((e) => {'id': e.dataId, 'version': e.localVersion, 'updatedAt': e.updatedAt.toIso8601String()}).toList(),
    };
    final path = 'MyAssistant/user/$dataType/${dataType}_index.json';
    await _webdav.putFile(path, Uint8List.fromList(utf8.encode(jsonEncode(index))));
  }
}
