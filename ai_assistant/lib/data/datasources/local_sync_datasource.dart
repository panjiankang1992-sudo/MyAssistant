import 'package:drift/drift.dart';
import '../../core/database/database.dart';

class LocalSyncDatasource {
  final AppDatabase _db;
  LocalSyncDatasource(this._db);

  Future<void> insertChangeRecord(String dataId, String dataType, String operation, String content, int version) async {
    await _db.into(_db.changeRecords).insertOnConflictUpdate(
      ChangeRecordsCompanion(
        dataId: Value(dataId),
        dataType: Value(dataType),
        operation: Value(operation),
        changeContent: Value(content),
        version: Value(version),
        pushed: const Value(false),
        createdAt: Value(DateTime.now()),
      ),
    );
  }

  Future<List<ChangeRecord>> getPendingChanges() async {
    return (_db.select(_db.changeRecords)..where((t) => t.pushed.equals(false))).get();
  }

  Future<void> markPushed(int recordId) async {
    await (_db.update(_db.changeRecords)..where((t) => t.recordId.equals(recordId))).write(
      const ChangeRecordsCompanion(pushed: Value(true)),
    );
  }

  Future<void> deletePushedRecords() async {
    await (_db.delete(_db.changeRecords)..where((t) => t.pushed.equals(true))).go();
  }

  Future<void> upsertSyncIndex(String dataId, String dataType, int localVersion, int cloudVersion, String status) async {
    await _db.into(_db.syncIndex).insertOnConflictUpdate(
      SyncIndexCompanion(
        dataId: Value(dataId),
        dataType: Value(dataType),
        localVersion: Value(localVersion),
        cloudVersion: Value(cloudVersion),
        syncStatus: Value(status),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<List<SyncIndexData>> getSyncIndexForType(String dataType) async {
    return (_db.select(_db.syncIndex)..where((t) => t.dataType.equals(dataType))).get();
  }

  Future<DeviceSyncStateData?> getDeviceState(String deviceId) async {
    return (_db.select(_db.deviceSyncState)..where((t) => t.deviceId.equals(deviceId))).getSingleOrNull();
  }

  Future<void> updateDeviceState(String deviceId, {DateTime? lastSyncTime, int? syncErrors}) async {
    await _db.into(_db.deviceSyncState).insertOnConflictUpdate(
      DeviceSyncStateCompanion(
        deviceId: Value(deviceId),
        lastSyncTime: Value(lastSyncTime ?? DateTime.now()),
        syncErrors: syncErrors != null ? Value(syncErrors) : const Value.absent(),
      ),
    );
  }
}
