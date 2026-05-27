import 'dart:typed_data';
import 'package:webdav_plus/webdav_plus.dart';

class WebDavDatasource {
  WebdavClient? _client;

  bool get isInitialized => _client != null;

  Future<void> initialize({required String baseUrl, required String username, required String password}) async {
    _client = WebdavClient.configured(
      baseUrl: baseUrl,
      username: username,
      password: password,
      isPreemptive: true,
    );
  }

  Future<void> createDirectory(String path) async {
    await _client!.createDirectory(path);
  }

  Future<List<DavResource>> listDirectory(String path) async {
    return await _client!.list(path);
  }

  Future<Uint8List> getFile(String path) async {
    return await _client!.get(path);
  }

  Future<void> putFile(String path, Uint8List data, {String? contentType}) async {
    if (contentType != null) {
      await _client!.putWithContentType(path, data, contentType);
    } else {
      await _client!.put(path, data);
    }
  }

  Future<void> deleteFile(String path) async {
    await _client!.delete(path);
  }

  Future<bool> exists(String path) async {
    return await _client!.exists(path);
  }

  void dispose() {
    _client?.shutdown();
  }
}
