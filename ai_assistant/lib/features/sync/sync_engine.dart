import 'dart:convert';
import 'dart:typed_data';
import '../../data/datasources/local_datasource.dart';
import '../../data/datasources/local_sync_datasource.dart';
import '../../data/datasources/webdav_datasource.dart';
import '../../domain/models/todo.dart' as model;
import '../../domain/models/routine.dart' as model_routine;
import '../../domain/models/tag.dart';
import '../../domain/models/metadata_option.dart';
import '../../domain/models/app_attachment.dart';
import '../../domain/services/todo_dedupe_service.dart';
import '../../features/sync/cloud_path_builder.dart';
import '../../features/sync/providers/sync_provider.dart';

class SyncEngine {
  final LocalDatasource _localDs;
  final LocalSyncDatasource _localSyncDs;
  final WebDavDatasource _webdav;
  final CloudPathBuilder _pathBuilder;
  final List<CloudPathBuilder> _legacyPathBuilders;
  final Set<String> _ensuredDirectories = {};
  bool _manifestDirty = false;

  SyncEngine(
    this._localDs,
    this._localSyncDs,
    this._webdav,
    this._pathBuilder, {
    List<CloudPathBuilder> legacyPathBuilders = const [],
  }) : _legacyPathBuilders = legacyPathBuilders;

  String get username => _pathBuilder.username;
  List<String> get readUsernames => [
    _pathBuilder.username,
    ..._legacyPathBuilders.map((builder) => builder.username),
  ];

  List<CloudPathBuilder> get _readPathBuilders => [
    _pathBuilder,
    ..._legacyPathBuilders,
  ];

