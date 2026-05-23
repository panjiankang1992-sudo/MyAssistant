import 'dart:convert';

import 'package:drift/drift.dart';
import '../../core/database/database.dart';
import '../../domain/models/todo.dart' as model;
import '../../domain/models/routine.dart' as model;
import '../../domain/models/tag.dart' as model_tag;

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
      ..where((t) => t.date.isBiggerOrEqualValue(start) & t.date.isSmallerThanValue(end) & t.deleted.equals(false))
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
        tags: Value(encodeTags(todo.tags)),
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
          tags: Value(encodeTags(todo.tags)),
          time: Value(todo.time),
          date: Value(todo.date),
          completed: Value(todo.completed),
          updatedAt: Value(DateTime.now()),
          version: Value(todo.version),
          deleted: Value(todo.deleted),
        ));
  }

  Future<void> softDeleteTodo(String id) async {
    final now = DateTime.now();
    final rows = await (_db.select(_db.todos)..where((t) => t.id.equals(id))).get();
    if (rows.isEmpty) return;
    await (_db.update(_db.todos)
      ..where((t) => t.id.equals(id)))
        .write(TodosCompanion(
          deleted: const Value(true),
          updatedAt: Value(now),
          version: Value(rows.first.version + 1),
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
    final rows = await (_db.select(_db.routines)
      ..where((r) => r.deleted.equals(false)))
        .get();
    return rows.map(_mapRoutine).toList();
  }

  Future<int> insertRoutine(model.Routine routine) async {
    return _db.into(_db.routines).insertOnConflictUpdate(
      RoutinesCompanion(
        uuid: Value(routine.uuid),
        title: Value(routine.title),
        description: Value(routine.description),
        type: Value(routine.type),
        tags: Value(encodeTags(routine.tags)),
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

  Future<void> updateRoutine(model.Routine routine) async {
    await _db.into(_db.routines).insertOnConflictUpdate(
      RoutinesCompanion(
        uuid: Value(routine.uuid ?? ''),
        title: Value(routine.title),
        description: Value(routine.description),
        type: Value(routine.type),
        tags: Value(encodeTags(routine.tags)),
        time: Value(routine.time),
        repeatRule: Value(routine.repeatRule),
        repeatDays: Value(routine.repeatDays),
        updatedAt: Value(DateTime.now()),
        version: Value(routine.version + 1),
        deleted: Value(routine.deleted),
      ),
    );
  }

  Future<void> softDeleteRoutine(int id) async {
    final now = DateTime.now();
    final rows = await (_db.select(_db.routines)..where((r) => r.id.equals(id))).get();
    if (rows.isEmpty) return;
    await (_db.update(_db.routines)
      ..where((r) => r.id.equals(id)))
        .write(RoutinesCompanion(
          deleted: const Value(true),
          updatedAt: Value(now),
          version: Value(rows.first.version + 1),
        ));
  }

  Future<void> softDeleteFutureRoutineTodos(String routineTitle, DateTime cutoff) async {
    final today = DateTime(cutoff.year, cutoff.month, cutoff.day);
    final tomorrow = today.add(const Duration(days: 1));
    // Delete all routine todos from tomorrow onward
    await (_db.update(_db.todos)
      ..where((t) => t.source.equals('routine') & t.title.equals(routineTitle) & t.date.isBiggerOrEqualValue(tomorrow)))
        .write(TodosCompanion(
          deleted: const Value(true),
          updatedAt: Value(DateTime.now()),
        ));
    // For today, delete routine todos whose time hasn't arrived yet
    final todayTodos = await (_db.select(_db.todos)
      ..where((t) => t.source.equals('routine') & t.title.equals(routineTitle) & t.date.equals(today) & t.deleted.equals(false)))
        .get();
    final cutoffMinutes = cutoff.hour * 60 + cutoff.minute;
    for (final row in todayTodos) {
      final parts = row.time.split(':');
      final todoMinutes = (int.tryParse(parts.first) ?? 0) * 60 + (int.tryParse(parts.elementAt(1)) ?? 0);
      if (todoMinutes > cutoffMinutes) {
        await (_db.update(_db.todos)..where((t) => t.id.equals(row.id)))
            .write(TodosCompanion(deleted: const Value(true), updatedAt: Value(DateTime.now())));
      }
    }
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
      tags: decodeTags(row.tags),
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
      tags: decodeTags(row.tags),
      time: row.time,
      repeatRule: row.repeatRule,
      repeatDays: row.repeatDays,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      version: row.version,
      deleted: row.deleted,
    );
  }

  // Tag CRUD

  Future<List<model_tag.Tag>> getAllTags() async {
    final rows = await (_db.select(_db.tags)
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
    return rows
        .map((r) => model_tag.Tag(
              id: r.id,
              name: r.name,
              colorKey: r.colorKey,
              sortOrder: r.sortOrder,
              isPreset: r.isPreset,
              createdAt: r.createdAt,
              updatedAt: r.updatedAt,
            ))
        .toList();
  }

  Future<void> insertTag(model_tag.Tag tag) async {
    await _db.into(_db.tags).insertOnConflictUpdate(TagsCompanion(
          id: Value(tag.id),
          name: Value(tag.name),
          colorKey: Value(tag.colorKey),
          sortOrder: Value(tag.sortOrder),
          isPreset: Value(tag.isPreset),
          createdAt: Value(tag.createdAt),
          updatedAt: Value(tag.updatedAt),
        ));
  }

  Future<void> updateTag(model_tag.Tag tag) async {
    await (_db.update(_db.tags)..where((t) => t.id.equals(tag.id))).write(
        TagsCompanion(
          name: Value(tag.name),
          colorKey: Value(tag.colorKey),
          sortOrder: Value(tag.sortOrder),
          updatedAt: Value(DateTime.now()),
        ));
  }

  Future<void> deleteTag(String id) async {
    await (_db.delete(_db.tags)..where((t) => t.id.equals(id))).go();
  }

  static String encodeTags(List<model_tag.Tag> tags) =>
      jsonEncode(tags.map((t) => t.toCompactJson()).toList());

  static List<model_tag.Tag> decodeTags(String json) {
    if (json.isEmpty || json == '[]') return [];
    try {
      final list = jsonDecode(json) as List;
      return list
          .map((e) =>
              model_tag.Tag.fromCompactJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
