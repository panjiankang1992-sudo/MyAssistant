import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import '../../core/storage/app_paths.dart';

class ApiClient {
  static const String baseUrl = 'http://localhost:23110';
  static const String _accessTokenKey = 'jwt_token';
  static const String _refreshTokenKey = 'refresh_token';
  static String? _token;
  static String? _refreshToken;
  static String? get token => _token;
  static String? get refreshToken => _refreshToken;

  static File? _credsFile;
  static Future<File> _getCredsFile() async {
    if (_credsFile != null) return _credsFile!;
    final dir = await getAppSupportDirectory();
    final credsDir = Directory('${dir.path}/credentials');
    if (!await credsDir.exists()) {
      await credsDir.create(recursive: true);
    }
    _credsFile = File('${credsDir.path}/apiclient.json');
    return _credsFile!;
  }

  static Future<Map<String, dynamic>> _readAll() async {
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

  static Future<void> _writeAll(Map<String, dynamic> data) async {
    final file = await _getCredsFile();
    await file.writeAsString(jsonEncode(data));
  }

  static Future<void> storageWrite(String key, String value) async {
    final data = await _readAll();
    data[key] = value;
    await _writeAll(data);
  }

  static Future<String?> storageRead(String key) async {
    final data = await _readAll();
    return data[key] as String?;
  }

  static Future<void> storageDelete(String key) async {
    final data = await _readAll();
    data.remove(key);
    await _writeAll(data);
  }

  static Future<DateTime> storageModifiedAt() async {
    try {
      final file = await _getCredsFile();
      if (await file.exists()) return file.lastModified();
    } catch (_) {}
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  static void setToken(String? token) {
    _token = token;
    if (token != null) {
      storageWrite(_accessTokenKey, token);
    } else {
      storageDelete(_accessTokenKey);
    }
  }

  static Future<void> setTokens(
    String? accessToken, {
    String? refreshToken,
  }) async {
    _token = accessToken;
    _refreshToken = refreshToken;
    if (accessToken != null) {
      await storageWrite(_accessTokenKey, accessToken);
    } else {
      await storageDelete(_accessTokenKey);
    }
    if (refreshToken != null) {
      await storageWrite(_refreshTokenKey, refreshToken);
    } else {
      await storageDelete(_refreshTokenKey);
    }
  }

  static Future<void> clearAuthTokens() async {
    _token = null;
    _refreshToken = null;
    await storageDelete(_accessTokenKey);
    await storageDelete(_refreshTokenKey);
  }

  static Future<String?> loadSavedToken() async {
    _token = await storageRead(_accessTokenKey);
    _refreshToken = await storageRead(_refreshTokenKey);
    return _token;
  }

  static Future<String?> loadSavedRefreshToken() async {
    _refreshToken = await storageRead(_refreshTokenKey);
    return _refreshToken;
  }

  static Map<String, String> get _authHeaders => _token != null
      ? {'Authorization': 'Bearer $_token', 'Content-Type': 'application/json'}
      : {'Content-Type': 'application/json'};

  static Map<String, String> _headersForToken(String? bearerToken) =>
      bearerToken != null
      ? {
          'Authorization': 'Bearer $bearerToken',
          'Content-Type': 'application/json',
        }
      : {'Content-Type': 'application/json'};

  static Future<ApiResponse> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse('$baseUrl$path');
    final resp = await http.post(
      uri,
      headers: _authHeaders,
      body: jsonEncode(body),
    );
    return ApiResponse.fromJson(jsonDecode(resp.body));
  }

  static Future<ApiResponse> postEmpty(
    String path, {
    String? bearerToken,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final resp = await http.post(
      uri,
      headers: _headersForToken(bearerToken ?? _token),
    );
    return ApiResponse.fromJson(jsonDecode(resp.body));
  }

  static Future<ApiResponse> get(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    final resp = await http.get(uri, headers: _authHeaders);
    return ApiResponse.fromJson(jsonDecode(resp.body));
  }

  static Future<ApiResponse> put(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('$baseUrl$path');
    final resp = await http.put(
      uri,
      headers: _authHeaders,
      body: jsonEncode(body),
    );
    return ApiResponse.fromJson(jsonDecode(resp.body));
  }
}

class ApiResponse {
  final String code;
  final String message;
  final Map<String, dynamic>? data;
  final String? traceId;

  ApiResponse({
    required this.code,
    required this.message,
    this.data,
    this.traceId,
  });
  bool get isSuccess => code == '0000';

  factory ApiResponse.fromJson(Map<String, dynamic> json) => ApiResponse(
    code: json['code'] ?? '',
    message: json['message'] ?? '',
    data: json['data'],
    traceId: json['traceId'],
  );
}
