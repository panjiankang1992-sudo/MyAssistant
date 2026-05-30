import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ai_assistant/core/database/database.dart'
    hide Attachment, Routine, Tag, Todo;
import 'package:ai_assistant/data/datasources/local_datasource.dart';
import 'package:ai_assistant/data/datasources/local_sync_datasource.dart';
import 'package:ai_assistant/data/datasources/webdav_datasource.dart';
import 'package:ai_assistant/domain/models/app_attachment.dart';
import 'package:ai_assistant/domain/models/routine.dart';
import 'package:ai_assistant/domain/models/todo.dart';
import 'package:ai_assistant/features/sync/cloud_path_builder.dart';
import 'package:ai_assistant/features/sync/sync_engine.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final enabled = Platform.environment['MY_ASSISTANT_LIVE_WEBDAV'] == '1';

  test(
    'sync engine uploads, downloads, dedupes, and syncs attachments',
    () async {
      final runId = DateTime.now().millisecondsSinceEpoch.toString();
      final root = 'MemoryE2E/MyAssistantSync-$runId';
      final remote = _MemoryWebDavDatasource();
      final deviceA = await _Harness.createMemory(root: root, webdav: remote);
      final deviceB = await _Harness.createMemory(root: root, webdav: remote);

      addTearDown(deviceA.close);
      addTearDown(deviceB.close);

      await _exerciseSync(root: root, deviceA: deviceA, deviceB: deviceB);
    },
  );

  test(
    'live WebDAV sync uploads, downloads, dedupes, and syncs attachments',
    () async {
      final baseUrl = _requiredEnv('WEBDAV_URL');
      final username = _requiredEnv('WEBDAV_USER');
      final password = _requiredEnv('WEBDAV_PASSWORD');
      final runId = DateTime.now().millisecondsSinceEpoch.toString();
      final root =
          Platform.environment['WEBDAV_ROOT'] ??
          'CodexE2E/MyAssistantSync-$runId';

      final deviceA = await _Harness.create(
        baseUrl: baseUrl,
        username: username,
        password: password,
        root: root,
      );
      final deviceB = await _Harness.create(
        baseUrl: baseUrl,
        username: username,
        password: password,
        root: root,
      );

      addTearDown(deviceA.close);
      addTearDown(deviceB.close);

      await _exerciseSync(root: root, deviceA: deviceA, deviceB: deviceB);
    },
    skip: !enabled,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

String _requiredEnv(String key) {
  final value = Platform.environment[key];
  if (value == null || value.trim().isEmpty) {
    throw StateError('Missing required environment variable: $key');
  }
  return value;
}

Future<void> _exerciseSync({
  required String root,
  required _Harness deviceA,
  required _Harness deviceB,
}) async {
  final runId = root.split('-').last;
  final paths = CloudPathBuilder(root);
  final baseTime = DateTime(2026, 5, 30, 9);
  final todo = Todo(
    id: 'todo-$runId',
    title: 'WebDAV E2E 待办 $runId',
    description: '端到端同步验证',
    source: 'message',
    routineId: 'message-$runId',
    type: 'personal',
    time: '09:30',
    date: DateTime(2026, 5, 30),
    createdAt: baseTime,
    updatedAt: baseTime,
    version: 1,
  );
  final duplicateOld = Todo(
    id: 'duplicate-old-$runId',
    title: 'WebDAV E2E 日历重复',
    source: 'calendar',
    routineId: 'calendar-$runId',
    type: 'calendar',
    time: '10:00',
    date: DateTime(2026, 5, 30),
    createdAt: baseTime,
    updatedAt: baseTime,
    version: 1,
  );
  final duplicateWinner = duplicateOld.copyWith(
    id: 'duplicate-winner-$runId',
    updatedAt: baseTime.add(const Duration(minutes: 1)),
    version: 2,
  );
  final routine = Routine(
    id: 0,
    uuid: 'routine-$runId',
    title: 'WebDAV E2E 例行 $runId',
    type: 'personal',
    time: '08:00',
    repeatRule: 'daily',
    createdAt: baseTime,
    updatedAt: baseTime,
    version: 1,
  );
  final attachment = AppAttachment(
    id: 'attachment-$runId',
    ownerType: 'note',
    ownerId: 'note-$runId',
    attachmentType: 'file',
    fileName: 'e2e.txt',
    mimeType: 'text/plain',
    sizeBytes: utf8.encode('hello-$runId').length,
    contentBase64: base64Encode(utf8.encode('hello-$runId')),
    createdAt: baseTime,
    updatedAt: baseTime,
  );
  final billId = 'bill-$runId';
  final noteId = 'note-$runId';

  await deviceA.local.insertTodo(todo);
  await deviceA.local.insertTodo(duplicateOld);
  await deviceA.local.insertTodo(duplicateWinner);
  await deviceA.local.insertRoutine(routine);
  await deviceA.local.upsertAttachment(attachment);
  await deviceA.local.upsertSyncEntityJson(
    dataType: 'bill',
    dataId: billId,
    data: {
      'id': billId,
      'kind': 'expense',
      'categoryId': 'transport',
      'categoryName': '交通',
      'categoryEmoji': '🚇',
      'note': 'E2E 地铁',
      'amount': 4.75,
      'currency': 'CNY',
      'cnyAmount': 4.75,
      'date': baseTime.toIso8601String(),
      'aiGenerated': false,
      'tags': const [],
      'createdAt': baseTime.toIso8601String(),
      'updatedAt': baseTime.toIso8601String(),
    },
    version: 1,
    isDeleted: false,
    updatedAt: baseTime,
  );
  await deviceA.local.upsertSyncEntityJson(
    dataType: 'note',
    dataId: noteId,
    data: {
      'id': noteId,
      'title': 'WebDAV E2E 随手记',
      'content': '验证新随手记表同步',
      'summary': '验证同步',
      'tags': const [],
      'date': baseTime.toIso8601String(),
      'createdAt': baseTime.toIso8601String(),
      'updatedAt': baseTime.toIso8601String(),
      'archived': false,
      'deleted': false,
      'pinned': false,
      'analyzed': false,
      'isAnalysis': false,
      'noteType': 'document',
      'category': '测试',
      'subcategory': '同步',
      'sourceNoteIds': const [],
      'attachmentIds': [attachment.id],
    },
    version: 1,
    isDeleted: false,
    updatedAt: baseTime,
  );
  await deviceA.local.upsertAppSettingJson(
    module: 'profile',
    dataType: 'theme',
    id: 'theme_settings',
    payload: {
      'mode': 'system',
      'accent': 'green',
      'density': 'comfortable',
      'reduceMotion': false,
      'highContrast': false,
    },
    updatedAt: baseTime,
  );

  expect(
    await deviceA.sync.getPendingSyncTasks(operationType: 'upload'),
    isNotEmpty,
  );

  final uploadResult = await deviceA.engine.sync('todos');
  expect(uploadResult.hasErrors, isFalse);
  expect((await deviceA.local.getTodoById(duplicateOld.id))?.deleted, true);

  final manifest = await deviceA.engine.readCloudJson(paths.syncIndexPath);
  expect(manifest, isNotNull);
  final manifestIndexNames = (manifest!['entries'] as List)
      .whereType<Map>()
      .map((entry) => entry['indexName'])
      .toSet();
  expect(manifestIndexNames, contains('todos_index.json'));
  expect(manifestIndexNames, contains('routine_index.json'));
  expect(manifestIndexNames, contains('attachments_index.json'));
  expect(manifestIndexNames, contains('bills_index.json'));
  expect(manifestIndexNames, contains('notes_index.json'));
  expect(manifestIndexNames, contains('profile_index.json'));

  final todoIndex = await deviceA.engine.readCloudJson(
    paths.buildIndexPath('todos', 'todo'),
  );
  expect((todoIndex?['entries'] as List?)?.length, greaterThanOrEqualTo(3));

  final attachmentPath = paths.buildDataFilePath(
    'attachments',
    'attachment',
    attachment.id,
    dateStr: attachment.updatedAt.toIso8601String(),
  );
  final attachmentEnvelope = await deviceA.engine.readCloudJson(attachmentPath);
  expect(attachmentEnvelope?['data']?['contentBase64'], isNotEmpty);

  final pullResult = await deviceB.engine.sync('todos');
  expect(pullResult.hasErrors, isFalse);
  expect((await deviceB.local.getTodoById(todo.id))?.title, todo.title);
  expect((await deviceB.local.getTodoById(duplicateOld.id))?.deleted, true);
  expect((await deviceB.local.getTodoById(duplicateWinner.id))?.deleted, false);
  expect(
    (await deviceB.local.getRoutineByUuid(routine.uuid!))?.title,
    routine.title,
  );
  expect(
    (await deviceB.local.getAttachmentById(attachment.id))?.contentBase64,
    attachment.contentBase64,
  );
  expect(
    (await deviceB.local.getSyncEntityJson('bills', billId))?['note'],
    'E2E 地铁',
  );
  expect(
    (await deviceB.local.getSyncEntityJson('quick_notes', noteId))?['title'],
    'WebDAV E2E 随手记',
  );
  expect(
    (await deviceB.local.getAppSettingJson(
      'theme',
      'theme_settings',
    ))?['accent'],
    'green',
  );
  expect(
    await deviceB.sync.getPendingSyncTasks(operationType: 'upload'),
    isEmpty,
  );

  final updated = todo.copyWith(
    title: 'WebDAV E2E 待办已更新 $runId',
    version: 2,
    updatedAt: baseTime.add(const Duration(minutes: 2)),
  );
  await deviceB.local.insertTodo(updated);
  await deviceB.engine.sync('todos');
  await deviceA.engine.sync('todos');

  expect((await deviceA.local.getTodoById(todo.id))?.title, updated.title);
}

class _Harness {
  final AppDatabase db;
  final LocalDatasource local;
  final LocalSyncDatasource sync;
  final WebDavDatasource webdav;
  final SyncEngine engine;

  const _Harness._({
    required this.db,
    required this.local,
    required this.sync,
    required this.webdav,
    required this.engine,
  });

  static Future<_Harness> create({
    required String baseUrl,
    required String username,
    required String password,
    required String root,
  }) async {
    final db = AppDatabase(NativeDatabase.memory());
    final local = LocalDatasource(db);
    final sync = LocalSyncDatasource(db);
    final webdav = WebDavDatasource();
    await webdav.initialize(
      baseUrl: baseUrl,
      username: username,
      password: password,
    );
    final engine = SyncEngine(local, sync, webdav, CloudPathBuilder(root));
    return _Harness._(
      db: db,
      local: local,
      sync: sync,
      webdav: webdav,
      engine: engine,
    );
  }

  static Future<_Harness> createMemory({
    required String root,
    required _MemoryWebDavDatasource webdav,
  }) async {
    final db = AppDatabase(NativeDatabase.memory());
    final local = LocalDatasource(db);
    final sync = LocalSyncDatasource(db);
    final engine = SyncEngine(local, sync, webdav, CloudPathBuilder(root));
    return _Harness._(
      db: db,
      local: local,
      sync: sync,
      webdav: webdav,
      engine: engine,
    );
  }

  Future<void> close() async {
    webdav.dispose();
    await db.close();
  }
}

class _MemoryWebDavDatasource extends WebDavDatasource {
  final Map<String, Uint8List> _files = {};
  final Set<String> _directories = {};

  @override
  Future<void> createDirectory(String path) async {
    _directories.add(CloudPathBuilder.normalizeRootDirectory(path));
  }

  @override
  Future<Uint8List> getFile(String path) async {
    final normalized = CloudPathBuilder.normalizeRootDirectory(path);
    final bytes = _files[normalized];
    if (bytes == null) throw StateError('File not found: $normalized');
    return Uint8List.fromList(bytes);
  }

  @override
  Future<void> putFile(
    String path,
    Uint8List data, {
    String? contentType,
  }) async {
    final normalized = CloudPathBuilder.normalizeRootDirectory(path);
    _files[normalized] = Uint8List.fromList(data);
  }

  @override
  Future<bool> exists(String path) async {
    final normalized = CloudPathBuilder.normalizeRootDirectory(path);
    return _files.containsKey(normalized) || _directories.contains(normalized);
  }

  @override
  Future<void> deleteFile(String path) async {
    final normalized = CloudPathBuilder.normalizeRootDirectory(path);
    _files.remove(normalized);
    _directories.remove(normalized);
  }

  @override
  void dispose() {}
}
