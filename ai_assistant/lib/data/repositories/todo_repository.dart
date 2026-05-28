import '../../domain/models/todo.dart';
import '../datasources/local_datasource.dart';
import '../../features/sync/data_sync_service.dart';

class TodoRepository {
  final LocalDatasource _datasource;
  final DataSyncService? _syncService;

  TodoRepository(this._datasource, {DataSyncService? syncService})
    : _syncService = syncService;

  Future<List<Todo>> getTodayTodos() async {
    return _datasource.getTodosByDate(DateTime.now());
  }

  Future<List<Todo>> getTodosByDate(DateTime date) async {
    return _datasource.getTodosByDate(date);
  }

  Future<void> addTodo(Todo todo) async {
    await _datasource.insertTodo(todo);
    await _markDirty(todo, 'upsert');
  }

  Future<void> updateTodo(Todo todo) async {
    final next = todo.copyWith(
      version: todo.version + 1,
      updatedAt: DateTime.now(),
    );
    await _datasource.updateTodo(next);
    await _markDirty(next, 'upsert');
  }

  Future<void> toggleTodo(String id) async {
    final todos = await _datasource.getAllTodos();
    final todo = todos.firstWhere((t) => t.id == id);
    await _datasource.toggleComplete(id, !todo.completed);
    await _markDirty(
      todo.copyWith(
        completed: !todo.completed,
        version: todo.version + 1,
        updatedAt: DateTime.now(),
      ),
      'upsert',
    );
  }

  Future<void> deleteTodo(String id) async {
    final todos = await _datasource.getAllTodos();
    final todo = todos.where((t) => t.id == id).firstOrNull;
    await _datasource.softDeleteTodo(id);
    await _syncService?.markDirty(
      DataSyncType.todo,
      id,
      operation: 'delete',
      version: (todo?.version ?? 0) + 1,
    );
  }

  Future<void> deleteFutureRoutineTodos(
    String routineTitle,
    DateTime cutoff,
  ) async {
    await _datasource.softDeleteFutureRoutineTodos(routineTitle, cutoff);
    await _syncService?.markDirty(
      DataSyncType.todo,
      'routine-title-$routineTitle',
      operation: 'bulk-delete',
    );
  }

  Future<void> deleteFutureRoutineTodosByRoutineId(
    String routineId,
    DateTime cutoff, {
    String? fallbackTitle,
  }) async {
    await _datasource.softDeleteFutureRoutineTodosByRoutineId(
      routineId,
      cutoff,
      fallbackTitle: fallbackTitle,
    );
    await _syncService?.markDirty(
      DataSyncType.todo,
      'routine-$routineId',
      operation: 'bulk-delete',
    );
  }

  Future<void> _markDirty(Todo todo, String operation) async {
    await _syncService?.markDirty(
      DataSyncType.todo,
      todo.id,
      operation: operation,
      version: todo.version,
      payload: {
        'title': todo.title,
        'updatedAt': todo.updatedAt.toIso8601String(),
        'reminderEnabled': todo.reminderEnabled,
        'reminderMinutesBefore': todo.reminderMinutesBefore,
      },
    );
  }
}
