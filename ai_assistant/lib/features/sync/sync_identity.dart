import '../../data/api/api_client.dart';

class SyncIdentity {
  static const authUsernameKey = 'auth_username';
  static const authNicknameKey = 'auth_nickname';

  static Future<void> saveUserInfo(String? username, String? nickname) async {
    final normalizedUsername = username?.trim();
    final normalizedNickname = nickname?.trim();
    if (normalizedUsername != null && normalizedUsername.isNotEmpty) {
      await ApiClient.storageWrite(authUsernameKey, normalizedUsername);
    }
    if (normalizedNickname != null && normalizedNickname.isNotEmpty) {
      await ApiClient.storageWrite(authNicknameKey, normalizedNickname);
    }
  }

  static Future<(String?, String?)> loadUserInfo() async {
    final username = await ApiClient.storageRead(authUsernameKey);
    final nickname = await ApiClient.storageRead(authNicknameKey);
    return (username, nickname);
  }

  static Future<void> clearUserInfo() async {
    await ApiClient.storageDelete(authUsernameKey);
    await ApiClient.storageDelete(authNicknameKey);
  }
}
