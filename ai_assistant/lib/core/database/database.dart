import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../storage/app_paths.dart';
import 'tables/todos_table.dart';
import 'tables/routines_table.dart';
import 'tables/sync_index_table.dart';
import 'tables/tags_table.dart';
import 'tables/metadata_options_table.dart';
import 'tables/sync_files_table.dart';
import 'tables/sync_data_table.dart';
import 'tables/sync_control_table.dart';
import 'tables/attachments_table.dart';
import 'tables/bills_table.dart';
import 'tables/quick_notes_table.dart';
import 'tables/copilot_sessions_table.dart';
import 'tables/app_settings_table.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Todos,
    Routines,
    SyncIndex,
    Tags,
    MetadataOptions,
    SyncFiles,
    SyncData,
    SyncControl,
    Attachments,
    Bills,
    BillCategories,
    QuickNotes,
    CopilotSessions,
    AppSettingsRecords,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  static const _presetTags = <_PresetTag>[
    _PresetTag('tag-preset-personal', '个人', 'purple'),
    _PresetTag('tag-preset-work', '工作', 'blue'),
    _PresetTag('tag-preset-traffic', '交通', 'orange'),
    _PresetTag('tag-preset-life', '生活', 'lime'),
    _PresetTag('tag-preset-health', '健康', 'green'),
    _PresetTag('tag-preset-study', '学习', 'indigo'),
    _PresetTag('tag-preset-tech', '科技', 'sky'),
    _PresetTag('tag-preset-ai', 'AI', 'blue'),
    _PresetTag('tag-preset-bill', '账单', 'pink'),
  ];

  @override
  int get schemaVersion => 13;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await _seedMetadataOptions();
      await _seedPresetTags();
      await _installSyncTriggers();
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
        await _seedPresetTags();
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
      if (from < 10) {
        await _addColumnIfMissing(
          'todos',
          'reminder_enabled',
          'INTEGER NOT NULL DEFAULT 1',
        );
        await _addColumnIfMissing(
          'todos',
          'reminder_minutes_before',
          'INTEGER NOT NULL DEFAULT 10',
        );
        await customStatement(
          'UPDATE todos SET reminder_minutes_before = 1440 WHERE priority >= 1',
        );
      }
      if (from < 11) {
        if (!await _tableExists('sync')) {
          await migrator.createTable(syncFiles);
        }
        if (!await _tableExists('sync_data')) {
          await migrator.createTable(syncData);
        }
        if (!await _tableExists('sync_control')) {
          await migrator.createTable(syncControl);
        }
        await _addColumnIfMissing('sync_index', 'sync_index_path', 'TEXT');
        await _addColumnIfMissing('sync_index', 'cloud_path', 'TEXT');
        await _addColumnIfMissing(
          'sync_index',
          'last_modified_device',
          'TEXT NOT NULL DEFAULT \'local\'',
        );
        await _addColumnIfMissing('sync_index', 'cloud_updated_at', 'DATETIME');
        await _addColumnIfMissing(
          'sync_index',
          'is_deleted',
          'INTEGER NOT NULL DEFAULT 0',
        );
        await _installSyncTriggers();
      }
      if (from < 12) {
        if (!await _tableExists('attachments')) {
          await migrator.createTable(attachments);
        }
        await _installSyncTriggers();
      }
      if (from < 13) {
        if (!await _tableExists('bills')) {
          await migrator.createTable(bills);
        }
        if (!await _tableExists('bill_categories')) {
          await migrator.createTable(billCategories);
        }
        if (!await _tableExists('quick_notes')) {
          await migrator.createTable(quickNotes);
        }
        if (!await _tableExists('copilot_sessions')) {
          await migrator.createTable(copilotSessions);
        }
        if (!await _tableExists('app_settings')) {
          await migrator.createTable(appSettingsRecords);
        }
        await customStatement('DROP TABLE IF EXISTS change_records');
        await customStatement('DROP TABLE IF EXISTS device_sync_state');
        await _installSyncTriggers();
      }
    },
    beforeOpen: (_) async {
      if (await _tableExists('tags')) {
        await _seedPresetTags();
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
      '(\'source-sms\', \'source\', \'sms\', \'短信\', \'sms\', \'teal\', 4, 1), '
      '(\'action-none\', \'action\', \'none\', \'无动作\', \'block\', \'gray\', 0, 1), '
      '(\'action-bookkeeping\', \'action\', \'bookkeeping\', \'记账\', \'receipt\', \'orange\', 1, 1), '
      '(\'action-open-app\', \'action\', \'open_app\', \'打开应用\', \'open\', \'blue\', 2, 1), '
      '(\'action-call\', \'action\', \'call\', \'拨打电话\', \'call\', \'green\', 3, 1), '
      '(\'action-message\', \'action\', \'message\', \'发消息\', \'message\', \'purple\', 4, 1)',
    );
  }

  Future<void> _seedPresetTags() async {
    for (final tag in _presetTags) {
      await customStatement(
        'INSERT OR IGNORE INTO tags '
        '(id, name, color_key, sort_order, is_preset) '
        'VALUES (?, ?, ?, '
        '(SELECT COALESCE(MAX(sort_order) + 1, 0) FROM tags), 1)',
        [tag.id, tag.name, tag.colorKey],
      );
    }
  }

  Future<void> _installSyncTriggers() async {
    await customStatement(
      'INSERT OR IGNORE INTO sync_control (id, muted, updated_at) '
      'VALUES (\'default\', 0, CAST(strftime(\'%s\', \'now\') AS INTEGER))',
    );
    await _installUploadTriggers(
      triggerPrefix: 'todos',
      tableName: 'todos',
      dataIdExpr: 'NEW.id',
      oldDataIdExpr: 'OLD.id',
      dataTypeExpr: "'todo'",
      localVersionExpr: 'NEW.version',
      isDeletedExpr: 'NEW.deleted',
    );
    await _installUploadTriggers(
      triggerPrefix: 'routines',
      tableName: 'routines',
      dataIdExpr: 'COALESCE(NEW.uuid, CAST(NEW.id AS TEXT))',
      oldDataIdExpr: 'COALESCE(OLD.uuid, CAST(OLD.id AS TEXT))',
      dataTypeExpr: "'routine'",
      localVersionExpr: 'NEW.version',
      isDeletedExpr: 'NEW.deleted',
    );
    await _installUploadTriggers(
      triggerPrefix: 'tags',
      tableName: 'tags',
      dataIdExpr: 'NEW.id',
      oldDataIdExpr: 'OLD.id',
      dataTypeExpr: "'tag'",
      localVersionExpr: '1',
      isDeletedExpr: '0',
    );
    await _installUploadTriggers(
      triggerPrefix: 'metadata_options',
      tableName: 'metadata_options',
      dataIdExpr: 'NEW.id',
      oldDataIdExpr: 'OLD.id',
      dataTypeExpr: "'metadata'",
      localVersionExpr: '1',
      isDeletedExpr: '0',
    );
    await _installUploadTriggers(
      triggerPrefix: 'attachments',
      tableName: 'attachments',
      dataIdExpr: 'NEW.id',
      oldDataIdExpr: 'OLD.id',
      dataTypeExpr: "'attachment'",
      localVersionExpr: '1',
      isDeletedExpr: 'NEW.is_deleted',
    );
    await _installUploadTriggers(
      triggerPrefix: 'bills',
      tableName: 'bills',
      dataIdExpr: 'NEW.id',
      oldDataIdExpr: 'OLD.id',
      dataTypeExpr: "'bill'",
      localVersionExpr: 'NEW.version',
      isDeletedExpr: 'NEW.is_deleted',
    );
    await _installUploadTriggers(
      triggerPrefix: 'bill_categories',
      tableName: 'bill_categories',
      dataIdExpr: 'NEW.id',
      oldDataIdExpr: 'OLD.id',
      dataTypeExpr: "'category'",
      localVersionExpr: 'NEW.version',
      isDeletedExpr: 'NEW.is_deleted',
    );
    await _installUploadTriggers(
      triggerPrefix: 'quick_notes',
      tableName: 'quick_notes',
      dataIdExpr: 'NEW.id',
      oldDataIdExpr: 'OLD.id',
      dataTypeExpr:
          "CASE WHEN NEW.archived = 1 THEN 'archive' WHEN NEW.note_type = 'diary' THEN 'diary' ELSE 'note' END",
      oldDataTypeExpr:
          "CASE WHEN OLD.archived = 1 THEN 'archive' WHEN OLD.note_type = 'diary' THEN 'diary' ELSE 'note' END",
      localVersionExpr: 'NEW.version',
      isDeletedExpr: 'NEW.is_deleted',
    );
    await _installUploadTriggers(
      triggerPrefix: 'copilot_sessions',
      tableName: 'copilot_sessions',
      dataIdExpr: 'NEW.id',
      oldDataIdExpr: 'OLD.id',
      dataTypeExpr:
          "CASE WHEN NEW.archived = 1 THEN 'archive_chat' ELSE 'chat' END",
      oldDataTypeExpr:
          "CASE WHEN OLD.archived = 1 THEN 'archive_chat' ELSE 'chat' END",
      localVersionExpr: 'NEW.version',
      isDeletedExpr: 'NEW.is_deleted',
    );
    await _installUploadTriggers(
      triggerPrefix: 'app_settings',
      tableName: 'app_settings',
      dataIdExpr: 'NEW.id',
      oldDataIdExpr: 'OLD.id',
      dataTypeExpr: 'NEW.data_type',
      oldDataTypeExpr: 'OLD.data_type',
      localVersionExpr: 'NEW.version',
      isDeletedExpr: 'NEW.is_deleted',
    );
  }

  Future<void> _installUploadTriggers({
    required String triggerPrefix,
    required String tableName,
    required String dataIdExpr,
    required String oldDataIdExpr,
    required String dataTypeExpr,
    String? oldDataTypeExpr,
    required String localVersionExpr,
    required String isDeletedExpr,
  }) async {
    const now = 'CAST(strftime(\'%s\', \'now\') AS INTEGER)';
    const muted = '(SELECT muted FROM sync_control WHERE id = \'default\') = 0';
    final deleteDataTypeExpr = oldDataTypeExpr ?? dataTypeExpr;
    await customStatement(
      'DROP TRIGGER IF EXISTS sync_track_${triggerPrefix}_ai',
    );
    await customStatement(
      'DROP TRIGGER IF EXISTS sync_track_${triggerPrefix}_au',
    );
    await customStatement(
      'DROP TRIGGER IF EXISTS sync_track_${triggerPrefix}_ad',
    );

    await customStatement('''
      CREATE TRIGGER sync_track_${triggerPrefix}_ai
      AFTER INSERT ON $tableName
      WHEN $muted
      BEGIN
        INSERT INTO sync_index (
          data_id,
          data_type,
          local_version,
          cloud_version,
          updated_at,
          sync_status,
          sync_index_path,
          cloud_path,
          last_modified_device,
          cloud_updated_at,
          is_deleted
        )
        VALUES (
          $dataIdExpr,
          $dataTypeExpr,
          $localVersionExpr,
          0,
          $now,
          'pending_upload',
          $dataTypeExpr,
          NULL,
          'local',
          NULL,
          $isDeletedExpr
        )
        ON CONFLICT(data_id, data_type) DO UPDATE SET
          local_version = excluded.local_version,
          updated_at = excluded.updated_at,
          sync_status = 'pending_upload',
          last_modified_device = 'local',
          is_deleted = excluded.is_deleted;

        INSERT INTO sync_data (
          sync_index_id,
          data_id,
          local_table,
          cloud_path,
          operation_type,
          is_completed,
          status,
          updated_at
        )
        VALUES (
          $dataTypeExpr || ':' || $dataIdExpr,
          $dataIdExpr,
          '$tableName',
          NULL,
          'upload',
          0,
          'pending',
          $now
        );
      END
    ''');

    await customStatement('''
      CREATE TRIGGER sync_track_${triggerPrefix}_au
      AFTER UPDATE ON $tableName
      WHEN $muted
      BEGIN
        INSERT INTO sync_index (
          data_id,
          data_type,
          local_version,
          cloud_version,
          updated_at,
          sync_status,
          sync_index_path,
          cloud_path,
          last_modified_device,
          cloud_updated_at,
          is_deleted
        )
        VALUES (
          $dataIdExpr,
          $dataTypeExpr,
          $localVersionExpr,
          0,
          $now,
          'pending_upload',
          $dataTypeExpr,
          NULL,
          'local',
          NULL,
          $isDeletedExpr
        )
        ON CONFLICT(data_id, data_type) DO UPDATE SET
          local_version = excluded.local_version,
          updated_at = excluded.updated_at,
          sync_status = 'pending_upload',
          last_modified_device = 'local',
          is_deleted = excluded.is_deleted;

        INSERT INTO sync_data (
          sync_index_id,
          data_id,
          local_table,
          cloud_path,
          operation_type,
          is_completed,
          status,
          updated_at
        )
        VALUES (
          $dataTypeExpr || ':' || $dataIdExpr,
          $dataIdExpr,
          '$tableName',
          NULL,
          'upload',
          0,
          'pending',
          $now
        );
      END
    ''');

    await customStatement('''
      CREATE TRIGGER sync_track_${triggerPrefix}_ad
      AFTER DELETE ON $tableName
      WHEN $muted
      BEGIN
        INSERT INTO sync_index (
          data_id,
          data_type,
          local_version,
          cloud_version,
          updated_at,
          sync_status,
          sync_index_path,
          cloud_path,
          last_modified_device,
          cloud_updated_at,
          is_deleted
        )
        VALUES (
          $oldDataIdExpr,
          $deleteDataTypeExpr,
          1,
          0,
          $now,
          'pending_upload',
          $deleteDataTypeExpr,
          NULL,
          'local',
          NULL,
          1
        )
        ON CONFLICT(data_id, data_type) DO UPDATE SET
          updated_at = excluded.updated_at,
          sync_status = 'pending_upload',
          last_modified_device = 'local',
          is_deleted = 1;

        INSERT INTO sync_data (
          sync_index_id,
          data_id,
          local_table,
          cloud_path,
          operation_type,
          is_completed,
          status,
          updated_at
        )
        VALUES (
          $deleteDataTypeExpr || ':' || $oldDataIdExpr,
          $oldDataIdExpr,
          '$tableName',
          NULL,
          'upload',
          0,
          'pending',
          $now
        );
      END
    ''');
  }

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'ai_assistant_db',
      native: const DriftNativeOptions(
        databaseDirectory: getAppDocumentsDirectory,
        tempDirectoryPath: _sqliteTempDirectoryPath,
      ),
    );
  }
}

Future<String> _sqliteTempDirectoryPath() async {
  return (await getAppTemporaryDirectory()).path;
}

class _PresetTag {
  final String id;
  final String name;
  final String colorKey;

  const _PresetTag(this.id, this.name, this.colorKey);
}
