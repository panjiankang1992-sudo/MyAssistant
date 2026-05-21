import 'package:drift/drift.dart';
import '../../core/database/database.dart';
import '../../domain/models/todo.dart' as model;
import '../../domain/models/routine.dart' as model;

class LocalDatasource {
  final AppDatabase _db;

  LocalDatasource(this._db);

  Future<List<model.Todo>> getAllTodos() async {
    final rows = await _db.select(_db.todos).get();
    return rows.map(_mapTodo).toList();
  }

  Future<List<model.Todo>> getTodosByDate(DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    final rows = await (_db.select(_db.todos)
      ..where((t) => t.date.isBiggerOrEqualValue(start) & t.date.isSmallerThanValue(end))
      ..orderBy([
        // 未完成优先，然后按时间排序
        (t) => OrderingTerm.asc(t.completed),
        (t) => OrderingTerm.asc(t.time),
      ]))
        .get();
    return rows.map(_mapTodo).toList();
  }

  Future<void> insertTodo(model.Todo todo) async {
    await _db.into(_db.todos).insertOnConflictUpdate(
      TodosCompanion(
        id: Value(todo.id),
        title: Value(todo.title),
        description: Value(todo.description),
        source: Value(todo.source),
        type: Value(todo.type),
        time: Value(todo.time),
        date: Value(todo.date),
        completed: Value(todo.completed),
        createdAt: Value(todo.createdAt),
        updatedAt: Value(todo.updatedAt),
        version: Value(todo.version),
        deleted: Value(todo.deleted),
      ),
    );
  }

  Future<void> updateTodo(model.Todo todo) async {
    await (_db.update(_db.todos)
      ..where((t) => t.id.equals(todo.id)))
        .write(TodosCompanion(
          title: Value(todo.title),
          description: Value(todo.description),
          source: Value(todo.source),
          type: Value(todo.type),
          time: Value(todo.time),
          date: Value(todo.date),
          completed: Value(todo.completed),
          updatedAt: Value(DateTime.now()),
          version: Value(todo.version),
          deleted: Value(todo.deleted),
        ));
  }

  Future<void> softDeleteTodo(String id) async {
    await (_db.update(_db.todos)
      ..where((t) => t.id.equals(id)))
        .write(TodosCompanion(
          deleted: const Value(true),
          updatedAt: Value(DateTime.now()),
        ));
  }

  Future<void> deleteTodo(String id) async {
    await (_db.delete(_db.todos)..where((t) => t.id.equals(id))).go();
  }

  Future<void> toggleComplete(String id, bool completed) async {
    await (_db.update(_db.todos)
      ..where((t) => t.id.equals(id)))
        .write(TodosCompanion(
          completed: Value(completed),
          updatedAt: Value(DateTime.now()),
        ));
  }

  Future<List<model.Routine>> getAllRoutines() async {
    final rows = await _db.select(_db.routines).get();
    return rows.map(_mapRoutine).toList();
  }

  Future<int> insertRoutine(model.Routine routine) async {
    return _db.into(_db.routines).insertOnConflictUpdate(
      RoutinesCompanion(
        uuid: Value(routine.uuid),
        title: Value(routine.title),
        description: Value(routine.description),
        type: Value(routine.type),
        time: Value(routine.time),
        repeatRule: Value(routine.repeatRule),
        repeatDays: Value(routine.repeatDays),
        createdAt: Value(routine.createdAt),
        updatedAt: Value(routine.updatedAt),
        version: Value(routine.version),
        deleted: Value(routine.deleted),
      ),
    );
  }

  Future<void> softDeleteRoutine(int id) async {
    await (_db.update(_db.routines)
      ..where((r) => r.id.equals(id)))
        .write(RoutinesCompanion(
          deleted: const Value(true),
          updatedAt: Value(DateTime.now()),
        ));
  }

  Future<void> deleteRoutine(int id) async {
    await (_db.delete(_db.routines)..where((r) => r.id.equals(id))).go();
  }

  model.Todo _mapTodo(Todo row) {
    return model.Todo(
      id: row.id,
      title: row.title,
      description: row.description,
      source: row.source,
      type: row.type,
      time: row.time,
      date: row.date,
      completed: row.completed,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      version: row.version,
      deleted: row.deleted,
    );
  }

  model.Routine _mapRoutine(Routine row) {
    return model.Routine(
      id: row.id,
      uuid: row.uuid,
      title: row.title,
      description: row.description,
      type: row.type,
      time: row.time,
      repeatRule: row.repeatRule,
      repeatDays: row.repeatDays,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      version: row.version,
      deleted: row.deleted,
    );
  }
}
