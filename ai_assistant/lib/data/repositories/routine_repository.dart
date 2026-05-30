import 'package:uuid/uuid.dart';
import '../../domain/models/routine.dart' as model;
import '../datasources/local_datasource.dart';

class RoutineRepository {
  final LocalDatasource _datasource;

  RoutineRepository(this._datasource);

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
  }

  Future<void> deleteRoutine(int id) async {
    await _datasource.softDeleteRoutine(id);
  }

  Future<void> updateRoutine(model.Routine routine) async {
    await _datasource.updateRoutine(routine);
  }
}
