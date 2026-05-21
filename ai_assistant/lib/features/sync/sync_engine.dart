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
    final pullCount = await _pullViaIndex(module);
    final pushCount = await _pushAll(module);
    return SyncResult(
      module: module,
      pullCount: pullCount,
      pushCount: pushCount,
      timestamp: DateTime.now(),
    );
  }

  Future<int> _pullViaIndex(String module) async {
    int pulled = 0;
    try {
      final todosIndex = await _fetchIndex(module, 'todo');
      pulled += await _processPullEntries('todo', todosIndex);
      final routinesIndex = await _fetchIndex(module, 'routine');
      pulled += await _processPullEntries('routine', routinesIndex);
    } catch (_) {}
    return pulled;
  }

  Future<List<Map<String, dynamic>>> _fetchIndex(String module, String subType) async {
    try {
      final indexPath = _pathBuilder.buildIndexPath(module, subType);
      final indexBytes = await _webdav.getFile(indexPath);
      final index = jsonDecode(utf8.decode(indexBytes));
      return (index['entries'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    } catch (_) {
      return [];
    }
  }

  Future<int> _processPullEntries(String dataType, List<Map<String, dynamic>> entries) async {
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
        if (dataType == 'todo') await _localDs.deleteTodo(id);
        await _localSyncDs.upsertSyncIndex(id, dataType, local?.localVersion ?? 1, cloudVersion, 'synced');
        pulled++;
        continue;
      }
      final fileData = await _downloadDataFile(dataType, id, entry);
      if (fileData == null) continue;
      final envelope = fileData['data'] as Map<String, dynamic>? ?? fileData;
      if (dataType == 'todo') {
        await _localDs.insertTodo(model.Todo(
          id: id, title: envelope['title'] as String,
          description: envelope['description'] as String?,
          source: envelope['source'] as String? ?? 'cloud',
          type: envelope['type'] as String? ?? 'personal',
          time: envelope['time'] as String? ?? '09:00',
          date: envelope['date'] != null ? DateTime.parse(envelope['date'] as String) : DateTime.now(),
          completed: envelope['completed'] as bool? ?? false,
          createdAt: envelope['createdAt'] != null ? DateTime.parse(envelope['createdAt'] as String) : DateTime.now(),
          updatedAt: fileData['updatedAt'] != null ? DateTime.parse(fileData['updatedAt'] as String) : DateTime.now(),
          version: cloudVersion,
        ));
      } else {
        await _localDs.insertRoutine(model_routine.Routine(
          id: 0, uuid: id, title: envelope['title'] as String,
          description: envelope['description'] as String?,
          type: envelope['type'] as String? ?? 'personal',
          time: envelope['time'] as String? ?? '09:00',
          repeatRule: envelope['repeatRule'] as String? ?? 'daily',
          repeatDays: envelope['repeatDays'] as String?,
          createdAt: envelope['createdAt'] != null ? DateTime.parse(envelope['createdAt'] as String) : DateTime.now(),
          updatedAt: fileData['updatedAt'] != null ? DateTime.parse(fileData['updatedAt'] as String) : DateTime.now(),
          version: cloudVersion,
          deleted: fileData['deleted'] as bool? ?? false,
        ));
      }
      await _localSyncDs.upsertSyncIndex(id, dataType, cloudVersion, cloudVersion, 'synced');
      pulled++;
    }
    return pulled;
  }

  Future<Map<String, dynamic>?> _downloadDataFile(String dataType, String id, Map<String, dynamic> entry) async {
    if (dataType == 'routine') {
      try {
        final p = _pathBuilder.buildFilePath(dataType, '', id);
        final bytes = await _webdav.getFile(p);
        return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      } catch (_) {}
      return null;
    }
    if (entry['date'] != null) {
      try {
        final p = _pathBuilder.buildFilePath(dataType, entry['date'] as String, id);
        final bytes = await _webdav.getFile(p);
        return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      } catch (_) {}
    }
    for (var i = 0; i < 7; i++) {
      final date = DateTime.now().subtract(Duration(days: i));
      final dateStr = date.toIso8601String().split('T').first;
      try {
        final p = _pathBuilder.buildFilePath(dataType, dateStr, id);
        final bytes = await _webdav.getFile(p);
        return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      } catch (_) {}
    }
    return null;
  }

  String _dateStr(DateTime dt) => dt.toIso8601String().split('T').first;

  Future<int> _pushAll(String module) async {
    for (final dir in _pathBuilder.requiredDirectories) {
      try { await _webdav.createDirectory(dir); } catch (_) {}
    }
    int pushed = 0;

    final todos = await _localDs.getAllTodos();
    final todoIndex = await _localSyncDs.getSyncIndexForType('todo');
    for (final todo in todos) {
      if (todo.deleted) continue;
      final li = todoIndex.where((e) => e.dataId == todo.id).firstOrNull;
      if (li != null && li.localVersion <= li.cloudVersion) continue;
      await _uploadTodoFile(todo);
      pushed++;
    }
    await _updateCloudIndex(module, 'todo');

    final routines = await _localDs.getAllRoutines();
    final routineIndex = await _localSyncDs.getSyncIndexForType('routine');
    final rp = 'MyAssistant/${_pathBuilder.username}/todos/routines';
    try { await _webdav.createDirectory(rp); } catch (_) {}
    for (final routine in routines) {
      if (routine.deleted || routine.uuid == null) continue;
      final li = routineIndex.where((e) => e.dataId == routine.uuid).firstOrNull;
      if (li != null && li.localVersion <= li.cloudVersion) continue;
      await _uploadRoutineFile(routine);
      pushed++;
    }
    await _updateCloudIndex(module, 'routine');
    return pushed;
  }

  Future<void> _uploadTodoFile(model.Todo todo) async {
    final dateStr = _dateStr(todo.date);
    final path = _pathBuilder.buildFilePath('todo', dateStr, todo.id);
    final pd = path.substring(0, path.lastIndexOf('/'));
    try { await _webdav.createDirectory(pd); } catch (_) {}
    final data = jsonEncode({
      'id': todo.id, 'type': 'todo', 'version': todo.version,
      'updatedAt': todo.updatedAt.toIso8601String(), 'date': dateStr,
      'data': {
        'title': todo.title, 'description': todo.description,
        'source': todo.source, 'type': todo.type, 'time': todo.time,
        'date': dateStr, 'completed': todo.completed,
        'createdAt': todo.createdAt.toIso8601String(),
      }, 'deleted': false,
    });
    await _webdav.putFile(path, Uint8List.fromList(utf8.encode(data)));
    await _localSyncDs.upsertSyncIndex(todo.id, 'todo', todo.version, todo.version, 'synced');
  }

  Future<void> _uploadRoutineFile(model_routine.Routine routine) async {
    if (routine.uuid == null) return;
    final path = _pathBuilder.buildFilePath('routine', '', routine.uuid!);
    final rp = 'MyAssistant/${_pathBuilder.username}/todos/routines';
    try { await _webdav.createDirectory(rp); } catch (_) {}
    final data = jsonEncode({
      'id': routine.uuid, 'type': 'routine', 'version': routine.version,
      'updatedAt': routine.updatedAt.toIso8601String(),
      'data': {
        'title': routine.title, 'description': routine.description,
        'type': routine.type, 'time': routine.time,
        'repeatRule': routine.repeatRule, 'repeatDays': routine.repeatDays,
        'createdAt': routine.createdAt.toIso8601String(),
      }, 'deleted': routine.deleted,
    });
    await _webdav.putFile(path, Uint8List.fromList(utf8.encode(data)));
    await _localSyncDs.upsertSyncIndex(routine.uuid!, 'routine', routine.version, routine.version, 'synced');
  }

  Future<void> _updateCloudIndex(String module, String subType) async {
    final entries = await _localSyncDs.getSyncIndexForType(subType);
    final allTodos = <String, model.Todo>{};
    if (subType == 'todo') {
      for (final t in await _localDs.getAllTodos()) { allTodos[t.id] = t; }
    }
    final index = {
      'module': module,
      'updatedAt': DateTime.now().toIso8601String(),
      'entries': entries.map((e) {
        final m = <String, dynamic>{
          'id': e.dataId, 'version': e.localVersion,
          'updatedAt': e.updatedAt.toIso8601String(), 'deleted': false,
        };
        if (subType == 'todo') {
          final todo = allTodos[e.dataId];
          if (todo != null) m['date'] = _dateStr(todo.date);
        }
        return m;
      }).toList(),
    };
    final path = _pathBuilder.buildIndexPath(module, subType);
    final pd = path.substring(0, path.lastIndexOf('/'));
    try { await _webdav.createDirectory(pd); } catch (_) {}
    await _webdav.putFile(path, Uint8List.fromList(utf8.encode(jsonEncode(index))));
  }

  // ── 全量同步：目录扫描 + 逐文件下载对比 ──

  Future<SyncResult> fullSync(String module) async {
    final diag = StringBuffer();
    int totalPulled = 0;

    final pushed = await _pushAll(module);

    try {
      for (var i = 0; i < 7; i++) {
        final date = DateTime.now().subtract(Duration(days: i));
        final dateStr = _dateStr(date);
        final dirPath = _pathBuilder.buildFilePath('todo', dateStr, 'dir');
        final baseDir = dirPath.substring(0, dirPath.lastIndexOf('/') + 1);
        diag.writeln('扫描目录: $baseDir');
        try {
          final resources = await _webdav.listDirectory(baseDir);
          for (final res in resources) {
            if (res.isDirectory || !res.name.endsWith('.json')) continue;
            final id = res.name.replaceAll('.json', '');
            diag.writeln('  发现文件: ${res.name}');
            final result = await _downloadAndInsertTodo(id);
            diag.writeln('  $result');
            if (result.startsWith('$id: 已拉取')) totalPulled++;
          }
        } catch (_) {
          diag.writeln('  目录不存在或无法访问');
        }
      }

      final routinesDir = 'MyAssistant/${_pathBuilder.username}/todos/routines';
      diag.writeln('扫描目录: $routinesDir');
      try {
        final resources = await _webdav.listDirectory(routinesDir);
        for (final res in resources) {
          if (res.isDirectory || !res.name.endsWith('.json')) continue;
          final id = res.name.replaceAll('.json', '');
          diag.writeln('  发现routine: ${res.name}');
          final result = await _downloadAndInsertRoutine(id);
          diag.writeln('  $result');
          if (result.startsWith('$id: routine已拉取')) totalPulled++;
        }
      } catch (_) {
        diag.writeln('  routine目录不存在或无法访问');
      }
    } catch (_) {}

    return SyncResult(
      module: module,
      pullCount: totalPulled,
      pushCount: pushed,
      timestamp: DateTime.now(),
      error: diag.toString(),
    );
  }

  Future<String> _downloadAndInsertTodo(String id) async {
    final localIndex = await _localSyncDs.getSyncIndexForType('todo');
    final local = localIndex.where((e) => e.dataId == id).firstOrNull;

    Map<String, dynamic>? fileData;
    for (var i = 0; i < 7; i++) {
      final date = DateTime.now().subtract(Duration(days: i));
      final dateStr = _dateStr(date);
      final filePath = _pathBuilder.buildFilePath('todo', dateStr, id);
      try {
        final bytes = await _webdav.getFile(filePath);
        fileData = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
        break;
      } catch (_) {}
    }
    if (fileData == null) return '$id: 文件未找到';

    final cloudVersion = fileData['version'] as int? ?? 1;
    if (local != null && local.cloudVersion >= cloudVersion) return '$id: 版本一致，跳过';
    final envelope = fileData['data'] as Map<String, dynamic>? ?? fileData;
    await _localDs.insertTodo(model.Todo(
      id: id, title: envelope['title'] as String,
      description: envelope['description'] as String?,
      source: envelope['source'] as String? ?? 'cloud',
      type: envelope['type'] as String? ?? 'personal',
      time: envelope['time'] as String? ?? '09:00',
      date: envelope['date'] != null ? DateTime.parse(envelope['date'] as String) : DateTime.now(),
      completed: envelope['completed'] as bool? ?? false,
      createdAt: envelope['createdAt'] != null ? DateTime.parse(envelope['createdAt'] as String) : DateTime.now(),
      updatedAt: fileData['updatedAt'] != null ? DateTime.parse(fileData['updatedAt'] as String) : DateTime.now(),
      version: cloudVersion,
    ));
    await _localSyncDs.upsertSyncIndex(id, 'todo', cloudVersion, cloudVersion, 'synced');
    return '$id: 已拉取(v$cloudVersion)';
  }

  Future<String> _downloadAndInsertRoutine(String id) async {
    final localIndex = await _localSyncDs.getSyncIndexForType('routine');
    final local = localIndex.where((e) => e.dataId == id).firstOrNull;
    final filePath = _pathBuilder.buildFilePath('routine', '', id);
    try {
      final bytes = await _webdav.getFile(filePath);
      final fileData = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final cloudVersion = fileData['version'] as int? ?? 1;
      if (local != null && local.cloudVersion >= cloudVersion) return '$id: 版本一致，跳过';
      final envelope = fileData['data'] as Map<String, dynamic>? ?? fileData;
      await _localDs.insertRoutine(model_routine.Routine(
        id: 0, uuid: id, title: envelope['title'] as String,
        description: envelope['description'] as String?,
        type: envelope['type'] as String? ?? 'personal',
        time: envelope['time'] as String? ?? '09:00',
        repeatRule: envelope['repeatRule'] as String? ?? 'daily',
        repeatDays: envelope['repeatDays'] as String?,
        createdAt: envelope['createdAt'] != null ? DateTime.parse(envelope['createdAt'] as String) : DateTime.now(),
        updatedAt: fileData['updatedAt'] != null ? DateTime.parse(fileData['updatedAt'] as String) : DateTime.now(),
        version: cloudVersion,
        deleted: fileData['deleted'] as bool? ?? false,
      ));
      await _localSyncDs.upsertSyncIndex(id, 'routine', cloudVersion, cloudVersion, 'synced');
      return '$id: routine已拉取(v$cloudVersion)';
    } catch (_) {
      return '$id: routine下载失败';
    }
  }

  // ── 公开的单条上传 (给 repository 的 auto-sync 用) ──

  Future<void> uploadSingleTodo(model.Todo todo) async {
    await _uploadTodoFile(todo);
    await _updateCloudIndex('todos', 'todo');
  }

  Future<void> uploadSingleRoutine(model_routine.Routine routine) async {
    await _uploadRoutineFile(routine);
    await _updateCloudIndex('todos', 'routine');
  }
}
