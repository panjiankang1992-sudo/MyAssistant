import 'package:drift/drift.dart';
import '../../core/database/database.dart';

class PendingSyncTask {
  final int id;
  final String syncIndexId;
  final String dataId;
  final String localTable;
  final String? cloudPath;
  final String operationType;
  final bool isCompleted;
  final String status;
  final String? error;
  final DateTime updatedAt;

  const PendingSyncTask({
    required this.id,
    required this.syncIndexId,
    required this.dataId,
    required this.localTable,
    required this.cloudPath,
    required this.operationType,
    required this.isCompleted,
    required this.status,
    required this.error,
    required this.updatedAt,
  });
}

class LocalSyncDatasource {
  final AppDatabase _db;
  LocalSyncDatasource(this._db);

  Future<T> runMuted<T>(Future<T> Function() action) async {
    await setMuted(true);
    try {
      return await action();
    } finally {
      await setMuted(false);
    }
  }

  Future<void> setMuted(bool muted) async {
    final value = muted ? 1 : 0;
    await _db.customStatement(
      'INSERT INTO sync_control (id, muted, updated_at) '
      'VALUES (\'default\', ?, CAST(strftime(\'%s\', \'now\') AS INTEGER)) '
      'ON CONFLICT(id) DO UPDATE SET '
      'muted = excluded.muted, updated_at = excluded.updated_at',
      [value],
    );
  }

  Future<void> enqueueUpload(
    String dataId,
    String localTable, {
    String? cloudPath,
    String? syncIndexId,
  }) async {
    await _db.customStatement(
      '''
      INSERT INTO sync_data (
        sync_index_id,
        data_id,
        local_table,
        cloud_path,
        operation_type,
        is_completed,
        status,
        updated_at
      )
      VALUES (?, ?, ?, ?, 'upload', 0, 'pending', CAST(strftime('%s', 'now') AS INTEGER))
      ''',
      [syncIndexId ?? '$localTable:$dataId', dataId, localTable, cloudPath],
    );
  }

  Future<void> enqueueDownload({
    required String syncIndexId,
    required String dataId,
    required String localTable,
    required String cloudPath,
  }) async {
    await _db.customStatement(
      '''
      INSERT INTO sync_data (
        sync_index_id,
        data_id,
        local_table,
        cloud_path,
        operation_type,
        is_completed,
        status,
        updated_at
      )
      SELECT ?, ?, ?, ?, 'download', 0, 'pending', CAST(strftime('%s', 'now') AS INTEGER)
      WHERE NOT EXISTS (
        SELECT 1 FROM sync_data
        WHERE sync_index_id = ?
          AND operation_type = 'download'
          AND is_completed = 0
      )
      ''',
      [syncIndexId, dataId, localTable, cloudPath, syncIndexId],
    );
  }

  Future<List<PendingSyncTask>> getPendingSyncTasks({
    String? operationType,
  }) async {
    final where = StringBuffer('is_completed = 0');
    final variables = <Variable>[];
    if (operationType != null) {
      where.write(' AND operation_type = ?');
      variables.add(Variable.withString(operationType));
    }
    final rows = await _db
        .customSelect(
          '''
          SELECT
            id,
            sync_index_id,
            data_id,
            local_table,
            cloud_path,
            operation_type,
            is_completed,
            status,
            error,
            updated_at
          FROM sync_data
          WHERE $where
          ORDER BY id ASC
          ''',
          variables: variables,
          readsFrom: {_db.syncData},
        )
        .get();
    return rows.map(_mapPendingTask).toList();
  }

  Stream<int> watchPendingTaskCount() {
    return _db
        .customSelect(
          'SELECT COUNT(*) AS c FROM sync_data WHERE is_completed = 0',
          readsFrom: {_db.syncData},
        )
        .watch()
        .map((rows) => rows.first.read<int>('c'));
  }

  Future<bool> hasPendingTasks() async {
    final rows = await _db
        .customSelect(
          'SELECT COUNT(*) AS c FROM sync_data WHERE is_completed = 0',
          readsFrom: {_db.syncData},
        )
        .get();
    return rows.first.read<int>('c') > 0;
  }

