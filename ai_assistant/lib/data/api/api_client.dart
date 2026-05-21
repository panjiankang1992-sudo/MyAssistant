import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ApiClient {
  static const String baseUrl = 'http://localhost:23110';
  static String? _token;
  static String? get token => _token;

  /// macOS: usesDataProtectionKeychain 设为 false，否则在没有开发者证书的
  /// ad-hoc 签名环境下会抛出 -34018 (errSecMissingEntitlement)。
  static const _macOptions = MacOsOptions(
    accessibility: KeychainAccessibility.unlocked,
    usesDataProtectionKeychain: false,
    synchronizable: false,
  );

  static final FlutterSecureStorage _storage = FlutterSecureStorage(mOptions: _macOptions);

  static Future<void> storageWrite(String key, String value) => _storage.write(key: key, value: value, mOptions: _macOptions);
  static Future<String?> storageRead(String key) => _storage.read(key: key, mOptions: _macOptions);
  static Future<void> storageDelete(String key) => _storage.delete(key: key, mOptions: _macOptions);

  static void setToken(String? t) {
    _token = t;
    if (t != null) {
      _storage.write(key: 'jwt_token', value: t, mOptions: _macOptions);
    } else {
      _storage.delete(key: 'jwt_token', mOptions: _macOptions);
    }
  }

  static Future<String?> loadSavedToken() async {
    _token = await _storage.read(key: 'jwt_token', mOptions: _macOptions);
    return _token;
  }

  static Map<String, String> get _authHeaders => _token != null
    ? {'Authorization': 'Bearer $_token', 'Content-Type': 'application/json'}
    : {'Content-Type': 'application/json'};

  static Future<ApiResponse> post(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('$baseUrl$path');
    final resp = await http.post(uri, headers: _authHeaders, body: jsonEncode(body));
    return ApiResponse.fromJson(jsonDecode(resp.body));
  }

  static Future<ApiResponse> get(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    final resp = await http.get(uri, headers: _authHeaders);
    return ApiResponse.fromJson(jsonDecode(resp.body));
  }

  static Future<ApiResponse> put(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('$baseUrl$path');
    final resp = await http.put(uri, headers: _authHeaders, body: jsonEncode(body));
    return ApiResponse.fromJson(jsonDecode(resp.body));
  }
}

class ApiResponse {
  final String code;
  final String message;
  final Map<String, dynamic>? data;
  final String? traceId;

  ApiResponse({required this.code, required this.message, this.data, this.traceId});
  bool get isSuccess => code == '0000';

  factory ApiResponse.fromJson(Map<String, dynamic> json) => ApiResponse(
    code: json['code'] ?? '',
    message: json['message'] ?? '',
    data: json['data'],
    traceId: json['traceId'],
  );
}