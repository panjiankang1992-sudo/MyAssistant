import 'package:flutter_test/flutter_test.dart';
import 'package:ai_assistant/domain/models/todo.dart';
import 'package:ai_assistant/domain/services/todo_dedupe_service.dart';

void main() {
  group('TodoDedupeService', () {
    test('dedupes generated calendar message and routine todos', () {
      final date = DateTime(2026, 5, 30);
      final todos = [
        _todo(
          id: 'calendar-old',
          source: 'calendar',
          routineId: 'event-1',
          date: date,
          version: 1,
          updatedAt: DateTime(2026, 5, 30, 9),
        ),
        _todo(
          id: 'calendar-new',
          source: 'calendar',
          routineId: 'event-1',
          date: date,
          version: 2,
          updatedAt: DateTime(2026, 5, 30, 10),
        ),
        _todo(
          id: 'message-old',
          source: 'message',
          title: '取快递',
          date: date,
          updatedAt: DateTime(2026, 5, 30, 9),
        ),
        _todo(
          id: 'message-new',
          source: 'message',
          title: ' 取快递 ',
          date: date,
          updatedAt: DateTime(2026, 5, 30, 10),
        ),
        _todo(
          id: 'routine-old',
          source: 'routine',
          routineId: 'routine-1',
          date: date,
          time: '09:00',
          updatedAt: DateTime(2026, 5, 30, 9),
        ),
        _todo(
          id: 'routine-new',
          source: 'routine',
          routineId: 'routine-1',
          date: date,
          time: '10:00',
          updatedAt: DateTime(2026, 5, 30, 10),
        ),
      ];

      final duplicateIds = TodoDedupeService.duplicatesToDelete(
        todos,
      ).map((todo) => todo.id);

      expect(duplicateIds, containsAll(['calendar-old', 'message-old']));
      expect(duplicateIds, contains('routine-old'));
      expect(duplicateIds, isNot(contains('calendar-new')));
      expect(duplicateIds, isNot(contains('message-new')));
      expect(duplicateIds, isNot(contains('routine-new')));
    });

    test('does not dedupe manual or ai todos with similar content', () {
      final date = DateTime(2026, 5, 30);
      final todos = [
        _todo(id: 'manual-1', source: 'manual', date: date),
        _todo(id: 'manual-2', source: 'manual', date: date),
        _todo(id: 'ai-1', source: 'ai', date: date),
        _todo(id: 'ai-2', source: 'ai', date: date),
      ];

      expect(TodoDedupeService.duplicatesToDelete(todos), isEmpty);
    });

    test('keeps completed todo when a generated duplicate is unfinished', () {
      final date = DateTime(2026, 5, 30);
      final todos = [
        _todo(
          id: 'completed',
          source: 'calendar',
          routineId: 'event-1',
          date: date,
          completed: true,
          updatedAt: DateTime(2026, 5, 30, 9),
        ),
        _todo(
          id: 'unfinished',
          source: 'calendar',
          routineId: 'event-1',
          date: date,
          version: 2,
          updatedAt: DateTime(2026, 5, 30, 10),
        ),
      ];

      final duplicateIds = TodoDedupeService.duplicatesToDelete(
        todos,
      ).map((todo) => todo.id);

      expect(duplicateIds, ['unfinished']);
    });
  });
}

Todo _todo({
  required String id,
  required String source,
  DateTime? date,
  DateTime? updatedAt,
  String? routineId,
  String title = '测试待办',
  String time = '09:00',
  int version = 1,
  bool completed = false,
}) {
  final createdAt = DateTime(2026, 5, 30, 8);
  return Todo(
    id: id,
    title: title,
    source: source,
    routineId: routineId,
    type: 'personal',
    time: time,
    date: date ?? DateTime(2026, 5, 30),
    createdAt: createdAt,
    updatedAt: updatedAt ?? createdAt,
    version: version,
    completed: completed,
  );
}
