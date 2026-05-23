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
    final todoRepo = ref.read(todoRepoProvider);
    // Find the routine title before deleting for cascade
    final routine = state.where((r) => r.id == id).firstOrNull;
    await repo.deleteRoutine(id);
    await loadRoutines();
    // Cascade: soft-delete future routine-generated todos (today's past todos kept)
    if (routine != null) {
      await todoRepo.deleteFutureRoutineTodos(routine.title, DateTime.now());
      await ref.read(todoNotifierProvider.notifier).loadTodayTodos();
    }
  }

  Future<void> updateRoutine(Routine newRoutine) async {
    final repo = ref.read(routineRepoProvider);
    final todoNotifier = ref.read(todoNotifierProvider.notifier);

    // 找到旧的 routine 用于级联判断
    final oldRoutine = state.where((r) => r.id == newRoutine.id).firstOrNull;

    // 更新 routine
    await repo.updateRoutine(newRoutine);
    await loadRoutines();

    // 级联：更新未来待办
    if (oldRoutine != null) {
      await todoNotifier.updateRoutineTodos(oldRoutine, newRoutine);
      await todoNotifier.loadTodayTodos();
    }
  }
}

final routineNotifierProvider = NotifierProvider<RoutineNotifier, List<Routine>>(RoutineNotifier.new);
