import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class KeychainService {
  /// macOS: usesDataProtectionKeychain 设为 false，否则在没有开发者证书的
  /// ad-hoc 签名环境下会抛出 -34018 (errSecMissingEntitlement)。
  static const _macOptions = MacOsOptions(
    accessibility: KeychainAccessibility.unlocked,
    usesDataProtectionKeychain: false,
    synchronizable: false,
  );

  final FlutterSecureStorage _storage = const FlutterSecureStorage(mOptions: _macOptions);

  Future<void> saveCredentials(String serverUrl, String username, String password) async {
    await _storage.write(key: 'webdav:$serverUrl:username', value: username, mOptions: _macOptions);
    await _storage.write(key: 'webdav:$serverUrl:password', value: password, mOptions: _macOptions);
  }

  Future<Map<String, String>?> getCredentials(String serverUrl) async {
    final username = await _storage.read(key: 'webdav:$serverUrl:username', mOptions: _macOptions);
    final password = await _storage.read(key: 'webdav:$serverUrl:password', mOptions: _macOptions);
    if (username == null || password == null) return null;
    return {'username': username, 'password': password};
  }

  Future<void> deleteCredentials(String serverUrl) async {
    await _storage.delete(key: 'webdav:$serverUrl:username', mOptions: _macOptions);
    await _storage.delete(key: 'webdav:$serverUrl:password', mOptions: _macOptions);
  }

  Future<String?> getLastServerUrl() async {
    return await _storage.read(key: 'webdav_last_server', mOptions: _macOptions);
  }

  Future<void> setLastServerUrl(String url) async {
    await _storage.write(key: 'webdav_last_server', value: url, mOptions: _macOptions);
  }
}
