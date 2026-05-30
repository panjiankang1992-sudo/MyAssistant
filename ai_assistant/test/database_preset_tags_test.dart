import 'package:ai_assistant/core/database/database.dart';
import 'package:ai_assistant/data/datasources/local_datasource.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('seeds default preset tags on database creation', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final tags = await LocalDatasource(db).getAllTags();

    expect(tags.take(9).map((tag) => tag.name).toList(), [
      '个人',
      '工作',
      '交通',
      '生活',
      '健康',
      '学习',
      '科技',
      'AI',
      '账单',
    ]);
    expect(tags.take(9).every((tag) => tag.isPreset), isTrue);
  });
}
