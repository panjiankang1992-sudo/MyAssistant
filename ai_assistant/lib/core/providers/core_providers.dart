import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database.dart' hide Tag;
import '../security/keychain_service.dart';
import '../../data/datasources/local_datasource.dart';
import '../../data/datasources/local_sync_datasource.dart';
import '../../data/datasources/webdav_datasource.dart';
import '../../data/repositories/todo_repository.dart';
import '../../data/repositories/routine_repository.dart';
import '../../data/repositories/tag_repository.dart';
import '../../domain/models/tag.dart';
import '../../features/todo/services/todo_reminder_service.dart';
import '../../features/sync/cloud_path_builder.dart';
import '../../features/sync/data_sync_service.dart';
import '../../features/sync/providers/sync_provider.dart';
import '../../features/sync/sync_engine.dart';

final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase());
final datasourceProvider = Provider<LocalDatasource>(
  (ref) => LocalDatasource(ref.watch(databaseProvider)),
);
final localSyncDsProvider = Provider<LocalSyncDatasource>(
  (ref) => LocalSyncDatasource(ref.watch(databaseProvider)),
);

final syncEngineProvider = FutureProvider<SyncEngine?>((ref) async {
  final keychain = KeychainService();
  final lastUrl = await keychain.getLastServerUrl();
  if (lastUrl == null || lastUrl.isEmpty) return null;

  final creds = await keychain.getCredentials(lastUrl);
  if (creds == null) return null;

  final webdav = WebDavDatasource();
  await webdav.initialize(
    baseUrl: lastUrl,
    username: creds['username']!,
    password: creds['password']!,
  );

  final localDs = ref.watch(datasourceProvider);
  final localSyncDs = ref.watch(localSyncDsProvider);
  final pathBuilder = CloudPathBuilder(creds['username']!);

  return SyncEngine(localDs, localSyncDs, webdav, pathBuilder);
});

final dataSyncServiceProvider = Provider<DataSyncService>((ref) {
  final service = DataSyncService(
    engineLoader: () => ref.read(syncEngineProvider.future),
    localSync: ref.watch(localSyncDsProvider),
    notifier: ref.read(syncNotifierProvider.notifier),
  )..start();
  ref.onDispose(service.dispose);
  return service;
});

final todoRepoProvider = Provider<TodoRepository>((ref) {
  return TodoRepository(
    ref.watch(datasourceProvider),
    syncService: ref.watch(dataSyncServiceProvider),
  );
});

final routineRepoProvider = Provider<RoutineRepository>((ref) {
  return RoutineRepository(
    ref.watch(datasourceProvider),
    syncService: ref.watch(dataSyncServiceProvider),
  );
});

final tagRepoProvider = Provider<TagRepository>((ref) {
  return TagRepository(
    ref.watch(datasourceProvider),
    syncService: ref.watch(dataSyncServiceProvider),
  );
});

final todoReminderServiceProvider = Provider<TodoReminderService>((ref) {
  return const TodoReminderService();
});

final allTagsProvider = FutureProvider<List<Tag>>((ref) async {
  return ref.watch(tagRepoProvider).getAllTags();
});