  Future<void> markTaskCompleted(int id, {String? cloudPath}) async {
    await _db.customStatement(
      '''
      UPDATE sync_data
      SET is_completed = 1,
          status = 'completed',
          cloud_path = COALESCE(?, cloud_path),
          error = NULL,
          updated_at = CAST(strftime('%s', 'now') AS INTEGER)
      WHERE id = ?
      ''',
      [cloudPath, id],
    );
  }

  Future<void> markTaskError(int id, String error) async {
    await _db.customStatement(
      '''
      UPDATE sync_data
      SET status = 'error',
          error = ?,
          updated_at = CAST(strftime('%s', 'now') AS INTEGER)
      WHERE id = ?
      ''',
      [error, id],
    );
  }

  Future<void> markCompletedForOperation(String operationType) async {
    await _db.customStatement(
      '''
      UPDATE sync_data
      SET is_completed = 1,
          status = 'completed',
          error = NULL,
          updated_at = CAST(strftime('%s', 'now') AS INTEGER)
      WHERE operation_type = ? AND is_completed = 0
      ''',
      [operationType],
    );
  }

  Future<Map<String, int>> getPendingCountsByType() async {
    final rows = await _db
        .customSelect(
          '''
          SELECT local_table, COUNT(*) AS c
          FROM sync_data
          WHERE is_completed = 0
          GROUP BY local_table
          ''',
          readsFrom: {_db.syncData},
        )
        .get();
    return {
      for (final row in rows)
        row.read<String>('local_table'): row.read<int>('c'),
    };
  }

  Future<void> upsertSyncFile(
    String cloudPath,
    String module,
    String indexName,
    DateTime updatedAt, {
    String lastModifiedDevice = 'cloud',
  }) async {
    await _db
        .into(_db.syncFiles)
        .insertOnConflictUpdate(
          SyncFilesCompanion(
            cloudPath: Value(cloudPath),
            module: Value(module),
            indexName: Value(indexName),
            lastModifiedDevice: Value(lastModifiedDevice),
            updatedAt: Value(updatedAt),
          ),
        );
  }

  Future<List<SyncFile>> getSyncFiles() async {
    return _db.select(_db.syncFiles).get();
  }

  Future<void> upsertSyncIndex(
    String dataId,
    String dataType,
    int localVersion,
    int cloudVersion,
    String status, {
    String? syncIndexPath,
    String? cloudPath,
    String lastModifiedDevice = 'local',
    DateTime? cloudUpdatedAt,
    bool isDeleted = false,
  }) async {
    await _db
        .into(_db.syncIndex)
        .insertOnConflictUpdate(
          SyncIndexCompanion(
            dataId: Value(dataId),
            dataType: Value(dataType),
            localVersion: Value(localVersion),
            cloudVersion: Value(cloudVersion),
            syncStatus: Value(status),
            updatedAt: Value(DateTime.now()),
            syncIndexPath: Value(syncIndexPath),
            cloudPath: Value(cloudPath),
            lastModifiedDevice: Value(lastModifiedDevice),
            cloudUpdatedAt: Value(cloudUpdatedAt),
            isDeleted: Value(isDeleted),
          ),
        );
  }

  Future<List<SyncIndexData>> getSyncIndexForType(String dataType) async {
    return (_db.select(
      _db.syncIndex,
    )..where((t) => t.dataType.equals(dataType))).get();
  }

  Future<SyncIndexData?> getSyncIndex(String dataId, String dataType) async {
    return (_db.select(_db.syncIndex)
          ..where((t) => t.dataId.equals(dataId) & t.dataType.equals(dataType)))
        .getSingleOrNull();
  }

  PendingSyncTask _mapPendingTask(QueryRow row) {
    return PendingSyncTask(
      id: row.read<int>('id'),
      syncIndexId: row.read<String>('sync_index_id'),
      dataId: row.read<String>('data_id'),
      localTable: row.read<String>('local_table'),
      cloudPath: row.readNullable<String>('cloud_path'),
      operationType: row.read<String>('operation_type'),
      isCompleted: row.read<bool>('is_completed'),
      status: row.read<String>('status'),
      error: row.readNullable<String>('error'),
      updatedAt: row.read<DateTime>('updated_at'),
    );
  }
}
