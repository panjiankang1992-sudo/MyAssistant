import 'api_client.dart';

class AuthService {
  static Future<LoginResult> login(String account, String password) async {
    final resp = await ApiClient.post('/api/auth/login', {
      'account': account,
      'password': password,
    });
    if (!resp.isSuccess) {
      return LoginResult(success: false, error: resp.message);
    }
    final data = resp.data!;
    final token = data['accessToken'] as String;
    final refreshToken = data['refreshToken'] as String?;
    await ApiClient.setTokens(token, refreshToken: refreshToken);
    return LoginResult(
      success: true,
      userId: data['userId'] as int,
      username: data['username'] as String,
      nickname: data['nickname'] as String? ?? data['username'] as String,
      avatar: data['avatar'] as String?,
      email: data['email'] as String?,
      phone: data['phone'] as String?,
      token: token,
      refreshToken: refreshToken,
      expiresIn: data['expiresIn'] as int?,
    );
  }

  static Future<LoginResult> refreshSession() async {
    final refreshToken = await ApiClient.loadSavedRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      return LoginResult(success: false, error: '登录已过期，请重新登录');
    }
    final resp = await ApiClient.postEmpty(
      '/api/auth/refresh',
      bearerToken: refreshToken,
    );
    if (!resp.isSuccess) {
      return LoginResult(success: false, error: resp.message);
    }
    final data = resp.data!;
    final token = data['accessToken'] as String;
    await ApiClient.setTokens(token, refreshToken: refreshToken);
    return LoginResult(
      success: true,
      token: token,
      refreshToken: refreshToken,
      expiresIn: data['expiresIn'] as int?,
    );
  }

  static Future<AuthActionResult> sendRegisterCode({
    required String username,
    required String email,
    required String phone,
  }) async {
    final resp = await ApiClient.post('/api/public/register/code', {
      'username': username,
      'email': email,
      'phone': phone,
    });
    if (!resp.isSuccess) {
      return AuthActionResult(success: false, error: resp.message);
    }
    return const AuthActionResult(success: true);
  }

  static Future<LoginResult> register({
    required String username,
    required String password,
    required String email,
    required String phone,
    required String verificationCode,
  }) async {
    final resp = await ApiClient.post('/api/public/register', {
      'username': username,
      'password': password,
      'email': email,
      'phone': phone,
      'verificationCode': verificationCode,
    });
    if (!resp.isSuccess) {
      return LoginResult(success: false, error: resp.message);
    }
    final data = resp.data!;
    final token = data['accessToken'] as String;
    final refreshToken = data['refreshToken'] as String?;
    await ApiClient.setTokens(token, refreshToken: refreshToken);
    return LoginResult(
      success: true,
      userId: data['userId'] as int,
      username: data['username'] as String,
      nickname: data['username'] as String,
      avatar: data['avatar'] as String?,
      email: data['email'] as String?,
      phone: data['phone'] as String?,
      token: token,
      refreshToken: refreshToken,
      expiresIn: data['expiresIn'] as int?,
    );
  }
}

class AuthActionResult {
  final bool success;
  final String? error;

  const AuthActionResult({required this.success, this.error});
}

class LoginResult {
  final bool success;
  final String? error;
  final int? userId;
  final String? username;
  final String? nickname;
  final String? avatar;
  final String? email;
  final String? phone;
  final String? token;
  final String? refreshToken;
  final int? expiresIn;

  LoginResult({
    required this.success,
    this.error,
    this.userId,
    this.username,
    this.nickname,
    this.avatar,
    this.email,
    this.phone,
    this.token,
    this.refreshToken,
    this.expiresIn,
  });
}
