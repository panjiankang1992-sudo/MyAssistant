import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/providers/core_providers.dart';
import '../../../domain/models/routine.dart';
import '../../../domain/models/todo.dart';
import '../../bookkeeping/bookkeeping_action_service.dart';
import '../../calendar/calendar_todo_service.dart';
import 'selected_date_provider.dart';

class TodoNotifier extends Notifier<List<Todo>> {
  DateTime? _lastCalendarImportAt;
  bool _remindersInitialized = false;

  @override
  List<Todo> build() {
    final selectedDate = ref.watch(selectedDateProvider);
    _loadTodosForDate(selectedDate);
    return [];
  }

  Future<void> _loadTodosForDate(DateTime date) async {
    final repo = ref.read(todoRepoProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final lastGeneratedDate = today.add(const Duration(days: 29));

    if (!normalizedDate.isBefore(today) &&
        !normalizedDate.isAfter(lastGeneratedDate)) {
      await _generateRoutineTodos();
      await _importCalendarTodosIfNeeded();
    }

    state = await repo.getTodosByDate(normalizedDate);
    await _rescheduleUpcomingRemindersIfNeeded();
  }

  Future<CalendarImportResult> importCalendarTodos({bool force = false}) async {
    if (!force && !_shouldImportCalendar()) {
      return const CalendarImportResult(
        created: 0,
        skipped: 0,
        unsupported: false,
      );
    }
    _lastCalendarImportAt = DateTime.now();
    final service = CalendarTodoService(
      datasource: ref.read(datasourceProvider),
      todoRepository: ref.read(todoRepoProvider),
    );
    final result = await service.importUpcoming(days: 30);
    final selectedDate = ref.read(selectedDateProvider);
    state = await ref.read(todoRepoProvider).getTodosByDate(selectedDate);
    return result;
  }

  Future<void> _importCalendarTodosIfNeeded() async {
    if (!_shouldImportCalendar()) return;
    try {
      await importCalendarTodos();
    } catch (_) {
      // 日历权限或平台适配异常不应阻断代办列表加载。
    }
  }

  bool _shouldImportCalendar() {
    final last = _lastCalendarImportAt;
    if (last == null) return true;
    return DateTime.now().difference(last) >= const Duration(minutes: 10);
  }

  Future<void> _generateRoutineTodos() async {
    final routineRepo = ref.read(routineRepoProvider);
    final todoRepo = ref.read(todoRepoProvider);
    final datasource = ref.read(datasourceProvider);
    final routines = await routineRepo.getRoutines();
    if (routines.isEmpty) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Get all existing todos to check for duplicates across 30 days
    final allTodos = await datasource.getAllTodos();

    for (int offset = 0; offset < 30; offset++) {
      final date = today.add(Duration(days: offset));
      for (final routine in routines) {
        if (!routine.shouldGenerateOn(date)) continue;
        final routineId = routine.uuid;
        if (routineId == null || routineId.isEmpty) continue;

        final alreadyExists = _routineTodoAlreadyExists(
          allTodos,
          routineId,
          date,
        );
        if (alreadyExists) continue;

        final todo = Todo(
          id: const Uuid().v4(),
          title: routine.title,
          description: routine.description,
          source: 'routine',
          routineId: routineId,
          type: routine.type,
          tags: routine.tags,
          action: routine.action,
          time: routine.time,
          date: date,
          createdAt: now,
          updatedAt: now,
          priority: 0,
          reminderMinutesBefore: Todo.defaultReminderMinutesForPriority(0),
        );
        await todoRepo.addTodo(todo);
        unawaited(ref.read(todoReminderServiceProvider).schedule(todo));
      }
    }

    final selectedDate = ref.read(selectedDateProvider);
    state = await todoRepo.getTodosByDate(selectedDate);
  }

  Future<void> loadTodayTodos() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    ref.read(selectedDateProvider.notifier).date = today;
  }

  Future<void> loadSelectedDateTodos() async {
    final selectedDate = ref.read(selectedDateProvider);
    await _loadTodosForDate(selectedDate);
  }

  Future<void> addTodo(Todo todo) async {
    final repo = ref.read(todoRepoProvider);
    await repo.addTodo(todo);
    unawaited(ref.read(todoReminderServiceProvider).schedule(todo));
    final selectedDate = ref.read(selectedDateProvider);
    await _loadTodosForDate(selectedDate);
  }

