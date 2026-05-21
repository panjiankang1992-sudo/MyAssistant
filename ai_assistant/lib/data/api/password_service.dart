import 'api_client.dart';

class PasswordService {
  static Future<PasswordResult> changePassword(String oldPwd, String newPwd) async {
    final resp = await ApiClient.put('/api/public/password', {
      'oldPassword': oldPwd,
      'newPassword': newPwd,
    });
    return PasswordResult(success: resp.isSuccess, message: resp.message);
  }
}

class PasswordResult {
  final bool success;
  final String message;
  PasswordResult({required this.success, required this.message});
}
