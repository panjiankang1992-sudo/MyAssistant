import 'dart:convert';

import 'package:drift/drift.dart';
import '../../core/database/database.dart';
import '../../domain/models/todo.dart' as model;
import '../../domain/models/routine.dart' as model;
import '../../domain/models/tag.dart' as model_tag;
import '../../domain/models/metadata_option.dart' as model_meta;

class LocalDatasource {
  final AppDatabase _db;

  LocalDatasource(this._db);

  Future<List<model.Todo>> getAllTodos() async {
    final rows = await _db.select(_db.todos).get();
    return rows.map(_mapTodo).toList();
  }

  Future<List<model.Todo>> getTodosByDate(DateTime date) async {
    final dateText =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    final rows = await _db
        .customSelect(
          '''
          SELECT * FROM todos
          WHERE deleted = 0
            AND date(date, 'unixepoch', 'localtime') = ?
          ORDER BY completed ASC, time ASC
          ''',
          variables: [Variable.withString(dateText)],
          readsFrom: {_db.todos},
        )
        .map((row) => _db.todos.map(row.data))
        .get();
    return rows.map(_mapTodo).toList();
  }

  Future<void> insertTodo(model.Todo todo) async {
    await _db
        .into(_db.todos)
        .insertOnConflictUpdate(
          TodosCompanion(
            id: Value(todo.id),
            title: Value(todo.title),
            description: Value(todo.description),
            source: Value(todo.source),
            routineId: Value(todo.routineId),
            type: Value(todo.type),
            tags: Value(encodeTags(todo.tags)),
            action: Value(todo.action),
            time: Value(todo.time),
            date: Value(todo.date),
            completed: Value(todo.completed),
            createdAt: Value(todo.createdAt),
            updatedAt: Value(todo.updatedAt),
            version: Value(todo.version),
            deleted: Value(todo.deleted),
            priority: Value(todo.priority),
          ),
        );
  }

  Future<void> updateTodo(model.Todo todo) async {
    await (_db.update(_db.todos)..where((t) => t.id.equals(todo.id))).write(
      TodosCompanion(
        title: Value(todo.title),
        description: Value(todo.description),
        source: Value(todo.source),
        routineId: Value(todo.routineId),
        type: Value(todo.type),
        tags: Value(encodeTags(todo.tags)),
        action: Value(todo.action),
        time: Value(todo.time),
        date: Value(todo.date),
        completed: Value(todo.completed),
        updatedAt: Value(DateTime.now()),
        version: Value(todo.version),
        deleted: Value(todo.deleted),
        priority: Value(todo.priority),
      ),
    );
  }

  Future<void> softDeleteTodo(String id) async {
    final now = DateTime.now();
    final rows = await (_db.select(
      _db.todos,
    )..where((t) => t.id.equals(id))).get();
    if (rows.isEmpty) return;
    await (_db.update(_db.todos)..where((t) => t.id.equals(id))).write(
      TodosCompanion(
        deleted: const Value(true),
        updatedAt: Value(now),
        version: Value(rows.first.version + 1),
      ),
    );
  }

  Future<void> deleteTodo(String id) async {
    await (_db.delete(_db.todos)..where((t) => t.id.equals(id))).go();
  }

  Future<void> toggleComplete(String id, bool completed) async {
    final rows = await (_db.select(
      _db.todos,
    )..where((t) => t.id.equals(id))).get();
    final nextVersion = rows.isEmpty ? 1 : rows.first.version + 1;
    await (_db.update(_db.todos)..where((t) => t.id.equals(id))).write(
      TodosCompanion(
        completed: Value(completed),
        updatedAt: Value(DateTime.now()),
        version: Value(nextVersion),
      ),
    );
  }

  Future<List<model.Routine>> getAllRoutines() async {
    final rows = await (_db.select(
      _db.routines,
    )..where((r) => r.deleted.equals(false))).get();
    return rows.map(_mapRoutine).toList();
  }

