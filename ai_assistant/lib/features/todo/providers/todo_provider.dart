import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/providers/core_providers.dart';
import '../../../domain/models/todo.dart';
import 'selected_date_provider.dart';

class TodoNotifier extends Notifier<List<Todo>> {
  @override
  List<Todo> build() {
    final selectedDate = ref.watch(selectedDateProvider);
    _loadTodosForDate(selectedDate);
    return [];
  }

  Future<void> _loadTodosForDate(DateTime date) async {
    final repo = ref.read(todoRepoProvider);
    final todos = await repo.getTodosByDate(date);
    state = todos;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (date == today) {
      await _generateRoutineTodos();
    }
  }

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

    state = await todoRepo.getTodayTodos();
  }

  Future<void> loadTodayTodos() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    ref.read(selectedDateProvider.notifier).date = today;
  }

  Future<void> addTodo(Todo todo) async {
    final repo = ref.read(todoRepoProvider);
    await repo.addTodo(todo);
    final selectedDate = ref.read(selectedDateProvider);
    await _loadTodosForDate(selectedDate);
  }

  Future<void> toggleComplete(String id) async {
    final repo = ref.read(todoRepoProvider);
    await repo.toggleTodo(id);
    final selectedDate = ref.read(selectedDateProvider);
    await _loadTodosForDate(selectedDate);
  }

  Future<void> deleteTodo(String id) async {
    final repo = ref.read(todoRepoProvider);
    await repo.deleteTodo(id);
    final selectedDate = ref.read(selectedDateProvider);
    await _loadTodosForDate(selectedDate);
  }
}

final todoNotifierProvider = NotifierProvider<TodoNotifier, List<Todo>>(TodoNotifier.new);
