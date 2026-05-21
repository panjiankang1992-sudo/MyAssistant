import 'dart:convert';
import 'dart:typed_data';
import '../../data/datasources/local_datasource.dart';
import '../../data/datasources/local_sync_datasource.dart';
import '../../data/datasources/webdav_datasource.dart';
import '../../domain/models/todo.dart' as model;
import '../../domain/models/routine.dart' as model_routine;
import '../../features/sync/cloud_path_builder.dart';
import '../../features/sync/providers/sync_provider.dart';

class SyncEngine {
  final LocalDatasource _localDs;
  final LocalSyncDatasource _localSyncDs;
  final WebDavDatasource _webdav;
  final CloudPathBuilder _pathBuilder;

  SyncEngine(this._localDs, this._localSyncDs, this._webdav, this._pathBuilder);

  Future<SyncResult> sync(String module) async {
    final pullCount = await pull(module);
    final pushCount = await push(module);
    return SyncResult(
      module: module,
      pullCount: pullCount,
      pushCount: pushCount,
      timestamp: DateTime.now(),
    );
  }

  Future<int> pull(String module) async {
    int pulled = 0;
    try {
      final todosIndex = await _fetchIndex(module, 'todos');
      pulled += await _processPullEntries(module, 'todo', todosIndex);

      final routinesIndex = await _fetchIndex(module, 'routines');
      pulled += await _processPullEntries(module, 'routine', routinesIndex);
    } catch (_) {
      return 0;
    }
    return pulled;
  }

