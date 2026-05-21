import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'my_app.dart';
import 'core/database/database.dart';
import 'data/datasources/local_datasource.dart';
import 'data/repositories/todo_repository.dart';
import 'data/repositories/routine_repository.dart';

final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase());
final datasourceProvider = Provider<LocalDatasource>((ref) => LocalDatasource(ref.watch(databaseProvider)));
final todoRepoProvider = Provider<TodoRepository>((ref) => TodoRepository(ref.watch(datasourceProvider)));
final routineRepoProvider = Provider<RoutineRepository>((ref) => RoutineRepository(ref.watch(datasourceProvider)));

void main() {
  runApp(const ProviderScope(child: App()));
}
