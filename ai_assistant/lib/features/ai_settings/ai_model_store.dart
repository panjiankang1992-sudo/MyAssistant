import 'package:uuid/uuid.dart';

import '../../core/database/database.dart';
import '../../data/datasources/local_datasource.dart';
import '../../domain/models/ai_model_config.dart';

class AiModelStore {
  static const _id = 'ai_models';
  final AppDatabase _db;

  AiModelStore(this._db);

  Future<List<AiModelConfig>> getAll() async {
    try {
      final json = await LocalDatasource(_db).getAppSettingJson('data', _id);
      if (json == null) return [];
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
    await LocalDatasource(_db).upsertAppSettingJson(
      module: 'profile',
      dataType: 'data',
      id: _id,
      payload: {'models': configs.map((item) => item.toJson()).toList()},
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
