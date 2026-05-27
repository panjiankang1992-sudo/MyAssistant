import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../data/datasources/local_sync_datasource.dart';
import 'providers/sync_provider.dart';
import 'sync_engine.dart';

enum DataSyncType {
  todo('todo', '待办'),
  routine('routine', '例行代办'),
  bill('bill', '记账'),
  note('note', '随手记'),
  tag('tag', '标签'),
  metadata('metadata', '元数据');

  final String key;
  final String label;

  const DataSyncType(this.key, this.label);
}

class DataSyncService {
  final Future<SyncEngine?> Function() _engineLoader;
  final LocalSyncDatasource _localSync;
  final SyncNotifier _notifier;
  Timer? _timer;
  bool _syncing = false;
  DateTime? _lastAttemptAt;

  DataSyncService({
    required Future<SyncEngine?> Function() engineLoader,
    required LocalSyncDatasource localSync,
    required SyncNotifier notifier,
  }) : _engineLoader = engineLoader,
       _localSync = localSync,
       _notifier = notifier;

  void start() {
    _timer ??= Timer.periodic(
      const Duration(minutes: 1),
      (_) => syncIfNeeded(reason: 'periodic'),
    );
  }

  void dispose() {
    _timer?.cancel();
  }

  Future<void> markDirty(
    DataSyncType type,
    String dataId, {
    String operation = 'upsert',
    Map<String, dynamic>? payload,
    int version = 1,
  }) async {
    await _localSync.insertChangeRecord(
      dataId,
      type.key,
      operation,
      jsonEncode(payload ?? const {}),
      version,
    );
    await _localSync.upsertSyncIndex(dataId, type.key, version, 0, 'pending');
  }

  Future<SyncResult?> manualSync({bool full = false}) async {
    return _runSync(full: full, reason: full ? 'manual-full' : 'manual');
  }

  Future<SyncResult?> syncIfNeeded({String reason = 'periodic'}) async {
    final pending = await _localSync.getPendingChanges();
    final shouldCheckCloud =
        _lastAttemptAt == null ||
        DateTime.now().difference(_lastAttemptAt!).inMinutes >= 1;
    if (pending.isEmpty && !shouldCheckCloud) return null;
    return _runSync(reason: reason);
  }

  Future<SyncResult?> _runSync({
    bool full = false,
    required String reason,
  }) async {
    if (_syncing) return null;
    _syncing = true;
    _lastAttemptAt = DateTime.now();
    _notifier.setSyncing(true);
    try {
      final engine = await _engineLoader();
      if (engine == null) {
        const message = '未配置 WebDAV';
        _notifier.onSyncError(message);
        return SyncResult(
          module: 'all',
          error: message,
          timestamp: DateTime.now(),
        );
      }

      // Current engine handles todo/routine/tag/metadata bidirectional sync.
      final result = full
          ? await engine.fullSync('todos')
          : await engine.sync('todos');
      await _syncNotes(engine);
      await _syncBills(engine);
      await _localSync.markPendingPushedForTypes({
        DataSyncType.todo.key,
        DataSyncType.routine.key,
        DataSyncType.tag.key,
        DataSyncType.metadata.key,
        DataSyncType.note.key,
        DataSyncType.bill.key,
      });
      await _localSync.updateDeviceState(
        'default',
        lastSyncTime: result.timestamp,
        syncErrors: result.hasErrors ? 1 : 0,
      );
      _notifier.onSyncComplete(result);
      return result;
    } catch (e) {
      // Keep pending records untouched. The next periodic tick will retry.
      final message = '同步失败，等待下次自动重试：$e';
      _notifier.onSyncError(message);
      await _localSync.updateDeviceState('default', syncErrors: 1);
      return SyncResult(
        module: 'all',
        error: message,
        timestamp: DateTime.now(),
      );
    } finally {
      _syncing = false;
    }
  }

