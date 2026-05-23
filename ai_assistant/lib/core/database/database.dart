import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'tables/todos_table.dart';
import 'tables/routines_table.dart';
import 'tables/change_records_table.dart';
import 'tables/sync_index_table.dart';
import 'tables/device_state_table.dart';
import 'tables/tags_table.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Todos, Routines, ChangeRecords, SyncIndex, DeviceSyncState, Tags])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 5;

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
      if (from < 5) {
        await migrator.createTable(tags);
        await customStatement(
          'ALTER TABLE todos ADD COLUMN tags TEXT NOT NULL DEFAULT \'[]\'',
        );
        await customStatement(
          'ALTER TABLE routines ADD COLUMN tags TEXT NOT NULL DEFAULT \'[]\'',
        );
        await customStatement(
          'INSERT INTO tags (id, name, color_key, sort_order, is_preset) VALUES '
          '(\'tag-preset-personal\', \'个人\', \'purple\', 0, 1), '
          '(\'tag-preset-work\', \'工作\', \'blue\', 1, 1), '
          '(\'tag-preset-bill\', \'账单\', \'pink\', 2, 1), '
          '(\'tag-preset-health\', \'健康\', \'green\', 3, 1)',
        );
        await customStatement(
          'UPDATE todos SET tags = \'["tag-preset-personal"]\' WHERE type = \'personal\'',
        );
        await customStatement(
          'UPDATE todos SET tags = \'["tag-preset-work"]\' WHERE type = \'work\'',
        );
        await customStatement(
          'UPDATE todos SET tags = \'["tag-preset-bill"]\' WHERE type = \'bill\'',
        );
        await customStatement(
          'UPDATE todos SET tags = \'["tag-preset-health"]\' WHERE type = \'health\'',
        );
        await customStatement(
          'UPDATE todos SET tags = \'[]\' WHERE type NOT IN (\'personal\', \'work\', \'bill\', \'health\')',
        );
        await customStatement(
          'UPDATE routines SET tags = \'["tag-preset-personal"]\' WHERE type = \'personal\'',
        );
        await customStatement(
          'UPDATE routines SET tags = \'["tag-preset-work"]\' WHERE type = \'work\'',
        );
        await customStatement(
          'UPDATE routines SET tags = \'["tag-preset-bill"]\' WHERE type = \'bill\'',
        );
        await customStatement(
          'UPDATE routines SET tags = \'["tag-preset-health"]\' WHERE type = \'health\'',
        );
        await customStatement(
          'UPDATE routines SET tags = \'[]\' WHERE type NOT IN (\'personal\', \'work\', \'bill\', \'health\')',
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