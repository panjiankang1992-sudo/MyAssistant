import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SyncResult {
  final String module;
  final int pullCount;
  final int pushCount;
  final int errorCount;
  final DateTime timestamp;
  final String? error;
  final int todosIndexCount;
  final int routinesIndexCount;

  SyncResult({
    required this.module,
    this.pullCount = 0,
    this.pushCount = 0,
    this.errorCount = 0,
    String? error,
    DateTime? timestamp,
    this.todosIndexCount = 0,
    this.routinesIndexCount = 0,
  })  : error = error,
        timestamp = timestamp ?? DateTime.now();

  bool get hasErrors => errorCount > 0 || error != null;
}

class SyncState {
  final DateTime? lastSyncTime;
  final int lastPullCount;
  final int lastPushCount;
  final bool syncing;
  final String? error;

  const SyncState({
    this.lastSyncTime,
    this.lastPullCount = 0,
    this.lastPushCount = 0,
    this.syncing = false,
    this.error,
  });

  SyncState copyWith({
    DateTime? lastSyncTime,
    int? lastPullCount,
    int? lastPushCount,
    bool? syncing,
    String? error,
  }) {
    return SyncState(
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      lastPullCount: lastPullCount ?? this.lastPullCount,
      lastPushCount: lastPushCount ?? this.lastPushCount,
      syncing: syncing ?? this.syncing,
      error: error,
    );
  }

  SyncState clearError() => SyncState(
        lastSyncTime: lastSyncTime,
        lastPullCount: lastPullCount,
        lastPushCount: lastPushCount,
        syncing: syncing,
      );
}

class SyncNotifier extends Notifier<SyncState> {
  final StreamController<SyncResult> _resultController = StreamController<SyncResult>.broadcast();

  Stream<SyncResult> get syncStream => _resultController.stream;

  SyncResult? lastResult;

  @override
  SyncState build() {
    ref.onDispose(() => _resultController.close());
    return const SyncState();
  }

  void setSyncing(bool v) => state = state.copyWith(syncing: v);

  void onSyncComplete(SyncResult result) {
    lastResult = result;
    state = SyncState(
      lastSyncTime: result.timestamp,
      lastPullCount: result.pullCount,
      lastPushCount: result.pushCount,
      syncing: false,
      error: result.error,
    );
    _resultController.add(result);
  }

  void onSyncError(String error) {
    state = state.copyWith(syncing: false, error: error);
  }
}

final syncNotifierProvider = NotifierProvider<SyncNotifier, SyncState>(SyncNotifier.new);
