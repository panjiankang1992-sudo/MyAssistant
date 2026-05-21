import 'dart:async';
import '../../core/network/network_monitor.dart';
import 'sync_engine.dart';
import 'providers/sync_provider.dart';

class SyncScheduler {
  final SyncEngine _engine;
  final NetworkMonitor _network;
  final SyncNotifier _notifier;
  bool _syncing = false;

  SyncScheduler(this._engine, this._network, this._notifier);

  Future<void> syncNow(String module) async {
    if (_syncing) return;
    if (!await _network.hasConnection()) return;

    _syncing = true;
    _notifier.setSyncing(true);
    try {
      final result = await _engine.sync(module);
      _notifier.onSyncComplete(result);
    } catch (e) {
      _notifier.onSyncError(e.toString());
    } finally {
      _syncing = false;
    }
  }

  void onNetworkRestored(void Function() callback) {
    _network.onConnectivityChanged((hasConnection) {
      if (hasConnection) callback();
    });
  }
}
