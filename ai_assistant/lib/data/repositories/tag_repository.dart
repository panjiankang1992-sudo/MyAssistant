import 'package:uuid/uuid.dart';
import '../../domain/models/tag.dart';
import '../../features/sync/data_sync_service.dart';
import '../datasources/local_datasource.dart';

class TagRepository {
  final LocalDatasource _datasource;
  final DataSyncService? _syncService;

  TagRepository(this._datasource, {DataSyncService? syncService})
    : _syncService = syncService;

  Future<List<Tag>> getAllTags() => _datasource.getAllTags();

  Future<Tag> addTag(String name, String colorKey) async {
    final now = DateTime.now();
    final tag = Tag(
      id: const Uuid().v4(),
      name: name,
      colorKey: colorKey,
      sortOrder: (await _datasource.getAllTags()).length,
      isPreset: false,
      createdAt: now,
      updatedAt: now,
    );
    await _datasource.insertTag(tag);
    await _markDirty(tag, 'upsert');
    return tag;
  }

  Future<void> updateTag(Tag tag) async {
    await _datasource.updateTag(tag);
    await _markDirty(tag, 'upsert');
  }

  Future<void> deleteTag(String id) async {
    await _datasource.deleteTag(id);
    await _syncService?.markDirty(DataSyncType.tag, id, operation: 'delete');
  }

  Future<void> reorderTags(List<Tag> tags) async {
    for (var i = 0; i < tags.length; i++) {
      final tag = tags[i].copyWith(sortOrder: i);
      await _datasource.updateTag(tag);
      await _markDirty(tag, 'upsert');
    }
  }

  Future<void> _markDirty(Tag tag, String operation) async {
    await _syncService?.markDirty(
      DataSyncType.tag,
      tag.id,
      operation: operation,
      payload: {'name': tag.name, 'updatedAt': tag.updatedAt.toIso8601String()},
    );
  }
}