  Future<Map<String, dynamic>?> readCloudJson(String path) async {
    try {
      final bytes = await _webdav.getFile(path);
      return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<List<dynamic>?> readCloudJsonList(String path) async {
    try {
      final bytes = await _webdav.getFile(path);
      return jsonDecode(utf8.decode(bytes)) as List<dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> writeCloudJson(String path, Object data) async {
    final pd = path.substring(0, path.lastIndexOf('/'));
    await _ensureCloudDirectory(pd);
    await _webdav.putFile(
      path,
      Uint8List.fromList(utf8.encode(jsonEncode(data))),
      contentType: 'application/json',
    );
    await _recordIndexFileIfNeeded(path);
  }

  Future<SyncResult> sync(String module) async {
    await _ensureCloudDirectories();

    // Pull tags first so we have latest tag definitions
    final cloudTags = await pullTags();
    if (cloudTags.isNotEmpty) {
      await _localSyncDs.runMuted(() async {
        for (final tag in cloudTags) {
          await _localDs.insertTag(tag);
        }
      });
    }
    final cloudMetadata = await pullMetadataOptions();
    await _localSyncDs.runMuted(() async {
      for (final option in cloudMetadata) {
        await _localDs.upsertMetadataOption(option);
      }
    });

    await _pullViaIndex(module);
    final pullCount = await _processPendingDownloads();
    final pushCount = await _pushAll(module);

    return SyncResult(
      module: module,
      pullCount: pullCount,
      pushCount: pushCount,
      timestamp: DateTime.now(),
    );
  }

  Future<int> _pullViaIndex(String module) async {
    int queued = 0;
    try {
      for (final builder in _readPathBuilders) {
        final changedIndexes = await _fetchChangedIndexFiles(builder);
        if (changedIndexes.isNotEmpty) {
          for (final indexFile in changedIndexes) {
            final dataType = _dataTypeForIndexName(indexFile.indexName);
            if (dataType == null) continue;
            final entries = await _fetchIndexByPath(indexFile.path);
            queued += await _processPullEntries(dataType, entries, builder);
            await _localSyncDs.upsertSyncFile(
              indexFile.path,
              indexFile.module,
              indexFile.indexName,
              indexFile.updatedAt,
              lastModifiedDevice: indexFile.lastModifiedDevice,
            );
          }
        } else {
          final todosIndex = await _fetchIndex(module, 'todo', builder);
          queued += await _processPullEntries('todo', todosIndex, builder);
          final routinesIndex = await _fetchIndex(module, 'routine', builder);
          queued += await _processPullEntries(
            'routine',
            routinesIndex,
            builder,
          );
        }
      }
    } catch (_) {}
    return queued;
  }

  Future<List<_RemoteIndexFile>> _fetchChangedIndexFiles(
    CloudPathBuilder pathBuilder,
  ) async {
    final manifest = await readCloudJson(pathBuilder.syncIndexPath);
    final entries = (manifest?['entries'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList();
    if (entries.isEmpty) return const [];
    final localFiles = {
      for (final item in await _localSyncDs.getSyncFiles())
        item.cloudPath: item.updatedAt,
    };
    final result = <_RemoteIndexFile>[];
    for (final entry in entries) {
      final path = entry['path'] as String? ?? entry['cloudPath'] as String?;
      if (path == null || path.isEmpty) continue;
      final updatedAt = DateTime.tryParse(entry['updatedAt'] as String? ?? '');
      if (updatedAt == null) continue;
      final localUpdatedAt = localFiles[path];
      if (localUpdatedAt != null && !updatedAt.isAfter(localUpdatedAt)) {
        continue;
      }
      result.add(
        _RemoteIndexFile(
          path: path,
          module: entry['module'] as String? ?? _moduleForIndexPath(path),
          indexName: entry['indexName'] as String? ?? _indexNameForPath(path),
          updatedAt: updatedAt,
          lastModifiedDevice: entry['lastModifiedDevice'] as String? ?? 'cloud',
        ),
      );
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> _fetchIndex(
    String module,
    String subType,
    CloudPathBuilder pathBuilder,
  ) async {
    try {
      final indexPath = pathBuilder.buildIndexPath(module, subType);
      final indexBytes = await _webdav.getFile(indexPath);
      final index = jsonDecode(utf8.decode(indexBytes));
      return (index['entries'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchIndexByPath(String indexPath) async {
    try {
      final indexBytes = await _webdav.getFile(indexPath);
      final index = jsonDecode(utf8.decode(indexBytes));
      return (index['entries'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    } catch (_) {
      return [];
    }
  }

  String? _dataTypeForIndexName(String indexName) {
    return switch (indexName) {
      'todo' => 'todo',
      'todos_index.json' => 'todo',
      'routine' => 'routine',
      'routine_index.json' => 'routine',
      'routines_index.json' => 'routine',
      'tag' => 'tag',
      'tags_index.json' => 'tag',
      'metadata' => 'metadata',
      'data' => 'metadata',
      'data_index.json' => 'metadata',
      'attachment' => 'attachment',
      'attachments_index.json' => 'attachment',
      'bill' => 'bill',
      'bills_index.json' => 'bill',
      'category' => 'category',
      'category_index.json' => 'category',
      'note' => 'note',
      'notes_index.json' => 'note',
      'diary' => 'diary',
      'diary_index.json' => 'diary',
      'archive' => 'archive',
      'archive_index.json' => 'archive',
      'chat' => 'chat',
      'chat_index.json' => 'chat',
      'archive_chat' => 'archive_chat',
      'archive_chat_index.json' => 'archive_chat',
      'memory' => 'memory',
      'memory_index.json' => 'memory',
      'profile_index.json' => 'profile',
      _ => null,
    };
  }

  String _indexNameForPath(String path) {
    final slash = path.lastIndexOf('/');
    return slash < 0 ? path : path.substring(slash + 1);
  }

  String _moduleForIndexPath(String path) {
    final parts = path.split('/');
    final indexPos = parts.indexOf('index');
    if (indexPos >= 0 && indexPos + 1 < parts.length) {
      return parts[indexPos + 1];
    }
    return 'todos';
  }

  Future<int> _processPullEntries(
    String dataType,
    List<Map<String, dynamic>> entries,
    CloudPathBuilder sourcePathBuilder,
  ) async {
    int pulled = 0;
    for (final entry in entries) {
      final id = entry['id'] as String;
      final entryDataType = entry['type'] as String? ?? dataType;
      final localIndex = await _localSyncDs.getSyncIndexForType(entryDataType);
      final cloudVersion = entry['version'] as int? ?? 1;
      final cloudUpdatedAt = DateTime.tryParse(
        entry['updatedAt'] as String? ?? '',
      );
      final indexedPath = entry['path'] as String?;
      final cloudPath = indexedPath == null || indexedPath.isEmpty
          ? _fallbackCloudPath(entryDataType, id, entry, sourcePathBuilder)
          : indexedPath;
      final local = localIndex.where((e) => e.dataId == id).firstOrNull;
      if (local != null) {
        final localCloudUpdatedAt = local.cloudUpdatedAt;
        if (cloudUpdatedAt != null && localCloudUpdatedAt != null) {
          if (!cloudUpdatedAt.isAfter(localCloudUpdatedAt)) continue;
        } else if (local.cloudVersion >= cloudVersion) {
          continue;
        }
        if (local.syncStatus != 'synced' && local.localVersion > cloudVersion) {
          continue;
        }
      }
      await _localSyncDs.enqueueDownload(
        syncIndexId: '$entryDataType:$id',
        dataId: id,
        localTable: _localTableForDataType(entryDataType),
        cloudPath: cloudPath,
      );
      pulled++;
    }
    return pulled;
  }

  Future<int> _processPendingDownloads() async {
    final tasks = await _localSyncDs.getPendingSyncTasks(
      operationType: 'download',
    );
    tasks.sort((a, b) {
      final aWeight = a.localTable == 'attachments' ? 1 : 0;
      final bWeight = b.localTable == 'attachments' ? 1 : 0;
      final weight = aWeight.compareTo(bWeight);
      return weight == 0 ? a.id.compareTo(b.id) : weight;
    });
    var pulled = 0;
    for (final task in tasks) {
      try {
        final fileData = await _downloadDataFileForTask(task);
        if (fileData == null) {
          await _localSyncDs.markTaskError(task.id, '云端实体文件不存在');
          continue;
        }
        final envelope = fileData['data'] as Map<String, dynamic>? ?? fileData;
        final dataType = _dataTypeForTask(task);
        final cloudVersion = fileData['version'] as int? ?? 1;
        final cloudUpdatedAt = DateTime.tryParse(
          fileData['updatedAt'] as String? ??
              fileData['updated_at'] as String? ??
              '',
        );
        await _localSyncDs.runMuted(() async {
          if (dataType == 'todo') {
            await _localDs.insertTodo(
              model.Todo(
                id: task.dataId,
                title: envelope['title'] as String,
                description: envelope['description'] as String?,
                source: envelope['source'] as String? ?? 'cloud',
                routineId: envelope['routineId'] as String?,
                type: envelope['type'] as String? ?? 'personal',
                tags: LocalDatasource.decodeTagValue(envelope['tags']),
                action: envelope['action'] as String? ?? 'none',
                time: envelope['time'] as String? ?? '09:00',
                date: envelope['date'] != null
                    ? DateTime.parse(envelope['date'] as String)
                    : DateTime.now(),
                completed: envelope['completed'] as bool? ?? false,
                createdAt:
                    (envelope['createdAt'] ?? envelope['created_at']) != null
                    ? DateTime.parse(
                        (envelope['createdAt'] ?? envelope['created_at'])
                            as String,
                      )
                    : DateTime.now(),
                updatedAt:
                    (fileData['updatedAt'] ?? fileData['updated_at']) != null
                    ? DateTime.parse(
                        (fileData['updatedAt'] ?? fileData['updated_at'])
                            as String,
                      )
                    : DateTime.now(),
                version: cloudVersion,
                deleted:
                    fileData['deleted'] as bool? ??
                    fileData['is_deleted'] as bool? ??
                    false,
                priority: envelope['priority'] as int? ?? 0,
                reminderEnabled: envelope['reminderEnabled'] as bool? ?? true,
                reminderMinutesBefore:
                    envelope['reminderMinutesBefore'] as int?,
              ),
              trackSync: false,
            );
          } else if (dataType == 'routine') {
            await _localDs.insertRoutine(
              model_routine.Routine(
                id: 0,
                uuid: task.dataId,
                title: envelope['title'] as String,
                description: envelope['description'] as String?,
                type: envelope['type'] as String? ?? 'personal',
                tags: LocalDatasource.decodeTagValue(envelope['tags']),
                action: envelope['action'] as String? ?? 'none',
                time: envelope['time'] as String? ?? '09:00',
                repeatRule: envelope['repeatRule'] as String? ?? 'daily',
                repeatDays: envelope['repeatDays'] as String?,
                createdAt:
                    (envelope['createdAt'] ?? envelope['created_at']) != null
                    ? DateTime.parse(
                        (envelope['createdAt'] ?? envelope['created_at'])
                            as String,
                      )
                    : DateTime.now(),
                updatedAt:
                    (fileData['updatedAt'] ?? fileData['updated_at']) != null
                    ? DateTime.parse(
                        (fileData['updatedAt'] ?? fileData['updated_at'])
                            as String,
                      )
                    : DateTime.now(),
                version: cloudVersion,
                deleted:
                    fileData['deleted'] as bool? ??
                    fileData['is_deleted'] as bool? ??
                    false,
              ),
            );
          } else if (dataType == 'attachment') {
            final attachment = AppAttachment.fromJson(envelope);
            if (attachment.exceedsMaxSize) {
              throw StateError('附件超过 20MB：${attachment.fileName}');
            }
            await _localDs.upsertAttachment(attachment);
          } else {
            await _localDs.upsertSyncEntityJson(
              dataType: dataType,
              dataId: task.dataId,
              data: envelope,
              version: cloudVersion,
              isDeleted:
                  fileData['deleted'] as bool? ??
                  fileData['is_deleted'] as bool? ??
                  false,
              updatedAt: cloudUpdatedAt ?? DateTime.now(),
            );
          }
        });
        await _localSyncDs.upsertSyncIndex(
          task.dataId,
          dataType,
          cloudVersion,
          cloudVersion,
          'synced',
          syncIndexPath: task.syncIndexId,
          cloudPath: task.cloudPath,
          lastModifiedDevice: 'cloud',
          cloudUpdatedAt: cloudUpdatedAt,
          isDeleted: fileData['deleted'] as bool? ?? false,
        );
        await _localSyncDs.markTaskCompleted(
          task.id,
          cloudPath: task.cloudPath,
        );
        pulled++;
      } catch (e) {
        await _localSyncDs.markTaskError(task.id, e.toString());
      }
    }
    return pulled;
  }

  Future<Map<String, dynamic>?> _downloadDataFileForTask(
    PendingSyncTask task,
  ) async {
    final path = task.cloudPath;
    if (path == null || path.isEmpty) return null;
    try {
      final bytes = await _webdav.getFile(path);
      return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  String _fallbackCloudPath(
    String dataType,
    String id,
    Map<String, dynamic> entry,
    CloudPathBuilder sourcePathBuilder,
  ) {
    if (dataType == 'routine') {
      return sourcePathBuilder.buildFilePath(dataType, '', id);
    }
    if (dataType == 'attachment') {
      return sourcePathBuilder.buildDataFilePath(
        'attachments',
        'attachment',
        id,
        dateStr: entry['updatedAt'] as String?,
      );
    }
    final module = _moduleForDataType(dataType);
    if (module != null) {
      return sourcePathBuilder.buildDataFilePath(
        module,
        dataType,
        id,
        dateStr: entry['date'] as String? ?? entry['updatedAt'] as String?,
      );
    }
    return sourcePathBuilder.buildFilePath(
      dataType,
      entry['date'] as String? ?? '',
      id,
    );
  }

  String _localTableForDataType(String dataType) {
    return switch (dataType) {
      'todo' => 'todos',
      'routine' => 'routines',
      'tag' => 'tags',
      'metadata' => 'metadata_options',
      'attachment' => 'attachments',
      'bill' => 'bills',
      'category' => 'bill_categories',
      'note' || 'diary' || 'archive' => 'quick_notes',
      'chat' || 'archive_chat' => 'copilot_sessions',
      'memory' ||
      'profile' ||
      'user_profile' ||
      'theme' ||
      'copilot_setting' ||
      'data' ||
      'tags_setting' ||
      'feedback' => 'app_settings',
      _ => dataType,
    };
  }

  String _dataTypeForLocalTable(String localTable) {
    return switch (localTable) {
      'todos' => 'todo',
      'routines' => 'routine',
      'tags' => 'tag',
      'metadata_options' => 'metadata',
      'attachments' => 'attachment',
      'bills' => 'bill',
      'bill_categories' => 'category',
      'quick_notes' => 'note',
      'copilot_sessions' => 'chat',
      'app_settings' => 'profile',
      _ => localTable,
    };
  }

  String _dataTypeForTask(PendingSyncTask task) {
    final separator = task.syncIndexId.indexOf(':');
    if (separator > 0) return task.syncIndexId.substring(0, separator);
    return _dataTypeForLocalTable(task.localTable);
  }

  String? _moduleForDataType(String dataType) {
    return switch (dataType) {
      'todo' || 'routine' => 'todos',
      'bill' || 'category' => 'bills',
      'note' || 'diary' || 'archive' => 'notes',
      'chat' || 'archive_chat' || 'memory' => 'copilot',
      'attachment' => 'attachments',
      'profile' ||
      'user_profile' ||
      'theme' ||
      'copilot_setting' ||
      'data' ||
      'tags_setting' ||
      'feedback' => 'profile',
      _ => null,
    };
  }

  String _dateStr(DateTime dt) => dt.toIso8601String().split('T').first;

  Future<int> _pushAll(String module) async {
    await _ensureCloudDirectories();
    await _dedupeLocalGeneratedTodos();
    int pushed = await _pushPendingUploads(module);

    final todos = await _localDs.getAllTodos();
    final todoIndex = await _localSyncDs.getSyncIndexForType('todo');
    var todoChanged = false;
    for (final todo in todos) {
      final li = todoIndex.where((e) => e.dataId == todo.id).firstOrNull;
      if (todo.deleted) {
        if (li != null && li.localVersion <= li.cloudVersion) continue;
        await _uploadTodoFile(todo, deleted: true);
        todoChanged = true;
        pushed++;
        continue;
      }
      if (li != null && li.localVersion <= li.cloudVersion) continue;
      await _uploadTodoFile(todo, deleted: false);
      todoChanged = true;
      pushed++;
    }
    if (todoChanged) await _updateCloudIndex('todos', 'todo');

    final routines = await _localDs.getAllRoutines();
    final routineIndex = await _localSyncDs.getSyncIndexForType('routine');
    final rp = _pathBuilder.routineDirectory;
    await _ensureCloudDirectory(rp);
    var routineChanged = false;
    for (final routine in routines) {
      if (routine.deleted || routine.uuid == null) continue;
      final li = routineIndex
          .where((e) => e.dataId == routine.uuid)
          .firstOrNull;
      if (li != null && li.localVersion <= li.cloudVersion) continue;
      await _uploadRoutineFile(routine);
      routineChanged = true;
      pushed++;
    }
    if (routineChanged) await _updateCloudIndex('todos', 'routine');
    await _flushSyncManifestIfNeeded();
    return pushed;
  }

  Future<void> _ensureCloudDirectories() async {
    for (final dir in _pathBuilder.requiredDirectories) {
      await _ensureCloudDirectory(dir);
    }
  }

  Future<void> _ensureCloudDirectory(String path) async {
    final normalized = CloudPathBuilder.normalizeRootDirectory(path);
    if (normalized.isEmpty) return;
    var current = '';
    for (final part in normalized.split('/')) {
      if (part.trim().isEmpty) continue;
      current = current.isEmpty ? part : '$current/$part';
      if (_ensuredDirectories.contains(current)) continue;
      try {
        await _webdav.createDirectory(current);
      } catch (_) {}
      _ensuredDirectories.add(current);
    }
  }

  Future<void> _recordIndexFileIfNeeded(String path) async {
    if (path == _pathBuilder.syncIndexPath) return;
    final parts = path.split('/');
    final indexPos = parts.indexOf('index');
    if (indexPos < 0 || indexPos + 2 >= parts.length) return;
    if (!path.endsWith('.json')) return;
    final module = parts[indexPos + 1];
    await _localSyncDs.upsertSyncFile(
      path,
      module,
      _indexNameForPath(path),
      DateTime.now(),
      lastModifiedDevice: 'local',
    );
    await _writeSyncManifest();
  }

  Future<int> _pushPendingUploads(String module) async {
    final tasks = await _localSyncDs.getPendingSyncTasks(
      operationType: 'upload',
    );
    tasks.sort((a, b) {
      final aWeight = a.localTable == 'attachments' ? 1 : 0;
      final bWeight = b.localTable == 'attachments' ? 1 : 0;
      final weight = aWeight.compareTo(bWeight);
      return weight == 0 ? a.id.compareTo(b.id) : weight;
    });
    final changedTypes = <String>{};
    var pushed = 0;
    for (final task in tasks) {
      try {
        switch (task.localTable) {
          case 'todos':
            final todo = await _localDs.getTodoById(task.dataId);
            if (todo == null) {
              await _localSyncDs.markTaskError(task.id, '本地待办不存在');
              continue;
            }
            final path = _pathBuilder.buildFilePath(
              'todo',
              _dateStr(todo.date),
              todo.id,
            );
            await _uploadTodoFile(todo, deleted: todo.deleted);
            await _localSyncDs.markTaskCompleted(task.id, cloudPath: path);
            changedTypes.add('todo');
            pushed++;
            break;
          case 'routines':
            final routine = await _localDs.getRoutineByUuid(
              task.dataId,
              includeDeleted: true,
            );
            if (routine == null) {
              await _localSyncDs.markTaskError(task.id, '本地例行不存在');
              continue;
            }
            final path = _pathBuilder.buildFilePath('routine', '', task.dataId);
            await _uploadRoutineFile(routine);
            await _localSyncDs.markTaskCompleted(task.id, cloudPath: path);
            changedTypes.add('routine');
            pushed++;
            break;
          case 'tags':
            await pushTags(await _localDs.getAllTags());
            await _localSyncDs.markTaskCompleted(task.id);
            changedTypes.add('tag');
            pushed++;
            break;
          case 'metadata_options':
            await pushMetadataOptions(await _localDs.getMetadataOptions());
            await _localSyncDs.markTaskCompleted(task.id);
            changedTypes.add('metadata');
            pushed++;
            break;
          case 'attachments':
            final attachment = await _localDs.getAttachmentById(task.dataId);
            if (attachment == null) {
              await _localSyncDs.markTaskError(task.id, '本地附件不存在');
              continue;
            }
            if (attachment.exceedsMaxSize) {
              await _localSyncDs.markTaskError(task.id, '附件超过 20MB');
              continue;
            }
            final path = _pathBuilder.buildDataFilePath(
              'attachments',
              'attachment',
              attachment.id,
              dateStr: attachment.updatedAt.toIso8601String(),
            );
            await _uploadAttachmentFile(attachment, path);
            await _localSyncDs.markTaskCompleted(task.id, cloudPath: path);
            changedTypes.add('attachment');
            pushed++;
            break;
          default:
            final dataType = _dataTypeForTask(task);
            final module = _moduleForDataType(dataType);
            final entity = await _localDs.getSyncEntityJson(
              task.localTable,
              task.dataId,
              dataType: dataType,
            );
            if (module == null || entity == null) {
              await _localSyncDs.markTaskError(
                task.id,
                '暂不支持的同步表：${task.localTable}',
              );
              continue;
            }
            final path = _pathBuilder.buildDataFilePath(
              module,
              dataType,
              task.dataId,
              dateStr:
                  entity['date'] as String? ?? entity['updatedAt'] as String?,
            );
            await _uploadGenericEntityFile(
              dataType: dataType,
              dataId: task.dataId,
              data: entity,
              path: path,
            );
            await _localSyncDs.markTaskCompleted(task.id, cloudPath: path);
            changedTypes.add(dataType);
            pushed++;
        }
      } catch (e) {
        await _localSyncDs.markTaskError(task.id, e.toString());
      }
    }
    if (changedTypes.contains('todo')) await _updateCloudIndex('todos', 'todo');
    if (changedTypes.contains('routine')) {
      await _updateCloudIndex('todos', 'routine');
    }
    if (changedTypes.contains('attachment')) {
      await _updateCloudIndex('attachments', 'attachment');
    }
    for (final dataType in changedTypes) {
      if (const {
        'todo',
        'routine',
        'attachment',
        'tag',
        'metadata',
      }.contains(dataType)) {
        continue;
      }
      final module = _moduleForDataType(dataType);
      if (module != null) await _updateCloudIndex(module, dataType);
    }
    return pushed;
  }

  Future<void> _uploadGenericEntityFile({
    required String dataType,
    required String dataId,
    required Map<String, dynamic> data,
    required String path,
  }) async {
    final updatedAt =
        DateTime.tryParse(data['updatedAt'] as String? ?? '') ?? DateTime.now();
    final createdAt =
        DateTime.tryParse(data['createdAt'] as String? ?? '') ?? updatedAt;
    final version = data['version'] as int? ?? 1;
    final deleted = data['deleted'] as bool? ?? false;
    final pd = path.substring(0, path.lastIndexOf('/'));
    await _ensureCloudDirectory(pd);
    await _webdav.putFile(
      path,
      Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'id': dataId,
            'type': dataType,
            'version': version,
            'is_deleted': deleted,
            'created_at': createdAt.toIso8601String(),
            'updated_at': updatedAt.toIso8601String(),
            'updatedAt': updatedAt.toIso8601String(),
            'deleted': deleted,
            'date': data['date'],
            'data': data,
          }),
        ),
      ),
      contentType: 'application/json',
    );
    await _localSyncDs.upsertSyncIndex(
      dataId,
      dataType,
      version,
      version,
      'synced',
      syncIndexPath: _pathBuilder.buildIndexPath(
        _moduleForDataType(dataType) ?? dataType,
        dataType,
      ),
      cloudPath: path,
      cloudUpdatedAt: updatedAt,
      isDeleted: deleted,
    );
  }

  Future<void> _uploadAttachmentFile(
    AppAttachment attachment,
    String path,
  ) async {
    final pd = path.substring(0, path.lastIndexOf('/'));
    await _ensureCloudDirectory(pd);
    final data = jsonEncode({
      'id': attachment.id,
      'type': 'attachment',
      'version': 1,
      'is_deleted': attachment.isDeleted,
      'created_at': attachment.createdAt.toIso8601String(),
      'updated_at': attachment.updatedAt.toIso8601String(),
      'updatedAt': attachment.updatedAt.toIso8601String(),
      'deleted': attachment.isDeleted,
      'data': attachment.toJson(),
    });
    await _webdav.putFile(
      path,
      Uint8List.fromList(utf8.encode(data)),
      contentType: 'application/json',
    );
    await _localSyncDs.upsertSyncIndex(
      attachment.id,
      'attachment',
      1,
      1,
      'synced',
      syncIndexPath: _pathBuilder.buildIndexPath('attachments', 'attachment'),
      cloudPath: path,
      cloudUpdatedAt: attachment.updatedAt,
      isDeleted: attachment.isDeleted,
    );
  }

  Future<int> _dedupeLocalGeneratedTodos() async {
    final todos = await _localDs.getAllTodos();
    final syncIndex = await _localSyncDs.getSyncIndexForType('todo');
    final cloudVersionById = {
      for (final item in syncIndex) item.dataId: item.cloudVersion,
    };

    final duplicates = TodoDedupeService.duplicatesToDelete(
      todos,
      cloudVersionById: cloudVersionById,
    );
    for (final duplicate in duplicates) {
      await _localDs.softDeleteTodo(duplicate.id);
      await _localSyncDs.upsertSyncIndex(
        duplicate.id,
        'todo',
        duplicate.version + 1,
        cloudVersionById[duplicate.id] ?? 0,
        'pending',
      );
    }
    return duplicates.length;
  }

  Future<void> _uploadTodoFile(model.Todo todo, {required bool deleted}) async {
    final dateStr = _dateStr(todo.date);
    final path = _pathBuilder.buildFilePath('todo', dateStr, todo.id);
    final pd = path.substring(0, path.lastIndexOf('/'));
    await _ensureCloudDirectory(pd);
    final data = jsonEncode({
      'id': todo.id,
      'type': 'todo',
      'version': todo.version,
      'is_deleted': deleted,
      'created_at': todo.createdAt.toIso8601String(),
      'updated_at': todo.updatedAt.toIso8601String(),
      'updatedAt': todo.updatedAt.toIso8601String(),
      'date': dateStr,
      'data': {
        'title': todo.title,
        'description': todo.description,
        'source': todo.source,
        'routineId': todo.routineId,
        'type': todo.type,
        'tags': LocalDatasource.encodeTags(todo.tags),
        'action': todo.action,
        'time': todo.time,
        'date': dateStr,
        'completed': todo.completed,
        'priority': todo.priority,
        'reminderEnabled': todo.reminderEnabled,
        'reminderMinutesBefore': todo.reminderMinutesBefore,
        'createdAt': todo.createdAt.toIso8601String(),
      },
      'deleted': deleted,
    });
    try {
      await _webdav.putFile(
        path,
        Uint8List.fromList(utf8.encode(data)),
        contentType: 'application/json',
      );
    } on Exception catch (e) {
      if (e.toString().contains('409')) {
        // Cloud has newer version — treat as synced, refresh cloud version
        final cloudVersion = await _getCloudFileVersion(path);
        if (cloudVersion != null) {
          await _localSyncDs.upsertSyncIndex(
            todo.id,
            'todo',
            todo.version,
            cloudVersion,
            'synced',
            syncIndexPath: _pathBuilder.buildIndexPath('todos', 'todo'),
            cloudPath: path,
            cloudUpdatedAt: DateTime.now(),
            isDeleted: todo.deleted,
          );
        }
        return;
      }
      rethrow;
    }
    await _localSyncDs.upsertSyncIndex(
      todo.id,
      'todo',
      todo.version,
      todo.version,
      'synced',
      syncIndexPath: _pathBuilder.buildIndexPath('todos', 'todo'),
      cloudPath: path,
      cloudUpdatedAt: todo.updatedAt,
      isDeleted: deleted,
    );
  }

  Future<void> _uploadRoutineFile(model_routine.Routine routine) async {
    if (routine.uuid == null) return;
    final path = _pathBuilder.buildFilePath('routine', '', routine.uuid!);
    final rp = _pathBuilder.routineDirectory;
    await _ensureCloudDirectory(rp);
    final data = jsonEncode({
      'id': routine.uuid,
      'type': 'routine',
      'version': routine.version,
      'is_deleted': routine.deleted,
      'created_at': routine.createdAt.toIso8601String(),
      'updated_at': routine.updatedAt.toIso8601String(),
      'updatedAt': routine.updatedAt.toIso8601String(),
      'data': {
        'title': routine.title,
        'description': routine.description,
        'type': routine.type,
        'tags': LocalDatasource.encodeTags(routine.tags),
        'action': routine.action,
        'time': routine.time,
        'repeatRule': routine.repeatRule,
        'repeatDays': routine.repeatDays,
        'createdAt': routine.createdAt.toIso8601String(),
      },
      'deleted': routine.deleted,
    });
    try {
      await _webdav.putFile(
        path,
        Uint8List.fromList(utf8.encode(data)),
        contentType: 'application/json',
      );
    } on Exception catch (e) {
      if (e.toString().contains('409')) {
        final cloudVersion = await _getCloudFileVersion(path);
        if (cloudVersion != null) {
          await _localSyncDs.upsertSyncIndex(
            routine.uuid!,
            'routine',
            routine.version,
            cloudVersion,
            'synced',
            syncIndexPath: _pathBuilder.buildIndexPath('todos', 'routine'),
            cloudPath: path,
            cloudUpdatedAt: DateTime.now(),
            isDeleted: routine.deleted,
          );
        }
        return;
      }
      rethrow;
    }
    await _localSyncDs.upsertSyncIndex(
      routine.uuid!,
      'routine',
      routine.version,
      routine.version,
      'synced',
      syncIndexPath: _pathBuilder.buildIndexPath('todos', 'routine'),
      cloudPath: path,
      cloudUpdatedAt: routine.updatedAt,
      isDeleted: routine.deleted,
    );
  }

  Future<int?> _getCloudFileVersion(String path) async {
    try {
      final bytes = await _webdav.getFile(path);
      final data = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      return data['version'] as int?;
    } catch (_) {
      return null;
    }
  }

  Future<void> _updateCloudIndex(String module, String subType) async {
    final entries = <dynamic>[];
    for (final type in _indexDataTypesFor(module, subType)) {
      entries.addAll(await _localSyncDs.getSyncIndexForType(type));
    }
    final allTodos = <String, model.Todo>{};
    final allRoutines = <String, model_routine.Routine>{};
    final allAttachments = <String, AppAttachment>{};
    if (subType == 'todo') {
      for (final t in await _localDs.getAllTodos()) {
        allTodos[t.id] = t;
      }
    } else if (subType == 'routine') {
      for (final r in await _localDs.getAllRoutines(includeDeleted: true)) {
        final uuid = r.uuid;
        if (uuid != null) allRoutines[uuid] = r;
      }
    } else if (subType == 'attachment') {
      for (final attachment in await _localDs.getAllAttachments()) {
        allAttachments[attachment.id] = attachment;
      }
    }
    final indexEntries = <Map<String, dynamic>>[];
    for (final e in entries) {
      final entryType = e.dataType as String;
      final m = <String, dynamic>{
        'id': e.dataId,
        'type': entryType,
        'version': e.localVersion,
        'updatedAt': e.updatedAt.toIso8601String(),
        'lastModifiedDevice': e.lastModifiedDevice,
        'path': e.cloudPath,
        'deleted': e.isDeleted,
      };
      if (subType == 'todo') {
        final todo = allTodos[e.dataId];
        if (todo != null) {
          m['date'] = _dateStr(todo.date);
          m['updatedAt'] = todo.updatedAt.toIso8601String();
          m['deleted'] = todo.deleted;
          m['path'] = _pathBuilder.buildFilePath(
            'todo',
            _dateStr(todo.date),
            todo.id,
          );
        }
      } else if (subType == 'routine') {
        final routine = allRoutines[e.dataId];
        if (routine != null) {
          m['updatedAt'] = routine.updatedAt.toIso8601String();
          m['deleted'] = routine.deleted;
          m['path'] = _pathBuilder.buildFilePath('routine', '', e.dataId);
        }
      } else if (subType == 'attachment') {
        final attachment = allAttachments[e.dataId];
        if (attachment != null) {
          m['updatedAt'] = attachment.updatedAt.toIso8601String();
          m['deleted'] = attachment.isDeleted;
          m['path'] = _pathBuilder.buildDataFilePath(
            'attachments',
            'attachment',
            attachment.id,
            dateStr: attachment.updatedAt.toIso8601String(),
          );
        }
      } else {
        final genericTable = _localTableForDataType(entryType);
        final entity = await _localDs.getSyncEntityJson(
          genericTable,
          e.dataId,
          dataType: entryType,
        );
        if (entity != null) {
          final updatedAt = entity['updatedAt'] as String?;
          final date = entity['date'] as String?;
          m['updatedAt'] = updatedAt ?? e.updatedAt.toIso8601String();
          m['deleted'] = entity['deleted'] as bool? ?? e.isDeleted;
          m['path'] = _pathBuilder.buildDataFilePath(
            module,
            entryType,
            e.dataId,
            dateStr: date ?? updatedAt,
          );
          if (date != null) m['date'] = date;
        }
      }
      indexEntries.add(m);
    }
    final indexPath = _pathBuilder.buildIndexPath(module, subType);
    final index = {
      'module': module,
      'type': subType,
      'updatedAt': DateTime.now().toIso8601String(),
      'entries': indexEntries,
    };
    final pd = indexPath.substring(0, indexPath.lastIndexOf('/'));
    await _ensureCloudDirectory(pd);
    try {
      await _webdav.putFile(
        indexPath,
        Uint8List.fromList(utf8.encode(jsonEncode(index))),
        contentType: 'application/json',
      );
      await _localSyncDs.upsertSyncFile(
        indexPath,
        module,
        _indexNameForPath(indexPath),
        DateTime.now(),
        lastModifiedDevice: 'local',
      );
      _manifestDirty = true;
    } on Exception catch (e) {
      // 409 on index is non-critical, just log
      if (!e.toString().contains('409')) rethrow;
    }
  }

  List<String> _indexDataTypesFor(String module, String subType) {
    if (module == 'profile') {
      return const [
        'user_profile',
        'theme',
        'copilot_setting',
        'data',
        'tags_setting',
        'feedback',
      ];
    }
    return [subType];
  }

  Future<void> _flushSyncManifestIfNeeded() async {
    if (!_manifestDirty) return;
    await _writeSyncManifest();
    _manifestDirty = false;
  }

  Future<void> _writeSyncManifest() async {
    final files = await _localSyncDs.getSyncFiles();
    await writeCloudJson(_pathBuilder.syncIndexPath, {
      'updatedAt': DateTime.now().toIso8601String(),
      'entries': files
          .map(
            (file) => {
              'path': file.cloudPath,
              'module': file.module,
              'indexName': file.indexName,
              'lastModifiedDevice': file.lastModifiedDevice,
              'updatedAt': file.updatedAt.toIso8601String(),
            },
          )
          .toList(),
    });
  }

  Future<SyncResult> fullSync(String module) async {
    return sync(module);
  }

  // ── 公开的单条上传 (给 repository 的 auto-sync 用) ──

  Future<void> uploadSingleTodo(model.Todo todo) async {
    await _uploadTodoFile(todo, deleted: todo.deleted);
    await _updateCloudIndex('todos', 'todo');
  }

  Future<void> uploadSingleRoutine(model_routine.Routine routine) async {
    await _uploadRoutineFile(routine);
    await _updateCloudIndex('todos', 'routine');
  }

  // ── 标签同步 ──

  Future<void> pushTags(List<Tag> tags) async {
    final path = _pathBuilder.buildTagsIndexPath();
    final pd = path.substring(0, path.lastIndexOf('/'));
    await _ensureCloudDirectory(pd);
    final data = jsonEncode({
      'updatedAt': DateTime.now().toIso8601String(),
      'tags': tags.map((t) => t.toJson()).toList(),
    });
    try {
      await _webdav.putFile(
        path,
        Uint8List.fromList(utf8.encode(data)),
        contentType: 'application/json',
      );
    } on Exception catch (e) {
      if (!e.toString().contains('409')) rethrow;
    }
  }

  Future<List<Tag>> pullTags() async {
    try {
      final path = _pathBuilder.buildTagsIndexPath();
      final bytes = await _webdav.getFile(path);
      final data = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final list = data['tags'] as List? ?? [];
      return list.map((e) => Tag.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> pushMetadataOptions(List<MetadataOption> options) async {
    final path = _pathBuilder.buildMetadataIndexPath();
    final pd = path.substring(0, path.lastIndexOf('/'));
    await _ensureCloudDirectory(pd);
    final data = jsonEncode({
      'updatedAt': DateTime.now().toIso8601String(),
      'options': options.map((t) => t.toJson()).toList(),
    });
    try {
      await _webdav.putFile(
        path,
        Uint8List.fromList(utf8.encode(data)),
        contentType: 'application/json',
      );
    } on Exception catch (e) {
      if (!e.toString().contains('409')) rethrow;
    }
  }

  Future<List<MetadataOption>> pullMetadataOptions() async {
    try {
      final path = _pathBuilder.buildMetadataIndexPath();
      final bytes = await _webdav.getFile(path);
      final data = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final list = data['options'] as List? ?? [];
      return list
          .map((e) => MetadataOption.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}

class _RemoteIndexFile {
  final String path;
  final String module;
  final String indexName;
  final DateTime updatedAt;
  final String lastModifiedDevice;

  const _RemoteIndexFile({
    required this.path,
    required this.module,
    required this.indexName,
    required this.updatedAt,
    required this.lastModifiedDevice,
  });
}
