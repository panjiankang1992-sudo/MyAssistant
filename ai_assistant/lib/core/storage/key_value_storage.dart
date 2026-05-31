import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class KeyValueStorage {
  Future<void> write(String key, Object? value);

  Future<T?> read<T>(String key);

  Future<void> delete(String key);

  Future<void> clear();
}

class AppKeyValueStorage implements KeyValueStorage {
  AppKeyValueStorage._();

  static final AppKeyValueStorage instance = AppKeyValueStorage._();

  static const MethodChannel _ohosChannel = MethodChannel(
    'my_assistant/local_store',
  );

  static bool get _isOhos =>
      defaultTargetPlatform.name.toLowerCase() == 'ohos' ||
      Platform.operatingSystem == 'ohos';

  Future<String?> readString(String key) => read<String>(key);

  Future<void> writeString(String key, String value) => write(key, value);

  Future<Map<String, dynamic>?> readJson(String key) async {
    final raw = await readString(key);
    if (raw == null || raw.trim().isEmpty) return null;
    final decoded = jsonDecode(raw);
    return decoded is Map ? decoded.cast<String, dynamic>() : null;
  }

  Future<void> writeJson(String key, Map<String, dynamic> value) {
    return writeString(key, jsonEncode(value));
  }

  @override
  Future<void> write(String key, Object? value) async {
    final normalized = _normalizeKey(key);
    if (_isOhos) {
      await _ohosChannel.invokeMethod<bool>('writeText', {
        'name': normalized,
        'content': value == null ? '' : _encodeValue(value),
      });
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    switch (value) {
      case null:
        await prefs.remove(normalized);
      case String():
        await prefs.setString(normalized, value);
      case int():
        await prefs.setInt(normalized, value);
      case double():
        await prefs.setDouble(normalized, value);
      case bool():
        await prefs.setBool(normalized, value);
      case List<String>():
        await prefs.setStringList(normalized, value);
      default:
        await prefs.setString(normalized, _encodeValue(value));
    }
  }

  @override
  Future<T?> read<T>(String key) async {
    final normalized = _normalizeKey(key);
    Object? value;
    if (_isOhos) {
      value = await _ohosChannel.invokeMethod<String>('readText', {
        'name': normalized,
      });
      if (value is String && value.isEmpty) return null;
    } else {
      final prefs = await SharedPreferences.getInstance();
      value = prefs.get(normalized);
    }

    if (value is T) return value;
    return null;
  }

  @override
  Future<void> delete(String key) async {
    final normalized = _normalizeKey(key);
    if (_isOhos) {
      await _ohosChannel.invokeMethod<bool>('delete', {'name': normalized});
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(normalized);
  }

  @override
  Future<void> clear() async {
    if (_isOhos) {
      await _ohosChannel.invokeMethod<bool>('clear');
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  static String _normalizeKey(String key) {
    final trimmed = key.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(key, 'key', 'Storage key cannot be empty');
    }
    return trimmed.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
  }

  static String _encodeValue(Object value) {
    return value is String ? value : jsonEncode(value);
  }
}
