import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class ApiClient {
  static const String baseUrl = 'http://localhost:23110';
  static String? _token;
  static String? get token => _token;

  static File? _credsFile;
  static Future<File> _getCredsFile() async {
    if (_credsFile != null) return _credsFile!;
    final dir = await getApplicationSupportDirectory();
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

  static void setToken(String? t) {
    _token = t;
    if (t != null) {
      storageWrite('jwt_token', t);
    } else {
      storageDelete('jwt_token');
    }
  }

  static Future<String?> loadSavedToken() async {
    _token = await storageRead('jwt_token');
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
