import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/api/auth_service.dart';
import '../../data/api/api_client.dart';
import '../../core/security/keychain_service.dart';

class AuthState {
  final bool isLoggedIn;
  final bool isLoading;
  final String? username;
  final String? nickname;
  final String? token;
  final String? error;

  const AuthState({
    this.isLoggedIn = false,
    this.isLoading = false,
    this.username,
    this.nickname,
    this.token,
    this.error,
  });

  AuthState copyWith({
    bool? isLoggedIn, bool? isLoading, String? username,
    String? nickname, String? token, String? error,
  }) {
    return AuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      isLoading: isLoading ?? this.isLoading,
      username: username ?? this.username,
      nickname: nickname ?? this.nickname,
      token: token ?? this.token,
      error: error,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  static const _keyUsername = 'auth_username';
  static const _keyNickname = 'auth_nickname';

  @override
  AuthState build() => const AuthState();

  Future<bool> login(String account, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await AuthService.login(account, password);
    if (result.success) {
      await _saveUserInfo(result.username, result.nickname);
      state = state.copyWith(
        isLoggedIn: true, isLoading: false,
        username: result.username, nickname: result.nickname, token: result.token,
      );
      return true;
    }
    state = state.copyWith(isLoading: false, error: result.error);
    return false;
  }

  void logout() {
    ApiClient.setToken(null);
    _clearUserInfo();
    _clearWebdavCredentials();
    state = const AuthState();
  }

  void restoreSession(String token) {
    ApiClient.setToken(token);
    _loadUserInfo().then((info) {
      state = state.copyWith(
        isLoggedIn: true,
        token: token,
        username: info.$1,
        nickname: info.$2,
      );
    });
  }

  Future<void> _saveUserInfo(String? username, String? nickname) async {
    if (username != null) {
      await ApiClient.storageWrite(_keyUsername, username);
    }
    if (nickname != null) {
      await ApiClient.storageWrite(_keyNickname, nickname);
    }
  }

  Future<void> _clearUserInfo() async {
    await ApiClient.storageDelete(_keyUsername);
    await ApiClient.storageDelete(_keyNickname);
  }

  Future<void> _clearWebdavCredentials() async {
    final keychain = KeychainService();
    final lastUrl = await keychain.getLastServerUrl();
    if (lastUrl != null) {
      await keychain.deleteCredentials(lastUrl);
      await keychain.setLastServerUrl(''); // 清空标记
    }
  }

  Future<(String?, String?)> _loadUserInfo() async {
    final username = await ApiClient.storageRead(_keyUsername);
    final nickname = await ApiClient.storageRead(_keyNickname);
    return (username, nickname);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
