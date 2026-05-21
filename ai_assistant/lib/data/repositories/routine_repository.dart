import 'dart:async';
import 'package:uuid/uuid.dart';
import '../../domain/models/routine.dart';
import '../datasources/local_datasource.dart';
import '../../features/sync/sync_engine.dart';

class RoutineRepository {
  final LocalDatasource _datasource;
  final Future<SyncEngine?> Function() _syncEngine;

  RoutineRepository(this._datasource, {Future<SyncEngine?> Function()? syncEngine})
    : _syncEngine = syncEngine ?? (() async => null);

  Future<List<Routine>> getRoutines() async {
    return _datasource.getAllRoutines();
  }

  Future<void> addRoutine(Routine routine) async {
    final withUuid = routine.uuid == null
        ? routine.copyWith(uuid: const Uuid().v4(), version: 1, updatedAt: DateTime.now(), deleted: false)
        : routine;
    await _datasource.insertRoutine(withUuid);
    _trySync();
  }

  Future<void> deleteRoutine(int id) async {
    await _datasource.softDeleteRoutine(id);
    _trySync();
  }

  void _trySync() {
    _syncEngine().then((engine) {
      if (engine != null) engine.sync('todos');
    });
  }
}
