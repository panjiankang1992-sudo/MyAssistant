import 'dart:async';
import '../../domain/models/todo.dart';
import '../datasources/local_datasource.dart';
import '../../features/sync/sync_engine.dart';

class TodoRepository {
  final LocalDatasource _datasource;
  final Future<SyncEngine?> Function() _syncEngine;

  TodoRepository(this._datasource, {Future<SyncEngine?> Function()? syncEngine})
    : _syncEngine = syncEngine ?? (() async => null);

  Future<List<Todo>> getTodayTodos() async {
    return _datasource.getTodosByDate(DateTime.now());
  }

  Future<void> addTodo(Todo todo) async {
    await _datasource.insertTodo(todo);
    _trySync();
  }

  Future<void> updateTodo(Todo todo) async {
    await _datasource.updateTodo(todo);
    _trySync();
  }

  Future<void> toggleTodo(String id) async {
    final todos = await _datasource.getAllTodos();
    final todo = todos.firstWhere((t) => t.id == id);
    await _datasource.toggleComplete(id, !todo.completed);
    _trySync();
  }

  Future<void> deleteTodo(String id) async {
    await _datasource.softDeleteTodo(id);
    _trySync();
  }

  void _trySync() {
    _syncEngine().then((engine) {
      if (engine != null) {
        engine.sync('todos');
      }
    });
  }
}
