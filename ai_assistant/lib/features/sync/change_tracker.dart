// @deprecated: Replaced by direct sync trigger in Repository layer.
// Sync is now triggered by TodoRepository and RoutineRepository after each CUD operation.
// This class is retained for backward compatibility but no longer used.

import 'dart:convert';
import '../../data/datasources/local_sync_datasource.dart';

class ChangeTracker {
  final LocalSyncDatasource _datasource;
  ChangeTracker(this._datasource);

  Future<void> recordCreate(String dataId, String dataType, Map<String, dynamic> data, int version) async {
    await _datasource.insertChangeRecord(dataId, dataType, 'create', jsonEncode(data), version);
  }

  Future<void> recordUpdate(String dataId, String dataType, Map<String, dynamic> data, int version) async {
    await _datasource.insertChangeRecord(dataId, dataType, 'update', jsonEncode(data), version);
  }

  Future<void> recordDelete(String dataId, String dataType, int version) async {
    await _datasource.insertChangeRecord(dataId, dataType, 'delete', '', version);
  }
}
