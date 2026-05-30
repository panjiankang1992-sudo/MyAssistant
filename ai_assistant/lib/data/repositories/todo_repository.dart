import '../../domain/models/todo.dart';
import '../datasources/local_datasource.dart';

class TodoRepository {
  final LocalDatasource _datasource;

  TodoRepository(this._datasource);

  Future<List<Todo>> getTodayTodos() async {
    return _datasource.getTodosByDate(DateTime.now());
  }

  Future<List<Todo>> getTodosByDate(DateTime date) async {
    return _datasource.getTodosByDate(date);
  }

  Future<void> addTodo(Todo todo) async {
    await _datasource.insertTodo(todo);
  }

  Future<void> updateTodo(Todo todo) async {
    final next = todo.copyWith(
      version: todo.version + 1,
      updatedAt: DateTime.now(),
    );
    await _datasource.updateTodo(next);
  }

  Future<void> toggleTodo(String id) async {
    final todos = await _datasource.getAllTodos();
    final todo = todos.firstWhere((t) => t.id == id);
    await _datasource.toggleComplete(id, !todo.completed);
  }

  Future<void> deleteTodo(String id) async {
    await _datasource.softDeleteTodo(id);
  }

  Future<void> deleteFutureRoutineTodos(
    String routineTitle,
    DateTime cutoff,
  ) async {
    await _datasource.softDeleteFutureRoutineTodos(routineTitle, cutoff);
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
  }
}
