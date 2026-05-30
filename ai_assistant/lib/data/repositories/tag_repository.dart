import 'package:uuid/uuid.dart';
import '../../domain/models/tag.dart';
import '../datasources/local_datasource.dart';

class TagRepository {
  final LocalDatasource _datasource;

  TagRepository(this._datasource);

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
    return tag;
  }

  Future<void> updateTag(Tag tag) async {
    await _datasource.updateTag(tag);
  }

  Future<void> deleteTag(String id) async {
    await _datasource.deleteTag(id);
  }

  Future<void> reorderTags(List<Tag> tags) async {
    for (var i = 0; i < tags.length; i++) {
      final tag = tags[i].copyWith(sortOrder: i);
      await _datasource.updateTag(tag);
    }
  }
}
