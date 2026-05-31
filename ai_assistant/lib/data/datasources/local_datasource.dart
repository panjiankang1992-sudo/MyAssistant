import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import '../../core/database/database.dart';
import '../../core/storage/key_value_storage.dart';
import '../../domain/models/todo.dart' as model;
import '../../domain/models/routine.dart' as model;
import '../../domain/models/tag.dart' as model_tag;
import '../../domain/models/metadata_option.dart' as model_meta;
import '../../domain/models/app_attachment.dart' as model_attachment;

class SyncEntityRef {
  final String id;
  final String dataType;
  final String localTable;

  const SyncEntityRef({
    required this.id,
    required this.dataType,
    required this.localTable,
  });
}

class LocalDatasource {
  final AppDatabase _db;

  LocalDatasource(this._db);

  AppDatabase get database => _db;

  static bool get _useFileFallback =>
      defaultTargetPlatform.name.toLowerCase() == 'ohos';

  static bool get usesFileFallback => _useFileFallback;

  static const _settingsStoreName = 'app_settings_json';
  static const _metadataOptionsStoreName = 'metadata_options_json';
  static List<model.Todo>? _fallbackTodoCache;
  static List<model_attachment.AppAttachment>? _fallbackAttachmentCache;

  Future<String?> readLocalStoreText(String name) => _readFallbackStore(name);

  Future<void> writeLocalStoreText(String name, String content) {
    return _writeFallbackStore(name, content);
  }