  Future<void> toggleComplete(String id) async {
    final repo = ref.read(todoRepoProvider);
    await repo.toggleTodo(id);
    final selectedDate = ref.read(selectedDateProvider);
    await _loadTodosForDate(selectedDate);
    await _syncReminderForTodoId(id);
  }

  Future<void> deleteTodo(String id) async {
    final repo = ref.read(todoRepoProvider);
    await repo.deleteTodo(id);
    unawaited(ref.read(todoReminderServiceProvider).cancel(id));
    final selectedDate = ref.read(selectedDateProvider);
    await _loadTodosForDate(selectedDate);
  }

  Future<void> updateTodo(Todo todo) async {
    final repo = ref.read(todoRepoProvider);
    await repo.updateTodo(todo);
    unawaited(ref.read(todoReminderServiceProvider).schedule(todo));
    final selectedDate = ref.read(selectedDateProvider);
    await _loadTodosForDate(selectedDate);
  }

  Future<bool> executeTodoAction(Todo todo) async {
    if (todo.source == 'calendar') {
      final service = CalendarTodoService(
        datasource: ref.read(datasourceProvider),
        todoRepository: ref.read(todoRepoProvider),
      );
      return service.openCalendarApp();
    }
    if (todo.action == 'bookkeeping') {
      return BookkeepingActionService().createExpenseFromTodo(
        ref: ref,
        todo: todo,
      );
    }
    return false;
  }

  Future<void> updateRoutineTodos(
    Routine oldRoutine,
    Routine newRoutine,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final datasource = ref.read(datasourceProvider);

    // Rebuild upcoming generated todos for this routine from now onward.
    final oldRoutineId = oldRoutine.uuid;
    if (oldRoutineId == null || oldRoutineId.isEmpty) return;
    await datasource.softDeleteFutureRoutineTodosByRoutineId(
      oldRoutineId,
      now,
      fallbackTitle: oldRoutine.title,
    );

    for (int offset = 0; offset < 30; offset++) {
      final date = today.add(Duration(days: offset));
      if (!newRoutine.shouldGenerateOn(date)) continue;
      await _generateSingleRoutineTodo(newRoutine, date);
    }
  }

  Future<void> _generateSingleRoutineTodo(
    Routine routine,
    DateTime date,
  ) async {
    final routineId = routine.uuid;
    if (routineId == null || routineId.isEmpty) return;
    final datasource = ref.read(datasourceProvider);
    final allTodos = await datasource.getAllTodos();
    final alreadyExists = _routineTodoAlreadyExists(allTodos, routineId, date);
    if (alreadyExists) return;

    final todo = Todo(
      id: const Uuid().v4(),
      title: routine.title,
      description: routine.description,
      source: 'routine',
      routineId: routineId,
      type: routine.type,
      tags: routine.tags,
      action: routine.action,
      time: routine.time,
      date: date,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      priority: 0,
      reminderMinutesBefore: Todo.defaultReminderMinutesForPriority(0),
    );
    final repo = ref.read(todoRepoProvider);
    await repo.addTodo(todo);
    unawaited(ref.read(todoReminderServiceProvider).schedule(todo));
  }

  Future<void> _rescheduleUpcomingRemindersIfNeeded() async {
    if (_remindersInitialized) return;
    _remindersInitialized = true;
    final todos = await ref.read(datasourceProvider).getAllTodos();
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final upcoming = todos.where(
      (todo) =>
          !todo.deleted &&
          !todo.completed &&
          !todo.date.isBefore(start) &&
          todo.date.isBefore(start.add(const Duration(days: 31))),
    );
    unawaited(ref.read(todoReminderServiceProvider).rescheduleAll(upcoming));
  }

  Future<void> _syncReminderForTodoId(String id) async {
    final todos = await ref.read(datasourceProvider).getAllTodos();
    final todo = todos.where((item) => item.id == id).firstOrNull;
    final service = ref.read(todoReminderServiceProvider);
    if (todo == null || todo.completed || todo.deleted) {
      await service.cancel(id);
    } else {
      await service.schedule(todo);
    }
  }

  bool _routineTodoAlreadyExists(
    List<Todo> todos,
    String routineId,
    DateTime date,
  ) {
    return todos.any(
      (t) =>
          t.source == 'routine' &&
          !t.deleted &&
          t.routineId == routineId &&
          _isSameDay(t.date, date),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

final todoNotifierProvider = NotifierProvider<TodoNotifier, List<Todo>>(
  TodoNotifier.new,
);
