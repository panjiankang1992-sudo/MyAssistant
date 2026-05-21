import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class KeychainService {
  static Future<File> _getCredsFile() async {
    final dir = await getApplicationSupportDirectory();
    final credsDir = Directory('${dir.path}/credentials');
    if (!await credsDir.exists()) {
      await credsDir.create(recursive: true);
    }
    return File('${credsDir.path}/keychain.json');
  }

  Future<Map<String, dynamic>> _readAll() async {
    try {
      final file = await _getCredsFile();
      if (!await file.exists()) return {};
      final content = await file.readAsString();
      if (content.isEmpty) return {};
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeAll(Map<String, dynamic> data) async {
    final file = await _getCredsFile();
    await file.writeAsString(jsonEncode(data));
  }

  Future<void> saveCredentials(String serverUrl, String username, String password) async {
    final data = await _readAll();
    data['webdav:$serverUrl:username'] = username;
    data['webdav:$serverUrl:password'] = password;
    await _writeAll(data);
  }

  Future<Map<String, String>?> getCredentials(String serverUrl) async {
    final data = await _readAll();
    final username = data['webdav:$serverUrl:username'] as String?;
    final password = data['webdav:$serverUrl:password'] as String?;
    if (username == null || password == null) return null;
    return {'username': username, 'password': password};
  }

  Future<void> deleteCredentials(String serverUrl) async {
    final data = await _readAll();
    data.remove('webdav:$serverUrl:username');
    data.remove('webdav:$serverUrl:password');
    await _writeAll(data);
  }

  Future<String?> getLastServerUrl() async {
    final data = await _readAll();
    return data['webdav_last_server'] as String?;
  }

  Future<void> setLastServerUrl(String url) async {
    final data = await _readAll();
    data['webdav_last_server'] = url;
    await _writeAll(data);
  }
}
