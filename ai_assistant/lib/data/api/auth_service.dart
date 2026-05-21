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
    ApiClient.setToken(token);
    return LoginResult(
      success: true,
      userId: data['userId'] as int,
      username: data['username'] as String,
      nickname: data['nickname'] as String? ?? data['username'] as String,
      avatar: data['avatar'] as String?,
      token: token,
    );
  }
}

class LoginResult {
  final bool success;
  final String? error;
  final int? userId;
  final String? username;
  final String? nickname;
  final String? avatar;
  final String? token;

  LoginResult({required this.success, this.error, this.userId, this.username, this.nickname, this.avatar, this.token});
}
