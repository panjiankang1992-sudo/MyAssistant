import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'tables/todos_table.dart';
import 'tables/routines_table.dart';
import 'tables/change_records_table.dart';
import 'tables/sync_index_table.dart';
import 'tables/device_state_table.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Todos, Routines, ChangeRecords, SyncIndex, DeviceSyncState])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.createAll();
      }
      if (from < 3) {
        await customStatement(
          'ALTER TABLE routines ADD COLUMN repeat_rule TEXT NOT NULL DEFAULT \'daily\'',
        );
        await customStatement(
          'ALTER TABLE routines ADD COLUMN repeat_days TEXT',
        );
      }
      if (from < 4) {
        await customStatement(
          'ALTER TABLE todos ADD COLUMN version INTEGER NOT NULL DEFAULT 1',
        );
        await customStatement(
          'ALTER TABLE todos ADD COLUMN deleted INTEGER NOT NULL DEFAULT 0',
        );
        await customStatement(
          'ALTER TABLE routines ADD COLUMN uuid TEXT',
        );
        await customStatement(
          'ALTER TABLE routines ADD COLUMN version INTEGER NOT NULL DEFAULT 1',
        );
        await customStatement(
          'ALTER TABLE routines ADD COLUMN updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP',
        );
        await customStatement(
          'ALTER TABLE routines ADD COLUMN deleted INTEGER NOT NULL DEFAULT 0',
        );
        await customStatement(
          'UPDATE routines SET uuid = lower(hex(randomblob(4)) || \'-\' || hex(randomblob(2)) || \'-4\' || substr(hex(randomblob(2)), 2) || \'-\' || substr(\'89ab\', abs(random()) % 4 + 1, 1) || substr(hex(randomblob(2)), 2) || \'-\' || hex(randomblob(6))) WHERE uuid IS NULL',
        );
      }
    },
  );

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'ai_assistant_db',
      native: const DriftNativeOptions(databaseDirectory: getApplicationDocumentsDirectory),
    );
  }
}