import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/core_providers.dart';
import '../../../domain/models/routine.dart';
import 'todo_provider.dart';

class RoutineNotifier extends Notifier<List<Routine>> {
  @override
  List<Routine> build() {
    loadRoutines();
    return [];
  }

  Future<void> loadRoutines() async {
    final repo = ref.read(routineRepoProvider);
    state = await repo.getRoutines();
  }

  Future<void> addRoutine(Routine routine) async {
    final repo = ref.read(routineRepoProvider);
    await repo.addRoutine(routine);
    await loadRoutines();
    // 添加例行后刷新今天待办（自动生成今天的例行待办）
    await ref.read(todoNotifierProvider.notifier).loadTodayTodos();
  }

  Future<void> deleteRoutine(int id) async {
    final repo = ref.read(routineRepoProvider);
    await repo.deleteRoutine(id);
    await loadRoutines();
  }
}

final routineNotifierProvider = NotifierProvider<RoutineNotifier, List<Routine>>(RoutineNotifier.new);
