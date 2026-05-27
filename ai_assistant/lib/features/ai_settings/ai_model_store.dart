import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../domain/models/ai_model_config.dart';

class AiModelStore {
  static Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    final configDir = Directory('${dir.path}/ai');
    if (!await configDir.exists()) {
      await configDir.create(recursive: true);
    }
    return File('${configDir.path}/models.json');
  }

  Future<List<AiModelConfig>> getAll() async {
    try {
      final file = await _file();
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      if (content.trim().isEmpty) return [];
      final json = jsonDecode(content) as Map<String, dynamic>;
      final items = json['models'] as List<dynamic>? ?? const [];
      return items
          .whereType<Map<String, dynamic>>()
          .map(AiModelConfig.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveAll(List<AiModelConfig> configs) async {
    final file = await _file();
    await file.writeAsString(
      const JsonEncoder.withIndent(
        '  ',
      ).convert({'models': configs.map((item) => item.toJson()).toList()}),
    );
  }

  Future<AiModelConfig> upsert(AiModelConfig config) async {
    final now = DateTime.now();
    final items = await getAll();
    final id = config.id.isEmpty ? const Uuid().v4() : config.id;
    final next = config.copyWith(id: id, updatedAt: now);
    final index = items.indexWhere((item) => item.id == id);
    if (index >= 0) {
      items[index] = next;
    } else {
      items.add(next.copyWith(createdAt: now));
    }
    await saveAll(items);
    return next;
  }

  Future<void> delete(String id) async {
    final items = await getAll();
    items.removeWhere((item) => item.id == id);
    await saveAll(items);
  }
}