  Future<void> _syncNotes(SyncEngine engine) async {
    final support = await getApplicationSupportDirectory();
    final file = File('${support.path}/notes/quick_notes.json');
    final cloudPath = 'MyAssistant/${engine.username}/notes/quick_notes.json';
    final localItems = await _readLocalList(file);
    final cloudItems = await engine.readCloudJsonList(cloudPath) ?? const [];
    final merged = _mergeMapsById(
      localItems.whereType<Map>().map((item) => item.cast<String, dynamic>()),
      cloudItems.whereType<Map>().map((item) => item.cast<String, dynamic>()),
      timestampKey: 'updatedAt',
    );
    await _writeLocalJson(file, merged);
    await engine.writeCloudJson(cloudPath, merged);
  }

  Future<void> _syncBills(SyncEngine engine) async {
    final support = await getApplicationSupportDirectory();
    final entriesFile = File('${support.path}/bookkeeping/entries.json');
    final categoriesFile = File('${support.path}/bookkeeping/categories.json');
    await _syncWrappedListFile(
      engine,
      file: entriesFile,
      cloudPath: 'MyAssistant/${engine.username}/bills/ledger_entries.json',
      key: 'entries',
      timestampKey: 'createdAt',
    );
    await _syncWrappedListFile(
      engine,
      file: categoriesFile,
      cloudPath: 'MyAssistant/${engine.username}/bills/ledger_categories.json',
      key: 'categories',
    );
  }

  Future<void> _syncWrappedListFile(
    SyncEngine engine, {
    required File file,
    required String cloudPath,
    required String key,
    String? timestampKey,
  }) async {
    final local = await _readLocalMap(file);
    final cloud = await engine.readCloudJson(cloudPath) ?? const {};
    final localItems = (local[key] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>());
    final cloudItems = (cloud[key] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>());
    final merged = _mergeMapsById(
      localItems,
      cloudItems,
      timestampKey: timestampKey,
    );
    final next = {'updatedAt': DateTime.now().toIso8601String(), key: merged};
    await _writeLocalJson(file, next);
    await engine.writeCloudJson(cloudPath, next);
  }

  Future<List<dynamic>> _readLocalList(File file) async {
    if (!await file.exists()) return const [];
    final text = await file.readAsString();
    if (text.trim().isEmpty) return const [];
    return jsonDecode(text) as List<dynamic>;
  }

  Future<Map<String, dynamic>> _readLocalMap(File file) async {
    if (!await file.exists()) return const {};
    final text = await file.readAsString();
    if (text.trim().isEmpty) return const {};
    return jsonDecode(text) as Map<String, dynamic>;
  }

  Future<void> _writeLocalJson(File file, Object data) async {
    final parent = file.parent;
    if (!await parent.exists()) await parent.create(recursive: true);
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
  }

  List<Map<String, dynamic>> _mergeMapsById(
    Iterable<Map<String, dynamic>> local,
    Iterable<Map<String, dynamic>> cloud, {
    String? timestampKey,
  }) {
    final byId = <String, Map<String, dynamic>>{};
    for (final item in cloud) {
      final id = item['id'] as String?;
      if (id != null) byId[id] = item;
    }
    for (final item in local) {
      final id = item['id'] as String?;
      if (id == null) continue;
      final existing = byId[id];
      if (existing == null || _isNewer(item, existing, timestampKey)) {
        byId[id] = item;
      }
    }
    return byId.values.toList();
  }

  bool _isNewer(
    Map<String, dynamic> candidate,
    Map<String, dynamic> existing,
    String? timestampKey,
  ) {
    if (timestampKey == null) return true;
    final candidateTime = DateTime.tryParse(
      candidate[timestampKey] as String? ?? '',
    );
    final existingTime = DateTime.tryParse(
      existing[timestampKey] as String? ?? '',
    );
    if (candidateTime == null || existingTime == null) return true;
    return !candidateTime.isBefore(existingTime);
  }
}