  Future<List<Map<String, dynamic>>> _fetchIndex(String module, String subType) async {
    final indexPath = _pathBuilder.buildIndexPath(module, subType);
    final indexBytes = await _webdav.getFile(indexPath);
    final index = jsonDecode(utf8.decode(indexBytes));
    return (index['entries'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  }

  Future<int> _processPullEntries(String module, String dataType, List<Map<String, dynamic>> entries) async {
    final localIndex = await _localSyncDs.getSyncIndexForType(dataType);
    int pulled = 0;

    for (final entry in entries) {
      final id = entry['id'] as String;
      final cloudVersion = entry['version'] as int;
      final deleted = entry['deleted'] as bool? ?? false;
      final local = localIndex.where((e) => e.dataId == id).firstOrNull;

      if (local != null && local.cloudVersion >= cloudVersion) continue;
      if (local != null && local.localVersion > cloudVersion) continue;

      if (deleted) {
        if (dataType == 'todo') {
          await _localDs.deleteTodo(id);
        }
        await _localSyncDs.upsertSyncIndex(id, dataType, local?.localVersion ?? 1, cloudVersion, 'synced');
        pulled++;
        continue;
      }

      try {
        final dateStr = entry['date'] as String? ?? DateTime.now().toIso8601String().split('T').first;
        final filePath = _pathBuilder.buildFilePath(dataType, dateStr, id);
        final fileBytes = await _webdav.getFile(filePath);
        final fileData = jsonDecode(utf8.decode(fileBytes)) as Map<String, dynamic>;
        final envelope = fileData['data'] as Map<String, dynamic>? ?? fileData;

        if (dataType == 'todo') {
          final todo = model.Todo(
            id: id,
            title: envelope['title'] as String,
            description: envelope['description'] as String?,
            source: envelope['source'] as String? ?? 'cloud',
            type: envelope['type'] as String? ?? 'personal',
            time: envelope['time'] as String? ?? '09:00',
            date: envelope['date'] != null ? DateTime.parse(envelope['date'] as String) : DateTime.now(),
            completed: envelope['completed'] as bool? ?? false,
            createdAt: envelope['createdAt'] != null ? DateTime.parse(envelope['createdAt'] as String) : DateTime.now(),
            updatedAt: fileData['updatedAt'] != null ? DateTime.parse(fileData['updatedAt'] as String) : DateTime.now(),
            version: cloudVersion,
          );
          await _localDs.insertTodo(todo);
        }
        await _localSyncDs.upsertSyncIndex(id, dataType, cloudVersion, cloudVersion, 'synced');
        pulled++;
      } catch (_) {}
    }
    return pulled;
  }

  Future<int> push(String module) async {
    int pushed = 0;

    final todos = await _localDs.getAllTodos();
    final todoIndex = await _localSyncDs.getSyncIndexForType('todo');

    for (final todo in todos) {
      if (todo.deleted) continue;
      final localIdx = todoIndex.where((e) => e.dataId == todo.id).firstOrNull;
      if (localIdx != null && localIdx.localVersion <= localIdx.cloudVersion) continue;

      try {
        final dateStr = todo.date.toIso8601String().split('T').first;
        final path = _pathBuilder.buildFilePath('todo', dateStr, todo.id);
        final parentDir = path.substring(0, path.lastIndexOf('/'));
        try { await _webdav.createDirectory(parentDir); } catch (_) {}

        final data = jsonEncode({
          'id': todo.id,
          'type': 'todo',
          'version': todo.version,
          'updatedAt': todo.updatedAt.toIso8601String(),
          'data': {
            'title': todo.title,
            'description': todo.description,
            'source': todo.source,
            'type': todo.type,
            'time': todo.time,
            'date': todo.date.toIso8601String().split('T').first,
            'completed': todo.completed,
            'createdAt': todo.createdAt.toIso8601String(),
          },
          'deleted': false,
        });
        await _webdav.putFile(path, Uint8List.fromList(utf8.encode(data)));
        await _localSyncDs.upsertSyncIndex(todo.id, 'todo', todo.version, todo.version, 'synced');
        pushed++;
      } catch (_) {}
    }

    await _updateCloudIndex(module, 'todos');
    return pushed;
  }

  Future<void> _updateCloudIndex(String module, String subType) async {
    final entries = await _localSyncDs.getSyncIndexForType(subType);
    final index = {
      'module': module,
      'updatedAt': DateTime.now().toIso8601String(),
      'entries': entries
          .map((e) => {
                'id': e.dataId,
                'version': e.localVersion,
                'updatedAt': e.updatedAt.toIso8601String(),
                'deleted': false,
              })
          .toList(),
    };
    final path = _pathBuilder.buildIndexPath(module, subType);
    await _webdav.putFile(path, Uint8List.fromList(utf8.encode(jsonEncode(index))));
  }

  Future<SyncResult> fullSync(String module) async {
    for (final dir in _pathBuilder.requiredDirectories) {
      try { await _webdav.createDirectory(dir); } catch (_) {}
    }

    final todos = await _localDs.getAllTodos();
    for (final todo in todos) {
      if (todo.deleted) continue;
      try {
        final dateStr = todo.date.toIso8601String().split('T').first;
        final path = _pathBuilder.buildFilePath('todo', dateStr, todo.id);
        final parentDir = path.substring(0, path.lastIndexOf('/'));
        try { await _webdav.createDirectory(parentDir); } catch (_) {}

        final data = jsonEncode({
          'id': todo.id,
          'type': 'todo',
          'version': todo.version,
          'updatedAt': todo.updatedAt.toIso8601String(),
          'data': {
            'title': todo.title,
            'description': todo.description,
            'source': todo.source,
            'type': todo.type,
            'time': todo.time,
            'date': todo.date.toIso8601String().split('T').first,
            'completed': todo.completed,
            'createdAt': todo.createdAt.toIso8601String(),
          },
          'deleted': false,
        });
        await _webdav.putFile(path, Uint8List.fromList(utf8.encode(data)));
        await _localSyncDs.upsertSyncIndex(todo.id, 'todo', todo.version, todo.version, 'synced');
      } catch (_) {}
    }

    await _updateCloudIndex(module, 'todos');
    return SyncResult(module: module, pullCount: 0, pushCount: todos.length, timestamp: DateTime.now());
  }

  Future<void> uploadSingleTodo(model.Todo todo) async {
    final dateStr = todo.date.toIso8601String().split('T').first;
    final path = _pathBuilder.buildFilePath('todo', dateStr, todo.id);
    final parentDir = path.substring(0, path.lastIndexOf('/'));
    try { await _webdav.createDirectory(parentDir); } catch (_) {}

    final data = jsonEncode({
      'id': todo.id,
      'type': 'todo',
      'version': todo.version,
      'updatedAt': todo.updatedAt.toIso8601String(),
      'data': {
        'title': todo.title,
        'description': todo.description,
        'source': todo.source,
        'type': todo.type,
        'time': todo.time,
        'date': todo.date.toIso8601String().split('T').first,
        'completed': todo.completed,
        'createdAt': todo.createdAt.toIso8601String(),
      },
      'deleted': todo.deleted,
    });
    await _webdav.putFile(path, Uint8List.fromList(utf8.encode(data)));
    await _localSyncDs.upsertSyncIndex(todo.id, 'todo', todo.version, todo.version, 'synced');
    await _updateCloudIndex('todos', 'todos');
  }

  Future<void> uploadSingleRoutine(model_routine.Routine routine) async {
    if (routine.uuid == null) return;
    final path = _pathBuilder.buildFilePath('routine', '', routine.uuid!);
    final parentDir = path.substring(0, path.lastIndexOf('/'));
    try { await _webdav.createDirectory(parentDir); } catch (_) {}

    final data = jsonEncode({
      'id': routine.uuid,
      'type': 'routine',
      'version': routine.version,
      'updatedAt': routine.updatedAt.toIso8601String(),
      'data': {
        'title': routine.title,
        'description': routine.description,
        'type': routine.type,
        'time': routine.time,
        'repeatRule': routine.repeatRule,
        'repeatDays': routine.repeatDays,
        'createdAt': routine.createdAt.toIso8601String(),
      },
      'deleted': routine.deleted,
    });
    await _webdav.putFile(path, Uint8List.fromList(utf8.encode(data)));
    await _localSyncDs.upsertSyncIndex(routine.uuid!, 'routine', routine.version, routine.version, 'synced');
    await _updateCloudIndex('todos', 'routines');
  }
}
