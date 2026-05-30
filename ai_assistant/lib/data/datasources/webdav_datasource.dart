import 'dart:async';
import 'dart:typed_data';
import 'package:webdav_plus/webdav_plus.dart';

class WebDavDatasource {
  WebdavClient? _client;
  static DateTime? _lastMutationAt;

  bool get isInitialized => _client != null;

  Future<void> initialize({
    required String baseUrl,
    required String username,
    required String password,
  }) async {
    _client = WebdavClient.configured(
      baseUrl: baseUrl,
      username: username,
      password: password,
      isPreemptive: true,
    );
  }

  Future<void> createDirectory(String path) async {
    await _withRetry(() => _client!.createDirectory(path), mutating: true);
  }

  Future<List<DavResource>> listDirectory(String path) async {
    return await _client!.list(path);
  }

  Future<Uint8List> getFile(String path) async {
    return _withRetry(() => _client!.get(path));
  }

  Future<void> putFile(
    String path,
    Uint8List data, {
    String? contentType,
  }) async {
    await _withRetry(() async {
      if (contentType != null) {
        await _client!.putWithContentType(path, data, contentType);
      } else {
        await _client!.put(path, data);
      }
    }, mutating: true);
  }

  Future<void> deleteFile(String path) async {
    await _withRetry(() => _client!.delete(path), mutating: true);
  }

  Future<bool> exists(String path) async {
    return await _client!.exists(path);
  }

  void dispose() {
    _client?.shutdown();
  }

  Future<T> _withRetry<T>(
    Future<T> Function() action, {
    bool mutating = false,
  }) async {
    Object? lastError;
    for (var attempt = 0; attempt < 4; attempt++) {
      if (mutating) await _paceMutation();
      try {
        return await action().timeout(const Duration(seconds: 12));
      } catch (e) {
        lastError = e;
        if (!_isTemporaryThrottle(e) || attempt == 3) rethrow;
        await Future<void>.delayed(Duration(seconds: 15 * (attempt + 1)));
      }
    }
    throw lastError ?? StateError('WebDAV request failed');
  }

  Future<void> _paceMutation() async {
    final last = _lastMutationAt;
    if (last != null) {
      final elapsed = DateTime.now().difference(last);
      const minInterval = Duration(milliseconds: 800);
      if (elapsed < minInterval) {
        await Future<void>.delayed(minInterval - elapsed);
      }
    }
    _lastMutationAt = DateTime.now();
  }

  bool _isTemporaryThrottle(Object error) {
    final text = error.toString();
    return text.contains('HTTP 503') ||
        text.contains('BlockedTemporarily') ||
        text.contains('Too many requests') ||
        error is TimeoutException;
  }
}
