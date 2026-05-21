import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsState {
  final bool isConfigured;
  final bool isConnected;
  final String serverUrl;
  final String username;
  const SettingsState({this.isConfigured = false, this.isConnected = false, this.serverUrl = '', this.username = ''});

  SettingsState copyWith({bool? isConfigured, bool? isConnected, String? serverUrl, String? username}) {
    return SettingsState(
      isConfigured: isConfigured ?? this.isConfigured,
      isConnected: isConnected ?? this.isConnected,
      serverUrl: serverUrl ?? this.serverUrl,
      username: username ?? this.username,
    );
  }
}

class SettingsNotifier extends Notifier<SettingsState> {
  @override
  SettingsState build() => const SettingsState();

  void setConfigured(bool value, [String? url, String? name]) {
    state = state.copyWith(isConfigured: value, serverUrl: url, username: name);
  }

  void setConnected(bool value) {
    state = state.copyWith(isConnected: value);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);
