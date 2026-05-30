import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/api/auth_service.dart';
import '../../data/api/api_client.dart';
import '../../core/security/keychain_service.dart';
import '../../data/api/profile_service.dart';
import '../profile/profile_provider.dart';
import '../sync/sync_identity.dart';

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
    bool? isLoggedIn,
    bool? isLoading,
    String? username,
    String? nickname,
    String? token,
    String? error,
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
  @override
  AuthState build() => const AuthState();

  Future<bool> login(String account, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await AuthService.login(account, password);
    if (result.success) {
      await _saveUserInfo(result.username, result.nickname);
      _updateProfileFromAuth(result);
      state = state.copyWith(
        isLoggedIn: true,
        isLoading: false,
        username: result.username,
        nickname: result.nickname,
        token: result.token,
      );
      return true;
    }
    state = state.copyWith(isLoading: false, error: result.error);
    return false;
  }

  Future<bool> sendRegisterCode({
    required String username,
    required String email,
    required String phone,
  }) async {
    state = state.copyWith(error: null);
    final result = await AuthService.sendRegisterCode(
      username: username,
      email: email,
      phone: phone,
    );
    if (!result.success) {
      state = state.copyWith(error: result.error);
      return false;
    }
    return true;
  }

  Future<bool> register({
    required String username,
    required String password,
    required String email,
    required String phone,
    required String verificationCode,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await AuthService.register(
      username: username,
      password: password,
      email: email,
      phone: phone,
      verificationCode: verificationCode,
    );
    if (result.success) {
      await _saveUserInfo(result.username, result.nickname);
      _updateProfileFromAuth(result);
      state = state.copyWith(
        isLoggedIn: true,
        isLoading: false,
        username: result.username,
        nickname: result.nickname,
        token: result.token,
      );
      return true;
    }
    state = state.copyWith(isLoading: false, error: result.error);
    return false;
  }

  Future<void> logout() async {
    await ApiClient.clearAuthTokens();
    await _clearUserInfo();
    await _clearWebdavCredentials();
    state = const AuthState();
  }

  Future<bool> restoreSession(String? token) async {
    if (token != null && token.isNotEmpty) {
      ApiClient.setToken(token);
    }
    final info = await _loadUserInfo();
    final refreshToken = await ApiClient.loadSavedRefreshToken();
    if (refreshToken != null && refreshToken.isNotEmpty) {
      final refreshed = await AuthService.refreshSession();
      if (refreshed.success && refreshed.token != null) {
        final profile = await _loadAndSaveLatestProfile();
        final username = profile?.username.isNotEmpty == true
            ? profile!.username
            : info.$1;
        final nickname = profile?.nickname.isNotEmpty == true
            ? profile!.nickname
            : info.$2;
        state = state.copyWith(
          isLoggedIn: true,
          isLoading: false,
          token: refreshed.token,
          username: username,
          nickname: nickname,
        );
        return true;
      }
    }
    if (token != null && token.isNotEmpty && !_isJwtExpired(token)) {
      state = state.copyWith(
        isLoggedIn: true,
        isLoading: false,
        token: token,
        username: info.$1,
        nickname: info.$2,
      );
      return true;
    }
    await ApiClient.clearAuthTokens();
    state = const AuthState();
    return false;
  }

  Future<void> _saveUserInfo(String? username, String? nickname) async {
    await SyncIdentity.saveUserInfo(username, nickname);
  }

  Future<void> _clearUserInfo() async {
    await SyncIdentity.clearUserInfo();
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
    return SyncIdentity.loadUserInfo();
  }

  void _updateProfileFromAuth(LoginResult result) {
    ref.read(profileProvider.notifier).updateFromServer({
      'username': result.username,
      'nickname': result.nickname,
      'avatar': result.avatar,
      'email': result.email,
      'phone': result.phone,
    });
  }

  Future<ProfileData?> _loadAndSaveLatestProfile() async {
    final profile = await ProfileService.getProfile();
    if (profile == null) return null;
    await _saveUserInfo(profile.username, profile.nickname);
    ref.read(profileProvider.notifier).updateFromServer(profile.toProfileMap());
    return profile;
  }

  bool _isJwtExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      final payload =
          jsonDecode(
                utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
              )
              as Map<String, dynamic>;
      final exp = payload['exp'];
      if (exp is! num) return true;
      final expiry = DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000);
      return !expiry.isAfter(DateTime.now().add(const Duration(seconds: 30)));
    } catch (_) {
      return true;
    }
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
