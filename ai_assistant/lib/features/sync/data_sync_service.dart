import 'dart:async';

import '../../data/datasources/local_sync_datasource.dart';
import 'providers/sync_provider.dart';
import 'sync_engine.dart';

enum DataSyncType {
  todo('todo', '待办'),
  routine('routine', '例行代办'),
  bill('bill', '记账'),
  note('note', '随手记'),
  profile('profile', '个人配置'),
  copilot('copilot', 'Copilot'),
  setting('setting', '设置'),
  tag('tag', '标签'),
  metadata('metadata', '元数据'),
  attachment('attachment', '附件');

  final String key;
  final String label;

  const DataSyncType(this.key, this.label);
}

class DataSyncService {
  final Future<SyncEngine?> Function() _engineLoader;
  final Future<bool> Function() _syncConfigured;
  final LocalSyncDatasource _localSync;
  final SyncNotifier _notifier;
  Timer? _timer;
  StreamSubscription<int>? _pendingSubscription;
  bool _syncing = false;
  DateTime? _lastAttemptAt;

  DataSyncService({
    required Future<SyncEngine?> Function() engineLoader,
    required Future<bool> Function() syncConfigured,
    required LocalSyncDatasource localSync,
    required SyncNotifier notifier,
  }) : _engineLoader = engineLoader,
       _syncConfigured = syncConfigured,
       _localSync = localSync,
       _notifier = notifier;

  bool get isSyncing => _syncing;

  Future<bool> get isConfigured => _syncConfigured();

  void start() {
    _timer ??= Timer.periodic(
      const Duration(minutes: 10),
      (_) => syncIfNeeded(reason: 'periodic'),
    );
    _pendingSubscription ??= _localSync.watchPendingTaskCount().listen((count) {
      if (count > 0) unawaited(syncIfNeeded(reason: 'table-change'));
    });
  }

  void dispose() {
    _timer?.cancel();
    _pendingSubscription?.cancel();
  }

  Future<void> markDirty(
    DataSyncType type,
    String dataId, {
    String operation = 'upsert',
    Map<String, dynamic>? payload,
    int version = 1,
  }) async {
    // Historical repository-level dirty marking is kept as a compatibility
    // nudge only. The sync source of truth is now database triggers writing
    // rows into sync_data.
    if (await _syncConfigured()) {
      unawaited(syncIfNeeded(reason: 'legacy-mark-dirty'));
    }
  }

  Future<SyncResult?> manualSync({bool full = false}) async {
    return _runSync(full: full, reason: full ? 'manual-full' : 'manual');
  }

  Future<SyncResult?> syncIfNeeded({String reason = 'periodic'}) async {
    if (!await _syncConfigured()) return null;
    final hasPending = await _localSync.hasPendingTasks();
    final shouldCheckCloud =
        _lastAttemptAt == null ||
        DateTime.now().difference(_lastAttemptAt!).inMinutes >= 10;
    if (!hasPending && !shouldCheckCloud) return null;
    return _runSync(reason: reason);
  }

  Future<SyncResult?> _runSync({
    bool full = false,
    required String reason,
  }) async {
    if (_syncing) return null;
    if (!await _syncConfigured()) return null;
    _syncing = true;
    _lastAttemptAt = DateTime.now();
    _notifier.setSyncing(true);
    try {
      final engine = await _engineLoader();
      if (engine == null) {
        _notifier.setSyncing(false);
        return null;
      }

      final result = full
          ? await engine.fullSync('all')
          : await engine.sync('all');
      _notifier.onSyncComplete(result);
      return result;
    } catch (e) {
      final message = '同步失败，等待下次自动重试：$e';
      _notifier.onSyncError(message);
      return SyncResult(
        module: 'all',
        error: message,
        timestamp: DateTime.now(),
      );
    } finally {
      _syncing = false;
      _notifier.setSyncing(false);
    }
  }
}