  Future<String?> _readFallbackStore(String name) async {
    try {
      return await AppKeyValueStorage.instance
          .readString(name)
          .timeout(const Duration(seconds: 2), onTimeout: () => null);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeFallbackStore(String name, String content) async {
    await AppKeyValueStorage.instance
        .writeString(name, content)
        .timeout(const Duration(seconds: 2));
  }

  Future<Map<String, dynamic>> _readFallbackJsonMap(String name) async {
    final raw = await _readFallbackStore(name);
    if (raw == null || raw.trim().isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(raw);
    if (decoded is Map) return decoded.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  Future<void> _writeFallbackJsonMap(String name, Map<String, dynamic> value) {
    return _writeFallbackStore(name, jsonEncode(value));
  }

  static String _fallbackSettingKey(String dataType, String id) {
    final raw = '${dataType}__$id';
    return raw.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
  }

  Future<List<model.Todo>> _readFallbackTodos() async {
    final cached = _fallbackTodoCache;
    if (cached != null) return List<model.Todo>.of(cached);
    final raw = await _readFallbackStore('todos_json');
    if (raw == null) {
      return const [];
    }
    if (raw.trim().isEmpty) {
      _fallbackTodoCache = const [];
      return const [];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      _fallbackTodoCache = const [];
      return const [];
    }
    final todos = decoded
        .whereType<Map>()
        .map((item) => _todoFromJson(item.cast<String, dynamic>()))
        .toList();
    _fallbackTodoCache = List<model.Todo>.unmodifiable(todos);
    return todos;
  }

  Future<void> _writeFallbackTodos(List<model.Todo> todos) async {
    _fallbackTodoCache = List<model.Todo>.unmodifiable(todos);
    await _writeFallbackStore(
      'todos_json',
      jsonEncode(todos.map(_todoToJson).toList()),
    );
  }

  Future<List<model_attachment.AppAttachment>>
  _readFallbackAttachments() async {
    final cached = _fallbackAttachmentCache;
    if (cached != null) return List<model_attachment.AppAttachment>.of(cached);
    final raw = await _readFallbackStore('attachments_json');
    if (raw == null || raw.trim().isEmpty) {
      _fallbackAttachmentCache = const [];
      return const [];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      _fallbackAttachmentCache = const [];
      return const [];
    }
    final attachments = decoded
        .whereType<Map>()
        .map(
          (item) => model_attachment.AppAttachment.fromJson(
            item.cast<String, dynamic>(),
          ),
        )
        .toList();
    _fallbackAttachmentCache =
        List<model_attachment.AppAttachment>.unmodifiable(attachments);
    return attachments;
  }

  Future<void> _writeFallbackAttachments(
    List<model_attachment.AppAttachment> attachments,
  ) async {
    _fallbackAttachmentCache =
        List<model_attachment.AppAttachment>.unmodifiable(attachments);
    await _writeFallbackStore(
      'attachments_json',
      jsonEncode(attachments.map((item) => item.toJson()).toList()),
    );
  }

  Map<String, dynamic> _todoToJson(model.Todo todo) {
    return {
      'id': todo.id,
      'title': todo.title,
      'description': todo.description,
      'source': todo.source,
      'routineId': todo.routineId,
      'type': todo.type,
      'tags': encodeTags(todo.tags),
      'action': todo.action,
      'time': todo.time,
      'date': todo.date.toIso8601String(),
      'completed': todo.completed,
      'createdAt': todo.createdAt.toIso8601String(),
      'updatedAt': todo.updatedAt.toIso8601String(),
      'version': todo.version,
      'deleted': todo.deleted,
      'priority': todo.priority,
      'reminderEnabled': todo.reminderEnabled,
      'reminderMinutesBefore': todo.reminderMinutesBefore,
    };
  }

  model.Todo _todoFromJson(Map<String, dynamic> json) {
    DateTime parseDate(Object? value) {
      return DateTime.tryParse(value as String? ?? '') ?? DateTime.now();
    }

    return model.Todo(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      source: json['source'] as String? ?? 'manual',
      routineId: json['routineId'] as String?,
      type: json['type'] as String? ?? 'personal',
      tags: decodeTagValue(json['tags']),
      action: json['action'] as String? ?? 'none',
      time: json['time'] as String? ?? '09:00',
      date: parseDate(json['date']),
      completed: json['completed'] as bool? ?? false,
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
      version: json['version'] as int? ?? 1,
      deleted: json['deleted'] as bool? ?? false,
      priority: json['priority'] as int? ?? 0,
      reminderEnabled: json['reminderEnabled'] as bool? ?? true,
      reminderMinutesBefore: json['reminderMinutesBefore'] as int?,
    );
  }

  List<model_tag.Tag> _presetFallbackTags() {
    final now = DateTime.now();
    const tags = [
      ('tag-preset-personal', '个人', 'purple'),
      ('tag-preset-work', '工作', 'blue'),
      ('tag-preset-traffic', '交通', 'orange'),
      ('tag-preset-life', '生活', 'lime'),
      ('tag-preset-health', '健康', 'green'),
      ('tag-preset-study', '学习', 'indigo'),
      ('tag-preset-tech', '科技', 'sky'),
      ('tag-preset-ai', 'AI', 'blue'),
      ('tag-preset-bill', '账单', 'pink'),
    ];
    return [
      for (var i = 0; i < tags.length; i++)
        model_tag.Tag(
          id: tags[i].$1,
          name: tags[i].$2,
          colorKey: tags[i].$3,
          sortOrder: i,
          isPreset: true,
          createdAt: now,
          updatedAt: now,
        ),
    ];
  }

  Future<bool> _isSyncMuted() async {
    final rows = await _db
        .customSelect(
          'SELECT muted FROM sync_control WHERE id = ?',
          variables: [Variable.withString('default')],
          readsFrom: {_db.syncControl},
        )
        .get();
    if (rows.isEmpty) return false;
    return rows.first.read<bool>('muted');
  }

  Future<void> _setSyncMuted(bool muted) async {
    await _db.customStatement(
      'INSERT INTO sync_control (id, muted, updated_at) '
      'VALUES (\'default\', ?, CAST(strftime(\'%s\', \'now\') AS INTEGER)) '
      'ON CONFLICT(id) DO UPDATE SET '
      'muted = excluded.muted, updated_at = excluded.updated_at',
      [muted ? 1 : 0],
    );
  }

  Future<void> _runWithoutSyncTriggers(Future<void> Function() action) async {
    final wasMuted = await _isSyncMuted();
    if (!wasMuted) await _setSyncMuted(true);
    try {
      await action();
    } finally {
      if (!wasMuted) await _setSyncMuted(false);
    }
  }

  Future<void> _enqueueUploadTask({
    required String dataId,
    required String dataType,
    required String localTable,
    required int localVersion,
    required bool isDeleted,
  }) async {
    const now = 'CAST(strftime(\'%s\', \'now\') AS INTEGER)';
    await _db.customStatement(
      '''
      UPDATE sync_index
      SET local_version = ?,
          updated_at = $now,
          sync_status = 'pending_upload',
          sync_index_path = ?,
          last_modified_device = 'local',
          is_deleted = ?
      WHERE data_id = ? AND data_type = ?
      ''',
      [localVersion, dataType, isDeleted ? 1 : 0, dataId, dataType],
    );
    await _db.customStatement(
      '''
      INSERT INTO sync_index (
        data_id,
        data_type,
        local_version,
        cloud_version,
        updated_at,
        sync_status,
        sync_index_path,
        cloud_path,
        last_modified_device,
        cloud_updated_at,
        is_deleted
      )
      SELECT ?, ?, ?, 0, $now, 'pending_upload', ?, NULL, 'local', NULL, ?
      WHERE NOT EXISTS (
        SELECT 1 FROM sync_index WHERE data_id = ? AND data_type = ?
      )
      ''',
      [
        dataId,
        dataType,
        localVersion,
        dataType,
        isDeleted ? 1 : 0,
        dataId,
        dataType,
      ],
    );
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
      VALUES (?, ?, ?, NULL, 'upload', 0, 'pending', $now)
      ''',
      ['$dataType:$dataId', dataId, localTable],
    );
  }

  Future<List<model.Todo>> getAllTodos() async {
    if (_useFileFallback) return _readFallbackTodos();
    final rows = await _db.select(_db.todos).get();
    return rows.map(_mapTodo).toList();
  }

  Future<model.Todo?> getTodoById(String id) async {
    if (_useFileFallback) {
      final todos = await _readFallbackTodos();
      for (final todo in todos) {
        if (todo.id == id) return todo;
      }
      return null;
    }
    final row = await (_db.select(
      _db.todos,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _mapTodo(row);
  }

  Future<List<model.Todo>> getTodosByDate(DateTime date) async {
    if (_useFileFallback) {
      final todos = await _readFallbackTodos();
      return todos
          .where(
            (todo) =>
                !todo.deleted &&
                todo.date.year == date.year &&
                todo.date.month == date.month &&
                todo.date.day == date.day,
          )
          .toList()
        ..sort((a, b) {
          final completed = a.completed == b.completed
              ? 0
              : (a.completed ? 1 : -1);
          return completed == 0 ? a.time.compareTo(b.time) : completed;
        });
    }
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

  Future<void> insertTodo(model.Todo todo, {bool trackSync = true}) async {
    if (_useFileFallback) {
      final todos = await _readFallbackTodos();
      final index = todos.indexWhere((item) => item.id == todo.id);
      if (index >= 0) {
        todos[index] = todo;
      } else {
        todos.add(todo);
      }
      await _writeFallbackTodos(todos);
      return;
    }
    final wasMuted = await _isSyncMuted();
    await _runWithoutSyncTriggers(() async {
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
              reminderEnabled: Value(todo.reminderEnabled),
              reminderMinutesBefore: Value(todo.reminderMinutesBefore),
            ),
          );
    });
    if (trackSync && !wasMuted) {
      await _enqueueUploadTask(
        dataId: todo.id,
        dataType: 'todo',
        localTable: 'todos',
        localVersion: todo.version,
        isDeleted: todo.deleted,
      );
    }
  }

  Future<void> updateTodo(model.Todo todo) async {
    if (_useFileFallback) {
      final todos = await _readFallbackTodos();
      final index = todos.indexWhere((item) => item.id == todo.id);
      final next = todo.copyWith(updatedAt: DateTime.now());
      if (index >= 0) {
        todos[index] = next;
      } else {
        todos.add(next);
      }
      await _writeFallbackTodos(todos);
      return;
    }
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
        reminderEnabled: Value(todo.reminderEnabled),
        reminderMinutesBefore: Value(todo.reminderMinutesBefore),
      ),
    );
  }

  Future<void> softDeleteTodo(String id) async {
    if (_useFileFallback) {
      final todos = await _readFallbackTodos();
      final index = todos.indexWhere((item) => item.id == id);
      if (index < 0) return;
      todos[index] = todos[index].copyWith(
        deleted: true,
        updatedAt: DateTime.now(),
        version: todos[index].version + 1,
      );
      await _writeFallbackTodos(todos);
      return;
    }
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
    if (_useFileFallback) {
      final todos = await _readFallbackTodos();
      todos.removeWhere((todo) => todo.id == id);
      await _writeFallbackTodos(todos);
      return;
    }
    await (_db.delete(_db.todos)..where((t) => t.id.equals(id))).go();
  }

  Future<void> toggleComplete(String id, bool completed) async {
    if (_useFileFallback) {
      final todos = await _readFallbackTodos();
      final index = todos.indexWhere((item) => item.id == id);
      if (index < 0) return;
      todos[index] = todos[index].copyWith(
        completed: completed,
        updatedAt: DateTime.now(),
        version: todos[index].version + 1,
      );
      await _writeFallbackTodos(todos);
      return;
    }
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

  Future<List<model.Routine>> getAllRoutines({
    bool includeDeleted = false,
  }) async {
    if (_useFileFallback) return const [];
    final query = _db.select(_db.routines);
    if (!includeDeleted) {
      query.where((r) => r.deleted.equals(false));
    }
    final rows = await query.get();
    return rows.map(_mapRoutine).toList();
  }

  Future<model.Routine?> getRoutineByUuid(
    String uuid, {
    bool includeDeleted = false,
  }) async {
    if (_useFileFallback) return null;
    final query = _db.select(_db.routines)..where((r) => r.uuid.equals(uuid));
    if (!includeDeleted) {
      query.where((r) => r.deleted.equals(false));
    }
    final row = await query.getSingleOrNull();
    return row == null ? null : _mapRoutine(row);
  }

  Future<int> insertRoutine(model.Routine routine) async {
    if (_useFileFallback) return 0;
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
    if (_useFileFallback) return;
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
    if (_useFileFallback) return;
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
    if (_useFileFallback) return;
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
    if (_useFileFallback) return;
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
    if (_useFileFallback) return;
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
      reminderEnabled: row.reminderEnabled,
      reminderMinutesBefore: row.reminderMinutesBefore,
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
    if (_useFileFallback) return _presetFallbackTags();
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
    if (_useFileFallback) return;
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
    if (_useFileFallback) return;
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
    if (_useFileFallback) return;
    await (_db.delete(_db.tags)..where((t) => t.id.equals(id))).go();
  }

  Future<List<model_meta.MetadataOption>> getMetadataOptions({
    String? kind,
  }) async {
    if (_useFileFallback) {
      final options = await _readFallbackMetadataOptions();
      final filtered = kind == null
          ? options
          : options.where((option) => option.kind == kind).toList();
      filtered.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return filtered;
    }
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
    if (_useFileFallback) {
      final options = await _readFallbackMetadataOptions();
      final index = options.indexWhere((item) => item.id == option.id);
      if (index >= 0) {
        options[index] = option;
      } else {
        options.add(option);
      }
      await _writeFallbackStore(
        _metadataOptionsStoreName,
        jsonEncode(options.map((item) => item.toJson()).toList()),
      );
      return;
    }
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

  Future<List<model_meta.MetadataOption>> _readFallbackMetadataOptions() async {
    final raw = await _readFallbackStore(_metadataOptionsStoreName);
    if (raw == null || raw.trim().isEmpty) {
      return _presetFallbackMetadataOptions();
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map(
              (item) => model_meta.MetadataOption.fromJson(
                item.cast<String, dynamic>(),
              ),
            )
            .toList();
      }
    } catch (_) {
      // Fall back to presets when old development data is malformed.
    }
    return _presetFallbackMetadataOptions();
  }

  static List<model_meta.MetadataOption> _presetFallbackMetadataOptions() {
    final now = DateTime.fromMillisecondsSinceEpoch(0);
    return [
      model_meta.MetadataOption(
        id: 'source-ai',
        kind: 'source',
        value: 'ai',
        label: 'AI',
        iconKey: 'auto_awesome',
        colorKey: 'blue',
        sortOrder: 0,
        updatedAt: now,
      ),
      model_meta.MetadataOption(
        id: 'source-routine',
        kind: 'source',
        value: 'routine',
        label: '例行',
        iconKey: 'repeat',
        colorKey: 'orange',
        sortOrder: 1,
        updatedAt: now,
      ),
      model_meta.MetadataOption(
        id: 'source-calendar',
        kind: 'source',
        value: 'calendar',
        label: '日历',
        iconKey: 'event',
        colorKey: 'purple',
        sortOrder: 2,
        updatedAt: now,
      ),
      model_meta.MetadataOption(
        id: 'source-message',
        kind: 'source',
        value: 'message',
        label: '消息',
        iconKey: 'message',
        colorKey: 'green',
        sortOrder: 3,
        updatedAt: now,
      ),
      model_meta.MetadataOption(
        id: 'source-sms',
        kind: 'source',
        value: 'sms',
        label: '短信',
        iconKey: 'sms',
        colorKey: 'teal',
        sortOrder: 4,
        updatedAt: now,
      ),
      model_meta.MetadataOption(
        id: 'action-none',
        kind: 'action',
        value: 'none',
        label: '无动作',
        iconKey: 'block',
        colorKey: 'gray',
        sortOrder: 0,
        updatedAt: now,
      ),
      model_meta.MetadataOption(
        id: 'action-bookkeeping',
        kind: 'action',
        value: 'bookkeeping',
        label: '记账',
        iconKey: 'receipt',
        colorKey: 'orange',
        sortOrder: 1,
        updatedAt: now,
      ),
      model_meta.MetadataOption(
        id: 'action-open-app',
        kind: 'action',
        value: 'open_app',
        label: '打开应用',
        iconKey: 'open',
        colorKey: 'blue',
        sortOrder: 2,
        updatedAt: now,
      ),
      model_meta.MetadataOption(
        id: 'action-call',
        kind: 'action',
        value: 'call',
        label: '拨打电话',
        iconKey: 'call',
        colorKey: 'green',
        sortOrder: 3,
        updatedAt: now,
      ),
      model_meta.MetadataOption(
        id: 'action-message',
        kind: 'action',
        value: 'message',
        label: '发消息',
        iconKey: 'message',
        colorKey: 'purple',
        sortOrder: 4,
        updatedAt: now,
      ),
    ];
  }

  Future<List<model_attachment.AppAttachment>> getAllAttachments() async {
    if (_useFileFallback) return _readFallbackAttachments();
    final rows = await _db.select(_db.attachments).get();
    return rows.map(_mapAttachment).toList();
  }

  Future<List<SyncEntityRef>> getAllSyncEntityRefs() async {
    final rows = await _db
        .customSelect(
          '''
          SELECT id, 'bill' AS data_type, 'bills' AS local_table FROM bills
          UNION ALL
          SELECT id, 'category' AS data_type, 'bill_categories' AS local_table
          FROM bill_categories
          UNION ALL
          SELECT
            id,
            CASE
              WHEN archived = 1 THEN 'archive'
              WHEN note_type = 'diary' THEN 'diary'
              ELSE 'note'
            END AS data_type,
            'quick_notes' AS local_table
          FROM quick_notes
          UNION ALL
          SELECT
            id,
            CASE WHEN archived = 1 THEN 'archive_chat' ELSE 'chat' END
              AS data_type,
            'copilot_sessions' AS local_table
          FROM copilot_sessions
          UNION ALL
          SELECT id, data_type, 'app_settings' AS local_table
          FROM app_settings
          ''',
          readsFrom: {
            _db.bills,
            _db.billCategories,
            _db.quickNotes,
            _db.copilotSessions,
            _db.appSettingsRecords,
          },
        )
        .get();
    return rows
        .map(
          (row) => SyncEntityRef(
            id: row.read<String>('id'),
            dataType: row.read<String>('data_type'),
            localTable: row.read<String>('local_table'),
          ),
        )
        .toList();
  }

  Future<model_attachment.AppAttachment?> getAttachmentById(String id) async {
    if (_useFileFallback) {
      final attachments = await _readFallbackAttachments();
      return attachments.where((item) => item.id == id).firstOrNull;
    }
    final row = await (_db.select(
      _db.attachments,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _mapAttachment(row);
  }

  Future<void> upsertAttachment(
    model_attachment.AppAttachment attachment,
  ) async {
    if (attachment.exceedsMaxSize) {
      throw ArgumentError(
        '附件不能超过 ${model_attachment.AppAttachment.maxSizeLabel}',
      );
    }
    if (_useFileFallback) {
      final attachments = await _readFallbackAttachments();
      final next = [
        for (final item in attachments)
          if (item.id == attachment.id) attachment else item,
      ];
      if (!next.any((item) => item.id == attachment.id)) {
        next.add(attachment);
      }
      await _writeFallbackAttachments(next);
      return;
    }
    await _db
        .into(_db.attachments)
        .insertOnConflictUpdate(
          AttachmentsCompanion(
            id: Value(attachment.id),
            ownerType: Value(attachment.ownerType),
            ownerId: Value(attachment.ownerId),
            attachmentType: Value(attachment.attachmentType),
            fileName: Value(attachment.fileName),
            mimeType: Value(attachment.mimeType),
            sizeBytes: Value(attachment.sizeBytes),
            contentBase64: Value(attachment.contentBase64),
            createdAt: Value(attachment.createdAt),
            updatedAt: Value(attachment.updatedAt),
            isDeleted: Value(attachment.isDeleted),
          ),
        );
  }

  model_attachment.AppAttachment _mapAttachment(Attachment row) {
    return model_attachment.AppAttachment(
      id: row.id,
      ownerType: row.ownerType,
      ownerId: row.ownerId,
      attachmentType: row.attachmentType,
      fileName: row.fileName,
      mimeType: row.mimeType,
      sizeBytes: row.sizeBytes,
      contentBase64: row.contentBase64,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      isDeleted: row.isDeleted,
    );
  }

  Future<Map<String, dynamic>?> getSyncEntityJson(
    String localTable,
    String dataId, {
    String? dataType,
  }) async {
    switch (localTable) {
      case 'bills':
        final row = await (_db.select(
          _db.bills,
        )..where((t) => t.id.equals(dataId))).getSingleOrNull();
        return row == null
            ? null
            : {
                'id': row.id,
                'kind': row.kind,
                'categoryId': row.categoryId,
                'categoryName': row.categoryName,
                'categoryEmoji': row.categoryEmoji,
                'note': row.note,
                'amount': row.amount,
                'currency': row.currency,
                'cnyAmount': row.cnyAmount,
                'date': row.date.toIso8601String(),
                'aiGenerated': row.aiGenerated,
                'tags': decodeTags(
                  row.tags,
                ).map((tag) => tag.toCompactJson()).toList(),
                'createdAt': row.createdAt.toIso8601String(),
                'updatedAt': row.updatedAt.toIso8601String(),
                'version': row.version,
                'deleted': row.isDeleted,
              };
      case 'bill_categories':
        final row = await (_db.select(
          _db.billCategories,
        )..where((t) => t.id.equals(dataId))).getSingleOrNull();
        return row == null
            ? null
            : {
                'id': row.id,
                'name': row.name,
                'emoji': row.emoji,
                'color': row.color,
                'kind': row.kind,
                'createdAt': row.createdAt.toIso8601String(),
                'updatedAt': row.updatedAt.toIso8601String(),
                'version': row.version,
                'deleted': row.isDeleted,
              };
      case 'quick_notes':
        final row = await (_db.select(
          _db.quickNotes,
        )..where((t) => t.id.equals(dataId))).getSingleOrNull();
        return row == null
            ? null
            : {
                'id': row.id,
                'title': row.title,
                'content': row.content,
                'summary': row.summary,
                'tags': decodeTags(
                  row.tags,
                ).map((tag) => tag.toCompactJson()).toList(),
                'date': row.date.toIso8601String(),
                'createdAt': row.createdAt.toIso8601String(),
                'updatedAt': row.updatedAt.toIso8601String(),
                'archived': row.archived,
                'deleted': row.isDeleted,
                'pinned': row.pinned,
                'analyzed': row.analyzed,
                'isAnalysis': row.isAnalysis,
                'noteType': row.noteType,
                'category': row.category,
                'subcategory': row.subcategory,
                'sourceNoteIds': _decodeStringList(row.sourceNoteIds),
                'attachmentIds': _decodeStringList(row.attachmentIds),
                'version': row.version,
              };
      case 'copilot_sessions':
        final row = await (_db.select(
          _db.copilotSessions,
        )..where((t) => t.id.equals(dataId))).getSingleOrNull();
        return row == null
            ? null
            : {
                'id': row.id,
                'title': row.title,
                'messages': jsonDecode(row.messages),
                'createdAt': row.createdAt.toIso8601String(),
                'updatedAt': row.updatedAt.toIso8601String(),
                'version': row.version,
                'archived': row.archived,
                'deleted': row.isDeleted,
              };
      case 'app_settings':
        final type = dataType ?? 'profile';
        final row =
            await (_db.select(_db.appSettingsRecords)
                  ..where((t) => t.id.equals(dataId) & t.dataType.equals(type)))
                .getSingleOrNull();
        return row == null
            ? null
            : {
                'id': row.id,
                'module': row.module,
                'dataType': row.dataType,
                ...((jsonDecode(row.payloadJson) as Map)
                    .cast<String, dynamic>()),
                'createdAt': row.createdAt.toIso8601String(),
                'updatedAt': row.updatedAt.toIso8601String(),
                'version': row.version,
                'deleted': row.isDeleted,
              };
      default:
        return null;
    }
  }

  Future<void> upsertSyncEntityJson({
    required String dataType,
    required String dataId,
    required Map<String, dynamic> data,
    required int version,
    required bool isDeleted,
    required DateTime updatedAt,
  }) async {
    switch (dataType) {
      case 'bill':
        await _db
            .into(_db.bills)
            .insertOnConflictUpdate(
              BillsCompanion(
                id: Value(dataId),
                kind: Value(data['kind'] as String? ?? 'expense'),
                categoryId: Value(data['categoryId'] as String? ?? 'other'),
                categoryName: Value(data['categoryName'] as String? ?? '其他'),
                categoryEmoji: Value(data['categoryEmoji'] as String? ?? ''),
                note: Value(data['note'] as String? ?? ''),
                amount: Value((data['amount'] as num?)?.toDouble() ?? 0),
                currency: Value(data['currency'] as String? ?? 'CNY'),
                cnyAmount: Value((data['cnyAmount'] as num?)?.toDouble() ?? 0),
                date: Value(_parseDate(data['date']) ?? updatedAt),
                aiGenerated: Value(data['aiGenerated'] as bool? ?? false),
                tags: Value(jsonEncode(data['tags'] ?? const [])),
                createdAt: Value(_parseDate(data['createdAt']) ?? updatedAt),
                updatedAt: Value(updatedAt),
                version: Value(version),
                isDeleted: Value(isDeleted),
              ),
            );
        break;
      case 'category':
        await _db
            .into(_db.billCategories)
            .insertOnConflictUpdate(
              BillCategoriesCompanion(
                id: Value(dataId),
                name: Value(data['name'] as String? ?? '自定义'),
                emoji: Value(data['emoji'] as String? ?? ''),
                color: Value(data['color'] as int? ?? 0xFFEAF5FF),
                kind: Value(data['kind'] as String? ?? 'expense'),
                createdAt: Value(_parseDate(data['createdAt']) ?? updatedAt),
                updatedAt: Value(updatedAt),
                version: Value(version),
                isDeleted: Value(isDeleted),
              ),
            );
        break;
      case 'note':
      case 'diary':
      case 'archive':
        await _db
            .into(_db.quickNotes)
            .insertOnConflictUpdate(
              QuickNotesCompanion(
                id: Value(dataId),
                title: Value(data['title'] as String? ?? ''),
                content: Value(data['content'] as String? ?? ''),
                summary: Value(data['summary'] as String? ?? ''),
                tags: Value(jsonEncode(data['tags'] ?? const [])),
                date: Value(_parseDate(data['date']) ?? updatedAt),
                createdAt: Value(_parseDate(data['createdAt']) ?? updatedAt),
                updatedAt: Value(updatedAt),
                archived: Value(
                  dataType == 'archive' || (data['archived'] as bool? ?? false),
                ),
                pinned: Value(data['pinned'] as bool? ?? false),
                analyzed: Value(data['analyzed'] as bool? ?? false),
                isAnalysis: Value(data['isAnalysis'] as bool? ?? false),
                noteType: Value(
                  dataType == 'diary'
                      ? 'diary'
                      : data['noteType'] as String? ?? 'document',
                ),
                category: Value(data['category'] as String? ?? '未分类'),
                subcategory: Value(data['subcategory'] as String? ?? '未归类'),
                sourceNoteIds: Value(
                  jsonEncode(data['sourceNoteIds'] ?? const []),
                ),
                attachmentIds: Value(
                  jsonEncode(data['attachmentIds'] ?? const []),
                ),
                version: Value(version),
                isDeleted: Value(isDeleted),
              ),
            );
        break;
      case 'chat':
      case 'archive_chat':
        await _db
            .into(_db.copilotSessions)
            .insertOnConflictUpdate(
              CopilotSessionsCompanion(
                id: Value(dataId),
                title: Value(data['title'] as String? ?? '未命名会话'),
                messages: Value(jsonEncode(data['messages'] ?? const [])),
                createdAt: Value(_parseDate(data['createdAt']) ?? updatedAt),
                updatedAt: Value(updatedAt),
                version: Value(version),
                archived: Value(
                  dataType == 'archive_chat' ||
                      (data['archived'] as bool? ?? false),
                ),
                isDeleted: Value(isDeleted),
              ),
            );
        break;
      case 'memory':
      case 'user_profile':
      case 'theme':
      case 'copilot_setting':
      case 'data':
      case 'tags_setting':
      case 'feedback':
        await upsertAppSettingJson(
          module: dataType == 'memory' ? 'copilot' : 'profile',
          dataType: dataType,
          id: dataId,
          payload: data,
          version: version,
          isDeleted: isDeleted,
          updatedAt: updatedAt,
        );
        break;
    }
  }

  Future<Map<String, dynamic>?> getAppSettingJson(
    String dataType,
    String id,
  ) async {
    if (_useFileFallback) {
      final settings = await _readFallbackJsonMap(_settingsStoreName);
      final record = settings[_fallbackSettingKey(dataType, id)];
      if (record is! Map) return null;
      final typed = record.cast<String, dynamic>();
      if (typed['isDeleted'] as bool? ?? false) return null;
      final payload = typed['payload'];
      if (payload is Map) return payload.cast<String, dynamic>();
      return null;
    }
    final row =
        await (_db.select(_db.appSettingsRecords)
              ..where((t) => t.dataType.equals(dataType) & t.id.equals(id)))
            .getSingleOrNull();
    if (row == null || row.isDeleted) return null;
    return (jsonDecode(row.payloadJson) as Map).cast<String, dynamic>();
  }

  Future<void> upsertAppSettingJson({
    required String module,
    required String dataType,
    required String id,
    required Map<String, dynamic> payload,
    int? version,
    bool isDeleted = false,
    DateTime? updatedAt,
  }) async {
    final now = updatedAt ?? DateTime.now();
    if (_useFileFallback) {
      final settings = await _readFallbackJsonMap(_settingsStoreName);
      final key = _fallbackSettingKey(dataType, id);
      final existing = settings[key];
      final existingVersion = existing is Map
          ? (existing['version'] as num?)?.toInt() ?? 0
          : 0;
      settings[key] = {
        'id': id,
        'module': module,
        'dataType': dataType,
        'payload': payload,
        'updatedAt': now.toIso8601String(),
        'version': version ?? existingVersion + 1,
        'isDeleted': isDeleted,
      };
      await _writeFallbackJsonMap(_settingsStoreName, settings);
      return;
    }
    final existing =
        await (_db.select(_db.appSettingsRecords)
              ..where((t) => t.dataType.equals(dataType) & t.id.equals(id)))
            .getSingleOrNull();
    await _db
        .into(_db.appSettingsRecords)
        .insertOnConflictUpdate(
          AppSettingsRecordsCompanion(
            id: Value(id),
            module: Value(module),
            dataType: Value(dataType),
            payloadJson: Value(jsonEncode(payload)),
            createdAt: Value(existing?.createdAt ?? now),
            updatedAt: Value(now),
            version: Value(version ?? ((existing?.version ?? 0) + 1)),
            isDeleted: Value(isDeleted),
          ),
        );
  }

  static DateTime? _parseDate(Object? value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static List<String> _decodeStringList(String value) {
    try {
      return (jsonDecode(value) as List).whereType<String>().toList();
    } catch (_) {
      return const [];
    }
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
      case 'tag-preset-traffic':
      case 'traffic':
        return model_tag.Tag(
          id: 'tag-preset-traffic',
          name: '交通',
          colorKey: 'orange',
          sortOrder: 2,
          isPreset: true,
          createdAt: now,
          updatedAt: now,
        );
      case 'tag-preset-life':
      case 'life':
        return model_tag.Tag(
          id: 'tag-preset-life',
          name: '生活',
          colorKey: 'lime',
          sortOrder: 3,
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
          sortOrder: 8,
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
          sortOrder: 4,
          isPreset: true,
          createdAt: now,
          updatedAt: now,
        );
      case 'tag-preset-study':
      case 'study':
        return model_tag.Tag(
          id: 'tag-preset-study',
          name: '学习',
          colorKey: 'indigo',
          sortOrder: 5,
          isPreset: true,
          createdAt: now,
          updatedAt: now,
        );
      case 'tag-preset-tech':
      case 'tech':
        return model_tag.Tag(
          id: 'tag-preset-tech',
          name: '科技',
          colorKey: 'sky',
          sortOrder: 6,
          isPreset: true,
          createdAt: now,
          updatedAt: now,
        );
      case 'tag-preset-ai':
      case 'ai':
        return model_tag.Tag(
          id: 'tag-preset-ai',
          name: 'AI',
          colorKey: 'blue',
          sortOrder: 7,
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
