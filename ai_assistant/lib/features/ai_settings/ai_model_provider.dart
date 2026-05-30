import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/core_providers.dart';
import '../../domain/models/ai_model_config.dart';
import 'ai_model_store.dart';

class AiModelState {
  final List<AiModelConfig> configs;
  final String? selectedId;
  final bool loading;

  const AiModelState({
    this.configs = const [],
    this.selectedId,
    this.loading = false,
  });

  AiModelConfig? get selected {
    if (configs.isEmpty) return null;
    if (selectedId == null) return configs.first;
    return configs.where((item) => item.id == selectedId).firstOrNull ??
        configs.first;
  }

  List<AiModelConfig> get enabledConfigs =>
      configs.where((item) => item.enabled).toList();

  AiModelState copyWith({
    List<AiModelConfig>? configs,
    String? selectedId,
    bool? loading,
  }) {
    return AiModelState(
      configs: configs ?? this.configs,
      selectedId: selectedId ?? this.selectedId,
      loading: loading ?? this.loading,
    );
  }
}

class AiModelNotifier extends Notifier<AiModelState> {
  late final AiModelStore _store;

  @override
  AiModelState build() {
    _store = AiModelStore(ref.read(databaseProvider));
    Future.microtask(load);
    return const AiModelState(loading: true);
  }

  Future<void> load() async {
    final configs = await _store.getAll();
    state = AiModelState(
      configs: configs,
      selectedId:
          state.selectedId ?? (configs.isNotEmpty ? configs.first.id : null),
      loading: false,
    );
  }

  void select(String id) {
    state = state.copyWith(selectedId: id);
  }

  Future<void> upsert(AiModelConfig config) async {
    final saved = await _store.upsert(config);
    await load();
    state = state.copyWith(selectedId: saved.id);
  }

  Future<void> delete(String id) async {
    await _store.delete(id);
    await load();
  }
}

final aiModelProvider = NotifierProvider<AiModelNotifier, AiModelState>(
  AiModelNotifier.new,
);
