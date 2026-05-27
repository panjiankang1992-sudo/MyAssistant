import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'tables/todos_table.dart';
import 'tables/routines_table.dart';
import 'tables/change_records_table.dart';
import 'tables/sync_index_table.dart';
import 'tables/device_state_table.dart';
import 'tables/tags_table.dart';
import 'tables/metadata_options_table.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Todos,
    Routines,
    ChangeRecords,
    SyncIndex,
    DeviceSyncState,
    Tags,
    MetadataOptions,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 9;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await _seedMetadataOptions();
    },
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.createAll();
      }
      if (from < 3) {
        await _addColumnIfMissing(
          'routines',
          'repeat_rule',
          'TEXT NOT NULL DEFAULT \'daily\'',
        );
        await _addColumnIfMissing('routines', 'repeat_days', 'TEXT');
      }
      if (from < 4) {
        await _addColumnIfMissing(
          'todos',
          'version',
          'INTEGER NOT NULL DEFAULT 1',
        );
        await _addColumnIfMissing(
          'todos',
          'deleted',
          'INTEGER NOT NULL DEFAULT 0',
        );
        await _addColumnIfMissing('routines', 'uuid', 'TEXT');
        await _addColumnIfMissing(
          'routines',
          'version',
          'INTEGER NOT NULL DEFAULT 1',
        );
        await _addColumnIfMissing(
          'routines',
          'updated_at',
          'DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP',
        );
        await _addColumnIfMissing(
          'routines',
          'deleted',
          'INTEGER NOT NULL DEFAULT 0',
        );
        await customStatement(
          'UPDATE routines SET uuid = lower(hex(randomblob(4)) || \'-\' || hex(randomblob(2)) || \'-4\' || substr(hex(randomblob(2)), 2) || \'-\' || substr(\'89ab\', abs(random()) % 4 + 1, 1) || substr(hex(randomblob(2)), 2) || \'-\' || hex(randomblob(6))) WHERE uuid IS NULL',
        );
      }
      if (from < 5) {
        if (!await _tableExists('tags')) {
          await migrator.createTable(tags);
        }
        await _addColumnIfMissing(
          'todos',
          'tags',
          'TEXT NOT NULL DEFAULT \'[]\'',
        );
        await _addColumnIfMissing(
          'routines',
          'tags',
          'TEXT NOT NULL DEFAULT \'[]\'',
        );
        await customStatement(
          'INSERT OR IGNORE INTO tags (id, name, color_key, sort_order, is_preset) VALUES '
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
      if (from < 6) {
        await _addColumnIfMissing(
          'todos',
          'priority',
          'INTEGER NOT NULL DEFAULT 0',
        );
      }
      if (from < 7) {
        await _addColumnIfMissing(
          'todos',
          'action',
          'TEXT NOT NULL DEFAULT \'none\'',
        );
        await _addColumnIfMissing(
          'routines',
          'action',
          'TEXT NOT NULL DEFAULT \'none\'',
        );
      }
      if (from < 8) {
        if (!await _tableExists('metadata_options')) {
          await migrator.createTable(metadataOptions);
        }
        await _seedMetadataOptions();
      }
      if (from < 9) {
        await _addColumnIfMissing('todos', 'routine_id', 'TEXT');
        await customStatement(
          'UPDATE todos '
          'SET routine_id = ('
          '  SELECT r.uuid FROM routines r '
          '  WHERE r.deleted = 0 '
          '    AND r.uuid IS NOT NULL '
          '    AND r.title = todos.title '
          '  ORDER BY r.updated_at DESC '
          '  LIMIT 1'
          ') '
          'WHERE source = \'routine\' AND deleted = 0 AND routine_id IS NULL',
        );
      }
    },
  );

  Future<bool> _tableExists(String tableName) async {
    final rows = await customSelect(
      'SELECT name FROM sqlite_master WHERE type = ? AND name = ?',
      variables: [Variable.withString('table'), Variable.withString(tableName)],
    ).get();
    return rows.isNotEmpty;
  }

  Future<bool> _columnExists(String tableName, String columnName) async {
    final rows = await customSelect('PRAGMA table_info($tableName)').get();
    return rows.any((row) => row.read<String>('name') == columnName);
  }

  Future<void> _addColumnIfMissing(
    String tableName,
    String columnName,
    String definition,
  ) async {
    if (await _columnExists(tableName, columnName)) return;
    await customStatement(
      'ALTER TABLE $tableName ADD COLUMN $columnName $definition',
    );
  }

  Future<void> _seedMetadataOptions() async {
    await customStatement(
      'INSERT OR REPLACE INTO metadata_options '
      '(id, kind, value, label, icon_key, color_key, sort_order, is_preset) VALUES '
      '(\'source-ai\', \'source\', \'ai\', \'AI\', \'auto_awesome\', \'blue\', 0, 1), '
      '(\'source-routine\', \'source\', \'routine\', \'例行\', \'repeat\', \'orange\', 1, 1), '
      '(\'source-calendar\', \'source\', \'calendar\', \'日历\', \'event\', \'purple\', 2, 1), '
      '(\'source-message\', \'source\', \'message\', \'消息\', \'message\', \'green\', 3, 1), '
      '(\'action-none\', \'action\', \'none\', \'无动作\', \'block\', \'gray\', 0, 1), '
      '(\'action-bookkeeping\', \'action\', \'bookkeeping\', \'记账\', \'receipt\', \'orange\', 1, 1), '
      '(\'action-open-app\', \'action\', \'open_app\', \'打开应用\', \'open\', \'blue\', 2, 1), '
      '(\'action-call\', \'action\', \'call\', \'拨打电话\', \'call\', \'green\', 3, 1), '
      '(\'action-message\', \'action\', \'message\', \'发消息\', \'message\', \'purple\', 4, 1)',
    );
  }

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'ai_assistant_db',
      native: const DriftNativeOptions(
        databaseDirectory: getApplicationDocumentsDirectory,
      ),
    );
  }
}
