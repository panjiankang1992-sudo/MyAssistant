import 'package:uuid/uuid.dart';
import '../../domain/models/routine.dart' as model;
import '../datasources/local_datasource.dart';
import '../../features/sync/data_sync_service.dart';

class RoutineRepository {
  final LocalDatasource _datasource;
  final DataSyncService? _syncService;

  RoutineRepository(this._datasource, {DataSyncService? syncService})
    : _syncService = syncService;

  Future<List<model.Routine>> getRoutines() async {
    return _datasource.getAllRoutines();
  }

  Future<void> addRoutine(model.Routine routine) async {
    final withUuid = routine.uuid == null
        ? routine.copyWith(
            uuid: const Uuid().v4(),
            version: 1,
            updatedAt: DateTime.now(),
            deleted: false,
          )
        : routine;
    await _datasource.insertRoutine(withUuid);
    await _markDirty(withUuid, 'upsert');
  }

  Future<void> deleteRoutine(int id) async {
    final routines = await _datasource.getAllRoutines();
    final routine = routines.where((item) => item.id == id).firstOrNull;
    await _datasource.softDeleteRoutine(id);
    await _syncService?.markDirty(
      DataSyncType.routine,
      routine?.uuid ?? id.toString(),
      operation: 'delete',
      version: (routine?.version ?? 0) + 1,
    );
  }

  Future<void> updateRoutine(model.Routine routine) async {
    await _datasource.updateRoutine(routine);
    await _markDirty(
      routine.copyWith(version: routine.version + 1, updatedAt: DateTime.now()),
      'upsert',
    );
  }

  Future<void> _markDirty(model.Routine routine, String operation) async {
    final id = routine.uuid;
    if (id == null || id.isEmpty) return;
    await _syncService?.markDirty(
      DataSyncType.routine,
      id,
      operation: operation,
      version: routine.version,
      payload: {
        'title': routine.title,
        'updatedAt': routine.updatedAt.toIso8601String(),
      },
    );
  }
}
