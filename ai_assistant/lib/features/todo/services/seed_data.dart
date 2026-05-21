import 'package:uuid/uuid.dart';

import '../../../data/repositories/todo_repository.dart';
import '../../../domain/models/todo.dart';

class SeedData {
  static final _uuid = Uuid();

  static Future<void> seedIfEmpty(TodoRepository repo) async {
    final existing = await repo.getTodayTodos();
    if (existing.isNotEmpty) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    final todos = [
      Todo(
        id: _uuid.v4(),
        title: '缴纳本月物业费',
        type: 'bill',
        source: 'recommend',
        time: '09:00',
        date: today,
        createdAt: now,
        updatedAt: now,
      ),
      Todo(
        id: _uuid.v4(),
        title: '周报撰写与提交',
        type: 'work',
        source: 'routine',
        time: '14:30',
        date: today,
        createdAt: now,
        updatedAt: now,
      ),
      Todo(
        id: _uuid.v4(),
        title: '回复客户邮件',
        type: 'work',
        source: 'message',
        time: '11:00',
        date: today,
        createdAt: now,
        updatedAt: now,
      ),
      Todo(
        id: _uuid.v4(),
        title: '购买生日礼物',
        type: 'personal',
        source: 'recommend',
        time: '16:00',
        date: today,
        createdAt: now,
        updatedAt: now,
      ),
      Todo(
        id: _uuid.v4(),
        title: '健身房上肢训练',
        type: 'health',
        source: 'routine',
        time: '18:30',
        date: today,
        createdAt: now,
        updatedAt: now,
      ),
      Todo(
        id: _uuid.v4(),
        title: '季度预算评审会',
        type: 'work',
        source: 'calendar',
        time: '10:00',
        date: tomorrow,
        createdAt: now,
        updatedAt: now,
      ),
    ];

    for (final todo in todos) {
      await repo.addTodo(todo);
    }
  }
}