  Future<int> insertRoutine(model.Routine routine) async {
    return _db
        .into(_db.routines)
        .insertOnConflictUpdate(
          RoutinesCompanion(
            uuid: Value(routine.uuid),
            title: Value(routine.title),
            description: Value(routine.description),
            type: Value(routine.type),
            tags: Value(encodeTags(routine.tags)),
            action: Value(routine.action),
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
    final now = DateTime.now();
    final existing = await (_db.select(
      _db.routines,
    )..where((r) => r.id.equals(routine.id))).getSingleOrNull();
    if (existing == null) return;
    await (_db.update(
      _db.routines,
    )..where((r) => r.id.equals(routine.id))).write(
      RoutinesCompanion(
        uuid: Value(routine.uuid ?? existing.uuid),
        title: Value(routine.title),
        description: Value(routine.description),
        type: Value(routine.type),
        tags: Value(encodeTags(routine.tags)),
        action: Value(routine.action),
        time: Value(routine.time),
        repeatRule: Value(routine.repeatRule),
        repeatDays: Value(routine.repeatDays),
        updatedAt: Value(now),
        version: Value(existing.version + 1),
        deleted: Value(routine.deleted),
      ),
    );
  }

  Future<void> softDeleteRoutine(int id) async {
    final now = DateTime.now();
    final rows = await (_db.select(
      _db.routines,
    )..where((r) => r.id.equals(id))).get();
    if (rows.isEmpty) return;
    await (_db.update(_db.routines)..where((r) => r.id.equals(id))).write(
      RoutinesCompanion(
        deleted: const Value(true),
        updatedAt: Value(now),
        version: Value(rows.first.version + 1),
      ),
    );
  }

  Future<void> softDeleteFutureRoutineTodos(
    String routineTitle,
    DateTime cutoff,
  ) async {
    final today = DateTime(cutoff.year, cutoff.month, cutoff.day);
    final tomorrow = today.add(const Duration(days: 1));
    await (_db.update(_db.todos)..where(
          (t) =>
              t.source.equals('routine') &
              t.title.equals(routineTitle) &
              t.date.isBiggerOrEqualValue(tomorrow),
        ))
        .write(
          TodosCompanion(
            deleted: const Value(true),
            updatedAt: Value(DateTime.now()),
          ),
        );

    final todayTodos =
        await (_db.select(_db.todos)..where(
              (t) =>
                  t.source.equals('routine') &
                  t.title.equals(routineTitle) &
                  t.date.equals(today) &
                  t.deleted.equals(false),
            ))
            .get();
    final cutoffMinutes = cutoff.hour * 60 + cutoff.minute;
    for (final row in todayTodos) {
      final parts = row.time.split(':');
      final todoMinutes =
          (int.tryParse(parts.first) ?? 0) * 60 +
          (int.tryParse(parts.elementAt(1)) ?? 0);
      if (todoMinutes > cutoffMinutes) {
        await (_db.update(_db.todos)..where((t) => t.id.equals(row.id))).write(
          TodosCompanion(
            deleted: const Value(true),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }
    }
  }

  Future<void> softDeleteFutureRoutineTodosByRoutineId(
    String routineId,
    DateTime cutoff, {
    String? fallbackTitle,
  }) async {
    final today = DateTime(cutoff.year, cutoff.month, cutoff.day);
    final tomorrow = today.add(const Duration(days: 1));
    Expression<bool> routineFilter($TodosTable t) {
      final byRoutineId = t.routineId.equals(routineId);
      if (fallbackTitle == null || fallbackTitle.isEmpty) return byRoutineId;
      return byRoutineId |
          (t.routineId.isNull() & t.title.equals(fallbackTitle));
    }

    // Delete all routine todos from tomorrow onward
    await (_db.update(_db.todos)..where(
          (t) =>
              t.source.equals('routine') &
              routineFilter(t) &
              t.date.isBiggerOrEqualValue(tomorrow),
        ))
        .write(
          TodosCompanion(
            deleted: const Value(true),
            updatedAt: Value(DateTime.now()),
          ),
        );
    // For today, delete routine todos whose time hasn't arrived yet
    final todayTodos =
        await (_db.select(_db.todos)..where(
              (t) =>
                  t.source.equals('routine') &
                  routineFilter(t) &
                  t.date.equals(today) &
                  t.deleted.equals(false),
            ))
            .get();
    final cutoffMinutes = cutoff.hour * 60 + cutoff.minute;
    for (final row in todayTodos) {
      final parts = row.time.split(':');
      final todoMinutes =
          (int.tryParse(parts.first) ?? 0) * 60 +
          (int.tryParse(parts.elementAt(1)) ?? 0);
      if (todoMinutes > cutoffMinutes) {
        await (_db.update(_db.todos)..where((t) => t.id.equals(row.id))).write(
          TodosCompanion(
            deleted: const Value(true),
            updatedAt: Value(DateTime.now()),
          ),
        );
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
      routineId: row.routineId,
      type: row.type,
      tags: decodeTags(row.tags),
      action: row.action,
      time: row.time,
      date: row.date,
      completed: row.completed,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      version: row.version,
      deleted: row.deleted,
      priority: row.priority,
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
      action: row.action,
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
    final rows = await (_db.select(
      _db.tags,
    )..orderBy([(t) => OrderingTerm.asc(t.sortOrder)])).get();
    return rows
        .map(
          (r) => model_tag.Tag(
            id: r.id,
            name: r.name,
            colorKey: r.colorKey,
            sortOrder: r.sortOrder,
            isPreset: r.isPreset,
            createdAt: r.createdAt,
            updatedAt: r.updatedAt,
          ),
        )
        .toList();
  }

  Future<void> insertTag(model_tag.Tag tag) async {
    await _db
        .into(_db.tags)
        .insertOnConflictUpdate(
          TagsCompanion(
            id: Value(tag.id),
            name: Value(tag.name),
            colorKey: Value(tag.colorKey),
            sortOrder: Value(tag.sortOrder),
            isPreset: Value(tag.isPreset),
            createdAt: Value(tag.createdAt),
            updatedAt: Value(tag.updatedAt),
          ),
        );
  }

  Future<void> updateTag(model_tag.Tag tag) async {
    await (_db.update(_db.tags)..where((t) => t.id.equals(tag.id))).write(
      TagsCompanion(
        name: Value(tag.name),
        colorKey: Value(tag.colorKey),
        sortOrder: Value(tag.sortOrder),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> deleteTag(String id) async {
    await (_db.delete(_db.tags)..where((t) => t.id.equals(id))).go();
  }

  Future<List<model_meta.MetadataOption>> getMetadataOptions({
    String? kind,
  }) async {
    final query = _db.select(_db.metadataOptions)
      ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]);
    if (kind != null) {
      query.where((t) => t.kind.equals(kind));
    }
    final rows = await query.get();
    return rows
        .map(
          (r) => model_meta.MetadataOption(
            id: r.id,
            kind: r.kind,
            value: r.value,
            label: r.label,
            iconKey: r.iconKey,
            colorKey: r.colorKey,
            sortOrder: r.sortOrder,
            isPreset: r.isPreset,
            updatedAt: r.updatedAt,
          ),
        )
        .toList();
  }

  Future<void> upsertMetadataOption(model_meta.MetadataOption option) async {
    await _db
        .into(_db.metadataOptions)
        .insertOnConflictUpdate(
          MetadataOptionsCompanion(
            id: Value(option.id),
            kind: Value(option.kind),
            value: Value(option.value),
            label: Value(option.label),
            iconKey: Value(option.iconKey),
            colorKey: Value(option.colorKey),
            sortOrder: Value(option.sortOrder),
            isPreset: Value(option.isPreset),
            updatedAt: Value(option.updatedAt),
          ),
        );
  }

  static String encodeTags(List<model_tag.Tag> tags) =>
      jsonEncode(tags.map((t) => t.toCompactJson()).toList());

  static List<model_tag.Tag> decodeTagValue(Object? value) {
    if (value == null) return [];
    if (value is String) return decodeTags(value);
    if (value is List) return _decodeTagList(value);
    return [];
  }

  static List<model_tag.Tag> decodeTags(String json) {
    if (json.isEmpty || json == '[]') return [];
    try {
      final list = jsonDecode(json) as List;
      return _decodeTagList(list);
    } catch (_) {
      return [];
    }
  }

  static List<model_tag.Tag> _decodeTagList(List list) {
    return list
        .map((e) {
          if (e is Map<String, dynamic>) {
            return model_tag.Tag.fromCompactJson(e);
          }
          if (e is Map) {
            return model_tag.Tag.fromCompactJson(Map<String, dynamic>.from(e));
          }
          if (e is String) return _tagFromLegacyId(e);
          return null;
        })
        .whereType<model_tag.Tag>()
        .toList();
  }

  static model_tag.Tag _tagFromLegacyId(String id) {
    final now = DateTime.now();
    switch (id) {
      case 'tag-preset-work':
      case 'work':
        return model_tag.Tag(
          id: 'tag-preset-work',
          name: '工作',
          colorKey: 'blue',
          sortOrder: 1,
          isPreset: true,
          createdAt: now,
          updatedAt: now,
        );
      case 'tag-preset-bill':
      case 'bill':
        return model_tag.Tag(
          id: 'tag-preset-bill',
          name: '账单',
          colorKey: 'pink',
          sortOrder: 2,
          isPreset: true,
          createdAt: now,
          updatedAt: now,
        );
      case 'tag-preset-health':
      case 'health':
        return model_tag.Tag(
          id: 'tag-preset-health',
          name: '健康',
          colorKey: 'green',
          sortOrder: 3,
          isPreset: true,
          createdAt: now,
          updatedAt: now,
        );
      case 'tag-preset-personal':
      case 'personal':
      default:
        return model_tag.Tag(
          id: 'tag-preset-personal',
          name: '个人',
          colorKey: 'purple',
          sortOrder: 0,
          isPreset: true,
          createdAt: now,
          updatedAt: now,
        );
    }
  }
}
