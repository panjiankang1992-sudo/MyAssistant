import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../main.dart';
import '../../../domain/models/todo.dart';

class TodoNotifier extends Notifier<List<Todo>> {
  @override
  List<Todo> build() {
    loadTodayTodos();
    return [];
  }

  Future<void> loadTodayTodos() async {
    final repo = ref.read(todoRepoProvider);
    final todos = await repo.getTodayTodos();
    state = todos;

    // 加载例行数据，为今天生成待办
    await _generateRoutineTodos();
  }

  /// 根据例行规则为今天生成待办（去重）
  Future<void> _generateRoutineTodos() async {
    final routineRepo = ref.read(routineRepoProvider);
    final todoRepo = ref.read(todoRepoProvider);
    final routines = await routineRepo.getRoutines();
    if (routines.isEmpty) return;

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final existingTodos = state;

    for (final routine in routines) {
      if (!routine.shouldGenerateOn(todayDate)) continue;

      // 去重：检查今天是否已存在标题相同且来源为例行的待办
      final alreadyExists = existingTodos.any(
        (t) => t.title == routine.title && t.source == 'routine' && t.date == todayDate,
      );
      if (alreadyExists) continue;

      final todo = Todo(
        id: const Uuid().v4(),
        title: routine.title,
        description: routine.description,
        source: 'routine',
        type: routine.type,
        time: routine.time,
        date: todayDate,
        createdAt: today,
        updatedAt: today,
      );
      await todoRepo.addTodo(todo);
    }

    // 重新加载刷新列表
    state = await todoRepo.getTodayTodos();
  }

  Future<void> addTodo(Todo todo) async {
    final repo = ref.read(todoRepoProvider);
    await repo.addTodo(todo);
    await loadTodayTodos();
  }

  Future<void> toggleComplete(String id) async {
    final repo = ref.read(todoRepoProvider);
    await repo.toggleTodo(id);
    await loadTodayTodos();
  }

  Future<void> deleteTodo(String id) async {
    final repo = ref.read(todoRepoProvider);
    await repo.deleteTodo(id);
    await loadTodayTodos();
  }
}

final todoNotifierProvider = NotifierProvider<TodoNotifier, List<Todo>>(TodoNotifier.new);
