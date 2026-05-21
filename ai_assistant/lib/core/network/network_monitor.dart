import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkMonitor {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  Future<bool> hasConnection() async {
    final results = await _connectivity.checkConnectivity();
    return !results.contains(ConnectivityResult.none);
  }

  Future<bool> isOnWifi() async {
    final results = await _connectivity.checkConnectivity();
    return results.contains(ConnectivityResult.wifi);
  }

  void onConnectivityChanged(Function(bool hasConnection) callback) {
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      callback(!results.contains(ConnectivityResult.none));
    });
  }

  void dispose() {
    _subscription?.cancel();
  }
}
