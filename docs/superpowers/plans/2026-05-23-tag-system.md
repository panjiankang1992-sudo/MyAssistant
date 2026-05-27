# 待办标签系统 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the single `type` field on todos/routines with a multi-tag system supporting custom tags, tag management, and WebDAV sync.

**Architecture:** Hybrid storage — new `tags` table stores tag metadata (synced separately), todo/routine `tags` JSON column stores full tag info inline (redundant but query-fast). Querying todos reads only the todo table; tag metadata is only needed when creating/editing.

**Tech Stack:** Flutter 3.41, Dart 3.11.5, Drift (SQLite ORM), Riverpod 3.x, webdav_plus

---

## File Structure

| File | Responsibility |
|------|---------------|
| `core/database/tables/tags_table.dart` | Drift table definition for tags |
| `domain/models/tag.dart` | Plain Dart Tag model + TagColor palette |
| `core/theme/app_theme.dart` | Add tag color palette constants |
| `core/database/database.dart` | Schema v5 migration + Tags table registration |
| `domain/models/todo.dart` | Add `tags` field, deprecate `type` |
| `domain/models/routine.dart` | Add `tags` field, deprecate `type` |
| `data/datasources/local_datasource.dart` | Tag CRUD + todo/routine mapping with tags |
| `data/repositories/tag_repository.dart` | Tag repository with sync trigger |
| `core/providers/core_providers.dart` | Register tag providers |
| `shared/widgets/tag_chip.dart` | Support colorKey-based rendering |
| `features/todo/widgets/tag_selector.dart` | Reusable tag selector widget |
| `features/todo/widgets/tag_manage_dialog.dart` | Tag management dialog |
| `features/todo/widgets/add_todo_modal.dart` | Replace dropdown with tag selector |
| `features/todo/widgets/todo_detail_modal.dart` | Replace dropdown with tag selector |
| `features/todo/widgets/routine_modal.dart` | Replace dropdown with tag selector |
| `features/todo/widgets/todo_item.dart` | Render tags from `tags` field |
| `features/todo/widgets/smart_input.dart` | Display tag names in preview |
| `features/todo/services/todo_text_parser.dart` | Return tag name instead of type string |
| `features/todo/providers/todo_provider.dart` | Pass tags instead of type |
| `features/sync/cloud_path_builder.dart` | Add tags index path |
| `features/sync/sync_engine.dart` | Add tags sync logic |

---

### Task 1: Tag Model & Color Palette

**Files:**
- Create: `ai_assistant/lib/domain/models/tag.dart`
- Modify: `ai_assistant/lib/core/theme/app_theme.dart:4-33`

- [ ] **Step 1: Create Tag model**

Create `ai_assistant/lib/domain/models/tag.dart`:

```dart
class Tag {
  final String id;
  final String name;
  final String colorKey;
  final int sortOrder;
  final bool isPreset;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Tag({
    required this.id,
    required this.name,
    required this.colorKey,
    this.sortOrder = 0,
    this.isPreset = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Tag copyWith({
    String? id,
    String? name,
    String? colorKey,
    int? sortOrder,
    bool? isPreset,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Tag(
      id: id ?? this.id,
      name: name ?? this.name,
      colorKey: colorKey ?? this.colorKey,
      sortOrder: sortOrder ?? this.sortOrder,
      isPreset: isPreset ?? this.isPreset,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'colorKey': colorKey,
    'sortOrder': sortOrder,
    'isPreset': isPreset,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Tag.fromJson(Map<String, dynamic> json) => Tag(
    id: json['id'] as String,
    name: json['name'] as String,
    colorKey: json['colorKey'] as String,
    sortOrder: json['sortOrder'] as int? ?? 0,
    isPreset: json['isPreset'] as bool? ?? false,
    createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'] as String) : DateTime.now(),
    updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt'] as String) : DateTime.now(),
  );

  /// Compact JSON for embedding in todo.tags field (id + name + colorKey only)
  Map<String, dynamic> toCompactJson() => {
    'id': id,
    'name': name,
    'colorKey': colorKey,
  };

  static Tag fromCompactJson(Map<String, dynamic> json) => Tag(
    id: json['id'] as String,
    name: json['name'] as String,
    colorKey: json['colorKey'] as String,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}

class TagPalette {
  static const Map<String, ({Color bg, Color text})> colors = {
    'blue': (bg: Color(0xFFE8F2FD), text: Color(0xFF4A90D9)),
    'purple': (bg: Color(0xFFF3E8FF), text: Color(0xFFAF52DE)),
    'pink': (bg: Color(0xFFFCE4EC), text: Color(0xFFE91E63)),
    'green': (bg: Color(0xFFE8FAF3), text: Color(0xFF1ABC9C)),
    'orange': (bg: Color(0xFFFEF3E0), text: Color(0xFFE67E22)),
    'indigo': (bg: Color(0xFFF0E6FF), text: Color(0xFF7C3AED)),
    'lime': (bg: Color(0xFFEAF5EA), text: Color(0xFF27AE60)),
    'sky': (bg: Color(0xFFE3F2FD), text: Color(0xFF2196F3)),
  };

  static Color bgColor(String colorKey) => colors[colorKey]?.bg ?? const Color(0xFFF0F0F5);
  static Color textColor(String colorKey) => colors[colorKey]?.text ?? const Color(0xFF636366);
  static List<String> get keys => colors.keys.toList();
}
```

- [ ] **Step 2: Add tag color imports to app_theme.dart**

No changes needed to `app_theme.dart` — the color palette is self-contained in `TagPalette`. The existing `AppColors.billBg`, `AppColors.workBg` etc. remain for source-type TagChip backward compatibility.

- [ ] **Step 3: Commit**

```bash
cd ai_assistant
git add lib/domain/models/tag.dart
git commit -m "feat: add Tag model and TagPalette with 8-color palette"
```

---

### Task 2: Database Schema — Tags Table + Migration

**Files:**
- Create: `ai_assistant/lib/core/database/tables/tags_table.dart`
- Modify: `ai_assistant/lib/core/database/tables/todos_table.dart` (add tags column)
- Modify: `ai_assistant/lib/core/database/tables/routines_table.dart` (add tags column)
- Modify: `ai_assistant/lib/core/database/database.dart` (migration + table registration)

- [ ] **Step 1: Create tags_table.dart**

Create `ai_assistant/lib/core/database/tables/tags_table.dart`:

```dart
import 'package:drift/drift.dart';

class Tags extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get colorKey => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isPreset => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
```

- [ ] **Step 2: Add tags column to todos_table.dart**

Add after line 8 (`TextColumn get type => text()();`):

```dart
TextColumn get tags => text().withDefault(const Constant('[]'))();
```

- [ ] **Step 3: Add tags column to routines_table.dart**

Add after line 8 (`TextColumn get type => text()();`):

```dart
TextColumn get tags => text().withDefault(const Constant('[]'))();
```

- [ ] **Step 4: Update database.dart — add Tags table + schema v5 migration**

Replace the entire `database.dart` with:

```dart
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';

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
        await customStatement('ALTER TABLE todos ADD COLUMN tags TEXT NOT NULL DEFAULT \'[]\'');
        await customStatement('ALTER TABLE routines ADD COLUMN tags TEXT NOT NULL DEFAULT \'[]\'');
        // Insert preset tags with deterministic UUIDs
        await customStatement('INSERT INTO tags (id, name, color_key, sort_order, is_preset) VALUES (\'tag-preset-personal\', \'个人\', \'purple\', 0, 1)');
        await customStatement('INSERT INTO tags (id, name, color_key, sort_order, is_preset) VALUES (\'tag-preset-work\', \'工作\', \'blue\', 1, 1)');
        await customStatement('INSERT INTO tags (id, name, color_key, sort_order, is_preset) VALUES (\'tag-preset-bill\', \'账单\', \'pink\', 2, 1)');
        await customStatement('INSERT INTO tags (id, name, color_key, sort_order, is_preset) VALUES (\'tag-preset-health\', \'健康\', \'green\', 3, 1)');
        // Migrate todo type → tags
        await customStatement('UPDATE todos SET tags = \'[{"id":"tag-preset-personal","name":"个人","colorKey":"purple"}]\' WHERE type = \'personal\' AND tags = \'[]\'');
        await customStatement('UPDATE todos SET tags = \'[{"id":"tag-preset-work","name":"工作","colorKey":"blue"}]\' WHERE type = \'work\' AND tags = \'[]\'');
        await customStatement('UPDATE todos SET tags = \'[{"id":"tag-preset-bill","name":"账单","colorKey":"pink"}]\' WHERE type = \'bill\' AND tags = \'[]\'');
        await customStatement('UPDATE todos SET tags = \'[{"id":"tag-preset-health","name":"健康","colorKey":"green"}]\' WHERE type = \'health\' AND tags = \'[]\'');
        await customStatement('UPDATE todos SET tags = \'[{"id":"tag-preset-personal","name":"个人","colorKey":"purple"}]\' WHERE type NOT IN (\'personal\',\'work\',\'bill\',\'health\') AND tags = \'[]\'');
        // Migrate routine type → tags
        await customStatement('UPDATE routines SET tags = \'[{"id":"tag-preset-personal","name":"个人","colorKey":"purple"}]\' WHERE type = \'personal\' AND tags = \'[]\'');
        await customStatement('UPDATE routines SET tags = \'[{"id":"tag-preset-work","name":"工作","colorKey":"blue"}]\' WHERE type = \'work\' AND tags = \'[]\'');
        await customStatement('UPDATE routines SET tags = \'[{"id":"tag-preset-bill","name":"账单","colorKey":"pink"}]\' WHERE type = \'bill\' AND tags = \'[]\'');
        await customStatement('UPDATE routines SET tags = \'[{"id":"tag-preset-health","name":"健康","colorKey":"green"}]\' WHERE type = \'health\' AND tags = \'[]\'');
        await customStatement('UPDATE routines SET tags = \'[{"id":"tag-preset-personal","name":"个人","colorKey":"purple"}]\' WHERE type NOT IN (\'personal\',\'work\',\'bill\',\'health\') AND tags = \'[]\'');
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
```

- [ ] **Step 5: Regenerate Drift code**

Run: `cd ai_assistant && dart run build_runner build --delete-conflicting-outputs`
Expected: Build succeeds, `database.g.dart` regenerated with Tags table

- [ ] **Step 6: Commit**

```bash
cd ai_assistant
git add lib/core/database/tables/tags_table.dart lib/core/database/tables/todos_table.dart lib/core/database/tables/routines_table.dart lib/core/database/database.dart
git commit -m "feat: add Tags table, tags column, and schema v5 migration"
```

---

### Task 3: Todo & Routine Models — Add tags field

**Files:**
- Modify: `ai_assistant/lib/domain/models/todo.dart`
- Modify: `ai_assistant/lib/domain/models/routine.dart`

- [ ] **Step 1: Add tags field to Todo model**

In `ai_assistant/lib/domain/models/todo.dart`, add import and tags field. Replace the entire file:

```dart
import 'tag.dart';

class Todo {
  final String id;
  final String title;
  final String? description;
  final String source;
  final String type;
  final List<Tag> tags;
  final String time;
  final DateTime date;
  final bool completed;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;
  final bool deleted;

  const Todo({
    required this.id,
    required this.title,
    this.description,
    required this.source,
    required this.type,
    this.tags = const [],
    required this.time,
    required this.date,
    this.completed = false,
    required this.createdAt,
    required this.updatedAt,
    this.version = 1,
    this.deleted = false,
  });

  Todo copyWith({
    String? id,
    String? title,
    String? description,
    String? source,
    String? type,
    List<Tag>? tags,
    String? time,
    DateTime? date,
    bool? completed,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? version,
    bool? deleted,
  }) {
    return Todo(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      source: source ?? this.source,
      type: type ?? this.type,
      tags: tags ?? this.tags,
      time: time ?? this.time,
      date: date ?? this.date,
      completed: completed ?? this.completed,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
      deleted: deleted ?? this.deleted,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Todo && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
```

- [ ] **Step 2: Add tags field to Routine model**

In `ai_assistant/lib/domain/models/routine.dart`, add import and tags field. Replace the entire file:

```dart
import 'tag.dart';

class Routine {
  final int id;
  final String? uuid;
  final String title;
  final String? description;
  final String type;
  final List<Tag> tags;
  final String time;
  final String repeatRule;
  final String? repeatDays;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;
  final bool deleted;

  const Routine({
    required this.id,
    this.uuid,
    required this.title,
    this.description,
    required this.type,
    this.tags = const [],
    required this.time,
    this.repeatRule = 'daily',
    this.repeatDays,
    required this.createdAt,
    DateTime? updatedAt,
    this.version = 1,
    this.deleted = false,
  }) : updatedAt = updatedAt ?? createdAt;

  Routine copyWith({
    int? id,
    String? uuid,
    String? title,
    String? description,
    String? type,
    List<Tag>? tags,
    String? time,
    String? repeatRule,
    String? repeatDays,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? version,
    bool? deleted,
  }) {
    return Routine(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      tags: tags ?? this.tags,
      time: time ?? this.time,
      repeatRule: repeatRule ?? this.repeatRule,
      repeatDays: repeatDays ?? this.repeatDays,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
      deleted: deleted ?? this.deleted,
    );
  }

  bool shouldGenerateOn(DateTime date) {
    switch (repeatRule) {
      case 'daily':
        return true;
      case 'weekdays':
        return date.weekday >= 1 && date.weekday <= 5;
      case 'weekly':
        if (repeatDays == null) return true;
        final days = repeatDays!.split(',').map(int.parse).toList();
        return days.contains(date.weekday);
      case 'monthly':
        if (repeatDays == null) return true;
        final days = repeatDays!.split(',').map(int.parse).toList();
        return days.contains(date.day);
      case 'custom':
        return true;
      default:
        return true;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Routine && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
```

- [ ] **Step 3: Verify build**

Run: `cd ai_assistant && dart analyze lib/domain/models/`
Expected: No errors

- [ ] **Step 4: Commit**

```bash
cd ai_assistant
git add lib/domain/models/todo.dart lib/domain/models/routine.dart
git commit -m "feat: add tags field to Todo and Routine models"
```

---

### Task 4: LocalDatasource — Tag CRUD + Model Mapping

**Files:**
- Modify: `ai_assistant/lib/data/datasources/local_datasource.dart`

- [ ] **Step 1: Add tag CRUD methods and update todo/routine mapping**

Add these imports at top of `local_datasource.dart`:

```dart
import 'dart:convert';
import '../../domain/models/tag.dart' as model_tag;
```

Add these methods to the `LocalDatasource` class:

```dart
// ── Tag CRUD ──

Future<List<model_tag.Tag>> getAllTags() async {
  final rows = await (_db.select(_db.tags)..orderBy([(t) => OrderingTerm.asc(t.sortOrder)])).get();
  return rows.map((r) => model_tag.Tag(
    id: r.id, name: r.name, colorKey: r.colorKey,
    sortOrder: r.sortOrder, isPreset: r.isPreset,
    createdAt: r.createdAt, updatedAt: r.updatedAt,
  )).toList();
}

Future<void> insertTag(model_tag.Tag tag) async {
  await _db.into(_db.tags).insertOnConflictUpdate(TagsCompanion(
    id: Value(tag.id), name: Value(tag.name), colorKey: Value(tag.colorKey),
    sortOrder: Value(tag.sortOrder), isPreset: Value(tag.isPreset),
    createdAt: Value(tag.createdAt), updatedAt: Value(tag.updatedAt),
  ));
}

Future<void> updateTag(model_tag.Tag tag) async {
  await (_db.update(_db.tags)..where((t) => t.id.equals(tag.id))).write(TagsCompanion(
    name: Value(tag.name), colorKey: Value(tag.colorKey),
    sortOrder: Value(tag.sortOrder), updatedAt: Value(DateTime.now()),
  ));
}

Future<void> deleteTag(String id) async {
  await (_db.delete(_db.tags)..where((t) => t.id.equals(id))).go();
}

// ── Tag JSON helpers ──

static String encodeTags(List<model_tag.Tag> tags) =>
  jsonEncode(tags.map((t) => t.toCompactJson()).toList());

static List<model_tag.Tag> decodeTags(String json) {
  if (json.isEmpty || json == '[]') return [];
  try {
    final list = jsonDecode(json) as List;
    return list.map((e) => model_tag.Tag.fromCompactJson(e as Map<String, dynamic>)).toList();
  } catch (_) {
    return [];
  }
}
```

Update `_mapTodo` to include tags:

```dart
model.Todo _mapTodo(Todo row) {
  return model.Todo(
    id: row.id,
    title: row.title,
    description: row.description,
    source: row.source,
    type: row.type,
    tags: decodeTags(row.tags),
    time: row.time,
    date: row.date,
    completed: row.completed,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    version: row.version,
    deleted: row.deleted,
  );
}
```

Update `_mapRoutine` to include tags:

```dart
model.Routine _mapRoutine(Routine row) {
  return model.Routine(
    id: row.id,
    uuid: row.uuid,
    title: row.title,
    description: row.description,
    type: row.type,
    tags: decodeTags(row.tags),
    time: row.time,
    repeatRule: row.repeatRule,
    repeatDays: row.repeatDays,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    version: row.version,
    deleted: row.deleted,
  );
}
```

Update `insertTodo` to write tags column:

```dart
Future<void> insertTodo(model.Todo todo) async {
  await _db.into(_db.todos).insertOnConflictUpdate(
    TodosCompanion(
      id: Value(todo.id),
      title: Value(todo.title),
      description: Value(todo.description),
      source: Value(todo.source),
      type: Value(todo.type),
      tags: Value(encodeTags(todo.tags)),
      time: Value(todo.time),
      date: Value(todo.date),
      completed: Value(todo.completed),
      createdAt: Value(todo.createdAt),
      updatedAt: Value(todo.updatedAt),
      version: Value(todo.version),
      deleted: Value(todo.deleted),
    ),
  );
}
```

Update `updateTodo` to write tags column — add `tags: Value(encodeTags(todo.tags)),` after the `type` line.

Update `insertRoutine` to write tags column — add `tags: Value(encodeTags(routine.tags)),` after the `type` line.

- [ ] **Step 2: Verify build**

Run: `cd ai_assistant && dart analyze lib/data/datasources/local_datasource.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
cd ai_assistant
git add lib/data/datasources/local_datasource.dart
git commit -m "feat: add tag CRUD and tags field mapping to LocalDatasource"
```

---

### Task 5: Tag Repository + Providers

**Files:**
- Create: `ai_assistant/lib/data/repositories/tag_repository.dart`
- Modify: `ai_assistant/lib/core/providers/core_providers.dart`

- [ ] **Step 1: Create TagRepository**

Create `ai_assistant/lib/data/repositories/tag_repository.dart`:

```dart
import 'package:uuid/uuid.dart';
import '../../domain/models/tag.dart';
import '../datasources/local_datasource.dart';

class TagRepository {
  final LocalDatasource _datasource;
  TagRepository(this._datasource);

  Future<List<Tag>> getAllTags() => _datasource.getAllTags();

  Future<Tag> addTag(String name, String colorKey) async {
    final now = DateTime.now();
    final tag = Tag(
      id: const Uuid().v4(),
      name: name,
      colorKey: colorKey,
      sortOrder: (await _datasource.getAllTags()).length,
      isPreset: false,
      createdAt: now,
      updatedAt: now,
    );
    await _datasource.insertTag(tag);
    return tag;
  }

  Future<void> updateTag(Tag tag) => _datasource.updateTag(tag);

  Future<void> deleteTag(String id) => _datasource.deleteTag(id);

  Future<void> reorderTags(List<Tag> tags) async {
    for (var i = 0; i < tags.length; i++) {
      await _datasource.updateTag(tags[i].copyWith(sortOrder: i));
    }
  }
}
```

- [ ] **Step 2: Register providers in core_providers.dart**

Add import at top of `core_providers.dart`:

```dart
import '../../data/repositories/tag_repository.dart';
```

Add providers after `routineRepoProvider`:

```dart
final tagRepoProvider = Provider<TagRepository>((ref) {
  return TagRepository(ref.watch(datasourceProvider));
});

final allTagsProvider = FutureProvider<List<Tag>>((ref) async {
  return ref.watch(tagRepoProvider).getAllTags();
});
```

Also add the Tag model import:

```dart
import '../../domain/models/tag.dart';
```

- [ ] **Step 3: Verify build**

Run: `cd ai_assistant && dart analyze lib/core/providers/core_providers.dart lib/data/repositories/tag_repository.dart`
Expected: No errors

- [ ] **Step 4: Commit**

```bash
cd ai_assistant
git add lib/data/repositories/tag_repository.dart lib/core/providers/core_providers.dart
git commit -m "feat: add TagRepository and register tag providers"
```

---

### Task 6: TagChip Update — Support colorKey

**Files:**
- Modify: `ai_assistant/lib/shared/widgets/tag_chip.dart`

- [ ] **Step 1: Update TagChip to support both legacy mode and colorKey mode**

Replace the entire `tag_chip.dart`:

```dart
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models/tag.dart';

class TagChip extends StatelessWidget {
  final String label;
  final String? colorKey;
  final Color? bgColor;
  final Color? textColor;

  /// Legacy mode: pass type + value for source/type chip colors
  const TagChip({
    super.key,
    required this.label,
    String? type,
    String? value,
  })  : colorKey = null,
        bgColor = null,
        textColor = null,
        _type = type,
        _value = value;

  /// Tag mode: pass colorKey for tag palette colors
  const TagChip.fromTag({
    super.key,
    required this.label,
    required this.colorKey,
  })  : bgColor = null,
        textColor = null,
        _type = null,
        _value = null;

  /// Custom color mode
  const TagChip.withColor({
    super.key,
    required this.label,
    required this.bgColor,
    required this.textColor,
  })  : colorKey = null,
        _type = null,
        _value = null;

  final String? _type;
  final String? _value;

  Color _getBackgroundColor() {
    if (bgColor != null) return bgColor!;
    if (colorKey != null) return TagPalette.bgColor(colorKey!);
    if (_type == 'source') {
      switch (_value) {
        case 'recommend': return AppColors.workBg;
        case 'routine': return AppColors.routineBg;
        case 'message': return AppColors.messageBg;
        case 'calendar': return AppColors.calendarBg;
        default: return AppColors.chipBg;
      }
    } else if (_type == 'type') {
      switch (_value) {
        case 'bill': return AppColors.billBg;
        case 'work': return AppColors.workBg;
        case 'personal': return AppColors.personalBg;
        case 'health': return AppColors.healthBg;
        default: return AppColors.chipBg;
      }
    }
    return AppColors.chipBg;
  }

  Color _getTextColor() {
    if (textColor != null) return textColor!;
    if (colorKey != null) return TagPalette.textColor(colorKey!);
    if (_type == 'source') {
      switch (_value) {
        case 'recommend': return AppColors.primary;
        case 'routine': return AppColors.warning;
        case 'message': return AppColors.success;
        case 'calendar': return AppColors.calendarText;
        default: return AppColors.textTertiary;
      }
    } else if (_type == 'type') {
      switch (_value) {
        case 'bill': return AppColors.billText;
        case 'work': return AppColors.primary;
        case 'personal': return AppColors.purple;
        case 'health': return AppColors.healthText;
        default: return AppColors.textTertiary;
      }
    }
    return AppColors.textTertiary;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _getBackgroundColor(),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'PingFang SC',
          fontFamilyFallback: const ['.SF Pro Text', 'system-ui', 'sans-serif'],
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: _getTextColor(),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify build**

Run: `cd ai_assistant && dart analyze lib/shared/widgets/tag_chip.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
cd ai_assistant
git add lib/shared/widgets/tag_chip.dart
git commit -m "feat: update TagChip to support colorKey-based rendering"
```

---

### Task 7: Tag Selector Widget

**Files:**
- Create: `ai_assistant/lib/features/todo/widgets/tag_selector.dart`

- [ ] **Step 1: Create tag selector widget**

Create `ai_assistant/lib/features/todo/widgets/tag_selector.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models/tag.dart';
import '../../../shared/widgets/tag_chip.dart';

class TagSelector extends ConsumerStatefulWidget {
  final List<Tag> selectedTags;
  final ValueChanged<List<Tag>> onChanged;
  final int maxTags;

  const TagSelector({
    super.key,
    required this.selectedTags,
    required this.onChanged,
    this.maxTags = 6,
  });

  @override
  ConsumerState<TagSelector> createState() => _TagSelectorState();
}

class _TagSelectorState extends ConsumerState<TagSelector> {
  bool _showMore = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleTag(Tag tag) {
    final selected = List<Tag>.from(widget.selectedTags);
    final idx = selected.indexWhere((t) => t.id == tag.id);
    if (idx >= 0) {
      selected.removeAt(idx);
    } else if (selected.length < widget.maxTags) {
      selected.add(tag);
    }
    widget.onChanged(selected);
  }

  void _removeTag(Tag tag) {
    final selected = List<Tag>.from(widget.selectedTags)..removeWhere((t) => t.id == tag.id);
    widget.onChanged(selected);
  }

  void _addTempTag(String name) {
    if (name.trim().isEmpty || name.trim().length > 6) return;
    if (widget.selectedTags.length >= widget.maxTags) return;
    final tempTag = Tag(
      id: 'temp-${name.trim()}',
      name: name.trim(),
      colorKey: 'blue',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final selected = List<Tag>.from(widget.selectedTags)..add(tempTag);
    widget.onChanged(selected);
    _searchController.clear();
    setState(() => _searchQuery = '');
  }

  @override
  Widget build(BuildContext context) {
    final tagsAsync = ref.watch(allTagsProvider);

    return tagsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (allTags) {
        final selectedIds = widget.selectedTags.map((t) => t.id).toSet();
        final availableTags = allTags.where((t) => !selectedIds.contains(t.id)).toList();
        final filteredTags = _searchQuery.isEmpty
            ? availableTags
            : availableTags.where((t) => t.name.contains(_searchQuery)).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Selected tags row
            if (widget.selectedTags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: widget.selectedTags.map((tag) => _buildSelectedChip(tag)).toList(),
                ),
              ),
            // Available tags row + more + manage
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ...availableTags.take(5).map((tag) => _buildAvailableChip(tag)),
                _buildMoreButton(),
                _buildManageButton(),
              ],
            ),
            // Expanded "more" section
            if (_showMore) ...[
              const SizedBox(height: 8),
              _buildMoreSection(filteredTags),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSelectedChip(Tag tag) {
    return GestureDetector(
      onTap: () => _removeTag(tag),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: TagPalette.bgColor(tag.colorKey),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: TagPalette.textColor(tag.colorKey).withValues(alpha: 0.5), width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tag.name, style: TextStyle(
              fontFamily: 'PingFang SC',
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: TagPalette.textColor(tag.colorKey),
            )),
            const SizedBox(width: 4),
            Icon(Icons.close, size: 14, color: TagPalette.textColor(tag.colorKey)),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailableChip(Tag tag) {
    return GestureDetector(
      onTap: widget.selectedTags.length < widget.maxTags ? () => _toggleTag(tag) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: TagPalette.bgColor(tag.colorKey),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Text(tag.name, style: TextStyle(
          fontFamily: 'PingFang SC',
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: TagPalette.textColor(tag.colorKey),
        )),
      ),
    );
  }

  Widget _buildMoreButton() {
    return GestureDetector(
      onTap: () => setState(() => _showMore = !_showMore),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.chipBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Text(_showMore ? '收起' : '更多...', style: const TextStyle(
          fontFamily: 'PingFang SC',
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        )),
      ),
    );
  }

  Widget _buildManageButton() {
    return GestureDetector(
      onTap: () => _showManageDialog(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.chipBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: const Text('管理', style: TextStyle(
          fontFamily: 'PingFang SC',
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        )),
      ),
    );
  }

  Widget _buildMoreSection(List<Tag> filteredTags) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.inputBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _searchQuery = v),
            onSubmitted: (v) {
              if (filteredTags.isEmpty && v.trim().isNotEmpty) _addTempTag(v);
            },
            decoration: InputDecoration(
              hintText: '搜索或输入新标签（回车创建）',
              hintStyle: const TextStyle(fontSize: 13, color: AppColors.textTertiary),
              prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textTertiary),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ...filteredTags.map((tag) => _buildAvailableChip(tag)),
              if (_searchQuery.isNotEmpty && filteredTags.isEmpty)
                GestureDetector(
                  onTap: () => _addTempTag(_searchQuery),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.chipBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1),
                    ),
                    child: Text('创建「${_searchQuery.length > 6 ? '${_searchQuery.substring(0, 6)}…' : _searchQuery}」', style: const TextStyle(
                      fontFamily: 'PingFang SC',
                      fontSize: 13,
                      color: AppColors.primary,
                    )),
                  ),
                ),
            ],
          ),
          if (widget.selectedTags.length >= widget.maxTags)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('最多选择$maxTags个标签', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
            ),
        ],
      ),
    );
  }

  void _showManageDialog(BuildContext context) {
    showDialog(context: context, builder: (_) => const TagManageDialog());
  }
}
```

- [ ] **Step 2: Verify build**

Run: `cd ai_assistant && dart analyze lib/features/todo/widgets/tag_selector.dart`
Expected: No errors (TagManageDialog import will be added in next task, for now it references a non-existent file)

Note: The `TagManageDialog` import at top will be resolved in Task 8. For now, comment out the import line and the `_showManageDialog` method body to pass analysis, then uncomment after Task 8.

- [ ] **Step 3: Commit**

```bash
cd ai_assistant
git add lib/features/todo/widgets/tag_selector.dart
git commit -m "feat: add TagSelector widget with more/expand/search support"
```

---

### Task 8: Tag Manage Dialog

**Files:**
- Create: `ai_assistant/lib/features/todo/widgets/tag_manage_dialog.dart`

- [ ] **Step 1: Create tag management dialog**

Create `ai_assistant/lib/features/todo/widgets/tag_manage_dialog.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models/tag.dart';

class TagManageDialog extends ConsumerStatefulWidget {
  const TagManageDialog({super.key});

  @override
  ConsumerState<TagManageDialog> createState() => _TagManageDialogState();
}

class _TagManageDialogState extends ConsumerState<TagManageDialog> {
  final _nameController = TextEditingController();
  String _selectedColorKey = 'blue';

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _addTag() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || name.length > 6) return;
    await ref.read(tagRepoProvider).addTag(name, _selectedColorKey);
    _nameController.clear();
    ref.invalidate(allTagsProvider);
  }

  Future<void> _deleteTag(Tag tag) async {
    await ref.read(tagRepoProvider).deleteTag(tag.id);
    ref.invalidate(allTagsProvider);
  }

  Future<void> _moveTag(Tag tag, int direction) async {
    final tags = await ref.read(tagRepoProvider).getAllTags();
    final idx = tags.indexWhere((t) => t.id == tag.id);
    if (idx < 0) return;
    final newIdx = idx + direction;
    if (newIdx < 0 || newIdx >= tags.length) return;
    final swapped = List<Tag>.from(tags);
    final tmp = swapped[idx];
    swapped[idx] = swapped[newIdx].copyWith(sortOrder: idx);
    swapped[newIdx] = tmp.copyWith(sortOrder: newIdx);
    await ref.read(tagRepoProvider).reorderTags(swapped);
    ref.invalidate(allTagsProvider);
  }

  Future<void> _changeColor(Tag tag, String newColorKey) async {
    await ref.read(tagRepoProvider).updateTag(tag.copyWith(colorKey: newColorKey));
    ref.invalidate(allTagsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final tagsAsync = ref.watch(allTagsProvider);

    return AlertDialog(
      title: const Text('标签管理', style: TextStyle(fontFamily: 'PingFang SC', fontWeight: FontWeight.w600)),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.85,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Add tag row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    maxLength: 6,
                    decoration: InputDecoration(
                      hintText: '标签名（最多6字）',
                      hintStyle: const TextStyle(fontSize: 13, color: AppColors.textTertiary),
                      counterText: '',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(width: 8),
                _buildColorPicker(),
                const SizedBox(width: 8),
                SizedBox(
                  height: 36,
                  child: ElevatedButton(
                    onPressed: _addTag,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('添加', style: TextStyle(fontSize: 13)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Tag list
            tagsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('加载失败: $e', style: const TextStyle(color: AppColors.danger)),
              data: (tags) => Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: tags.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) => _buildTagRow(tags[index], tags),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('完成', style: TextStyle(fontFamily: 'PingFang SC', fontSize: 15, fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }

  Widget _buildColorPicker() {
    return SizedBox(
      height: 36,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: TagPalette.keys.map((key) => GestureDetector(
          onTap: () => setState(() => _selectedColorKey = key),
          child: Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: TagPalette.bgColor(key),
              border: _selectedColorKey == key
                  ? Border.all(color: TagPalette.textColor(key), width: 2)
                  : Border.all(color: AppColors.border, width: 1),
            ),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildTagRow(Tag tag, List<Tag> allTags) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // Tag chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: TagPalette.bgColor(tag.colorKey),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(tag.name, style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: TagPalette.textColor(tag.colorKey),
            )),
          ),
          const SizedBox(width: 8),
          // Color dot (tap to change)
          GestureDetector(
            onTap: () => _showColorPicker(tag),
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: TagPalette.bgColor(tag.colorKey),
                border: Border.all(color: TagPalette.textColor(tag.colorKey).withValues(alpha: 0.3)),
              ),
            ),
          ),
          const Spacer(),
          // Up/down buttons
          GestureDetector(
            onTap: () => _moveTag(tag, -1),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.keyboard_arrow_up, size: 20, color: AppColors.textTertiary),
            ),
          ),
          GestureDetector(
            onTap: () => _moveTag(tag, 1),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.keyboard_arrow_down, size: 20, color: AppColors.textTertiary),
            ),
          ),
          // Delete button (preset tags cannot be deleted)
          if (!tag.isPreset)
            GestureDetector(
              onTap: () => _deleteTag(tag),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
              ),
            ),
        ],
      ),
    );
  }

  void _showColorPicker(Tag tag) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('选择颜色', style: TextStyle(fontSize: 14)),
        content: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: TagPalette.keys.map((key) => GestureDetector(
            onTap: () {
              _changeColor(tag, key);
              Navigator.of(ctx).pop();
            },
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: TagPalette.bgColor(key),
                border: tag.colorKey == key
                    ? Border.all(color: TagPalette.textColor(key), width: 2.5)
                    : Border.all(color: AppColors.border),
              ),
              child: tag.colorKey == key
                  ? Icon(Icons.check, size: 16, color: TagPalette.textColor(key))
                  : null,
            ),
          )).toList(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('取消')),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Uncomment TagManageDialog import in tag_selector.dart**

In `tag_selector.dart`, add the import and ensure the `_showManageDialog` method references `TagManageDialog`:

```dart
import 'tag_manage_dialog.dart';
```

- [ ] **Step 3: Verify build**

Run: `cd ai_assistant && dart analyze lib/features/todo/widgets/tag_selector.dart lib/features/todo/widgets/tag_manage_dialog.dart`
Expected: No errors

- [ ] **Step 4: Commit**

```bash
cd ai_assistant
git add lib/features/todo/widgets/tag_selector.dart lib/features/todo/widgets/tag_manage_dialog.dart
git commit -m "feat: add TagManageDialog with add/delete/reorder/color-change"
```

---

### Task 9: Replace Dropdowns with Tag Selector in All Modals

**Files:**
- Modify: `ai_assistant/lib/features/todo/widgets/add_todo_modal.dart`
- Modify: `ai_assistant/lib/features/todo/widgets/todo_detail_modal.dart`
- Modify: `ai_assistant/lib/features/todo/widgets/routine_modal.dart`

- [ ] **Step 1: Update add_todo_modal.dart**

In `add_todo_modal.dart`:
1. Add import: `import '../../../domain/models/tag.dart';` and `import 'tag_selector.dart';`
2. Replace `String _type = 'personal';` (line 41) with `List<Tag> _tags = [];`
3. Find the type dropdown section (around lines 246-280 with label '类型'). Replace the entire `_buildFormField(label: '类型', ...)` block with:

```dart
_buildFormField(
  label: '标签',
  child: TagSelector(
    selectedTags: _tags,
    onChanged: (tags) => setState(() => _tags = tags),
  ),
),
```

4. Where the Todo object is created on confirm, change `type: _type` to `type: _tags.isNotEmpty ? _tags.first.name : 'personal'` and add `tags: _tags`:

```dart
Todo(
  id: const Uuid().v4(),
  title: _title,
  description: _description,
  source: _source,
  type: _tags.isNotEmpty ? _tags.first.name : 'personal',
  tags: _tags,
  time: _time,
  date: _date,
  createdAt: now,
  updatedAt: now,
)
```

5. In the Smart Input confirm handler, after creating the result, add tag resolution. Find where `ParsedResult` is used to create a Todo, and add `tags` based on the parsed type. The `_getTypeTagIds` helper:

```dart
Tag _tagForType(String type) {
  switch (type) {
    case 'work': return const Tag(id: 'tag-preset-work', name: '工作', colorKey: 'blue', createdAt: _, updatedAt: _);
    case 'bill': return const Tag(id: 'tag-preset-bill', name: '账单', colorKey: 'pink', createdAt: _, updatedAt: _);
    case 'health': return const Tag(id: 'tag-preset-health', name: '健康', colorKey: 'green', createdAt: _, updatedAt: _);
    default: return const Tag(id: 'tag-preset-personal', name: '个人', colorKey: 'purple', createdAt: _, updatedAt: _);
  }
}
```

Note: Since Tag has `required DateTime` fields, use a factory or function instead:

```dart
Tag _tagForType(String type) {
  final now = DateTime.now();
  switch (type) {
    case 'work': return Tag(id: 'tag-preset-work', name: '工作', colorKey: 'blue', createdAt: now, updatedAt: now);
    case 'bill': return Tag(id: 'tag-preset-bill', name: '账单', colorKey: 'pink', createdAt: now, updatedAt: now);
    case 'health': return Tag(id: 'tag-preset-health', name: '健康', colorKey: 'green', createdAt: now, updatedAt: now);
    default: return Tag(id: 'tag-preset-personal', name: '个人', colorKey: 'purple', createdAt: now, updatedAt: now);
  }
}
```

Then when creating Todo from ParsedResult:

```dart
final tag = _tagForType(result.type);
Todo(
  ...
  type: result.type,
  tags: [tag],
  ...
)
```

- [ ] **Step 2: Update todo_detail_modal.dart**

In `todo_detail_modal.dart`:
1. Add imports: `import '../../../domain/models/tag.dart';` and `import 'tag_selector.dart';`
2. Replace `String _type = 'personal';` with `List<Tag> _tags = [];`
3. In `initState`, set `_tags = widget.todo.tags;`
4. Replace the type dropdown in edit mode with TagSelector
5. In view mode, replace the type TagChip with tags list:

Replace the type display in view mode (where TagChip for type is shown) with:

```dart
Wrap(
  spacing: 4,
  runSpacing: 4,
  children: widget.todo.tags.map((tag) => TagChip.fromTag(label: tag.name, colorKey: tag.colorKey)).toList(),
),
```

6. On save, update the todo with `tags: _tags`

- [ ] **Step 3: Update routine_modal.dart**

In `routine_modal.dart`:
1. Add imports: `import '../../../domain/models/tag.dart';` and `import 'tag_selector.dart';`
2. Replace `String type = 'work';` with `List<Tag> tags = [];`
3. Replace the type dropdown with TagSelector
4. Where Routine is created, add `tags: tags, type: tags.isNotEmpty ? tags.first.name : 'work'`

- [ ] **Step 4: Verify build**

Run: `cd ai_assistant && dart analyze lib/features/todo/widgets/`
Expected: No errors

- [ ] **Step 5: Commit**

```bash
cd ai_assistant
git add lib/features/todo/widgets/add_todo_modal.dart lib/features/todo/widgets/todo_detail_modal.dart lib/features/todo/widgets/routine_modal.dart
git commit -m "feat: replace type dropdowns with TagSelector in all modals"
```

---

### Task 10: Update Todo Item Display + Smart Input + Text Parser

**Files:**
- Modify: `ai_assistant/lib/features/todo/widgets/todo_item.dart`
- Modify: `ai_assistant/lib/features/todo/widgets/smart_input.dart`
- Modify: `ai_assistant/lib/features/todo/services/todo_text_parser.dart`
- Modify: `ai_assistant/lib/features/todo/providers/todo_provider.dart`

- [ ] **Step 1: Update todo_item.dart — render tags from tags field**

In `todo_item.dart`:
1. Add import: `import '../../../domain/models/tag.dart';`
2. Replace the type TagChip in the Row (around line 196) with tags from the `tags` field:

Replace:
```dart
TagChip(label: _getTypeLabel(widget.todo.type), type: 'type', value: widget.todo.type),
```

With:
```dart
...widget.todo.tags.take(3).map((tag) => Padding(
  padding: const EdgeInsets.only(right: 4),
  child: TagChip.fromTag(label: tag.name, colorKey: tag.colorKey),
)),
if (widget.todo.tags.length > 3)
  Padding(
    padding: const EdgeInsets.only(right: 4),
    child: Text('…', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
  ),
```

3. Update `_getActionStyle` to use the first tag's colorKey:

```dart
(Color, Color, String) _getActionStyle() {
  if (widget.todo.tags.isEmpty) return (AppColors.personalBg, AppColors.purple, '→');
  final colorKey = widget.todo.tags.first.colorKey;
  return (TagPalette.bgColor(colorKey), TagPalette.textColor(colorKey), '→');
}
```

Update the call site to remove the `type` argument.

4. Remove the `_getTypeLabel` method (no longer needed).

- [ ] **Step 2: Update smart_input.dart**

In `smart_input.dart`:
1. Replace the type preview row (line 175) — change `_getTypeLabel(_result!.type)` to just show the tag name directly. Since ParsedResult still has a `type` field, create a quick mapping:

Replace:
```dart
_buildPreviewRow('类型', _getTypeLabel(_result!.type)),
```

With:
```dart
_buildPreviewRow('标签', _getTypeLabel(_result!.type)),
```

Keep `_getTypeLabel` for now since ParsedResult still returns a type string. This will be cleaned up when the parser is updated.

- [ ] **Step 3: Update todo_text_parser.dart**

In `todo_text_parser.dart`:
1. No structural change needed yet. The parser returns `type` as a string ('work', 'personal', etc.), and the consuming code (add_todo_modal) maps it to tags via `_tagForType()`. This is a clean interface — the parser doesn't need to know about Tag objects.

- [ ] **Step 4: Update todo_provider.dart — pass tags for routine-generated todos**

In `todo_provider.dart`, find where routine-generated todos are created (around line 49):

```dart
final todo = Todo(
  id: const Uuid().v4(),
  title: routine.title,
  description: routine.description,
  source: 'routine',
  type: routine.type,
  tags: routine.tags,  // ADD THIS LINE
  time: routine.time,
  date: date,
  createdAt: now,
  updatedAt: now,
);
```

- [ ] **Step 5: Verify build**

Run: `cd ai_assistant && dart analyze lib/features/todo/`
Expected: No errors

- [ ] **Step 6: Commit**

```bash
cd ai_assistant
git add lib/features/todo/widgets/todo_item.dart lib/features/todo/widgets/smart_input.dart lib/features/todo/providers/todo_provider.dart
git commit -m "feat: render tags in todo list, pass tags in routine-generated todos"
```

---

### Task 11: Sync Engine — Tags Sync

**Files:**
- Modify: `ai_assistant/lib/features/sync/cloud_path_builder.dart`
- Modify: `ai_assistant/lib/features/sync/sync_engine.dart`

- [ ] **Step 1: Add tags path to CloudPathBuilder**

In `cloud_path_builder.dart`, add method:

```dart
String buildTagsIndexPath() {
  return 'MyAssistant/$username/tags/index.json';
}
```

Add to `requiredDirectories` getter:

```dart
'MyAssistant/$username/tags',
```

- [ ] **Step 2: Add tags sync methods to SyncEngine**

In `sync_engine.dart`, add import:

```dart
import '../../domain/models/tag.dart';
```

Add methods to SyncEngine:

```dart
Future<void> pushTags(List<Tag> tags) async {
  final path = _pathBuilder.buildTagsIndexPath();
  final pd = path.substring(0, path.lastIndexOf('/'));
  try { await _webdav.createDirectory(pd); } catch (_) {}
  final data = jsonEncode({
    'updatedAt': DateTime.now().toIso8601String(),
    'tags': tags.map((t) => t.toJson()).toList(),
  });
  try {
    await _webdav.putFile(path, Uint8List.fromList(utf8.encode(data)), contentType: 'application/json');
  } on Exception catch (e) {
    if (!e.toString().contains('409')) rethrow;
  }
}

Future<List<Tag>> pullTags() async {
  try {
    final path = _pathBuilder.buildTagsIndexPath();
    final bytes = await _webdav.getFile(path);
    final data = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    final list = data['tags'] as List? ?? [];
    return list.map((e) => Tag.fromJson(e as Map<String, dynamic>)).toList();
  } catch (_) {
    return [];
  }
}
```

- [ ] **Step 3: Integrate tags sync into main sync flow**

In the `sync()` method of SyncEngine, add tags push/pull around the existing logic:

```dart
Future<SyncResult> sync(String module) async {
  // Pull tags first so we have latest tag definitions
  final cloudTags = await pullTags();
  if (cloudTags.isNotEmpty) {
    for (final tag in cloudTags) {
      await _localDs.insertTag(tag);
    }
  }

  final pullCount = await _pullViaIndex(module);
  final pushCount = await _pushAll(module);

  // Push tags after todo sync
  final localTags = await _localDs.getAllTags();
  await pushTags(localTags);

  return SyncResult(
    module: module,
    pullCount: pullCount,
    pushCount: pushCount,
    timestamp: DateTime.now(),
  );
}
```

- [ ] **Step 4: Verify build**

Run: `cd ai_assistant && dart analyze lib/features/sync/`
Expected: No errors

- [ ] **Step 5: Commit**

```bash
cd ai_assistant
git add lib/features/sync/cloud_path_builder.dart lib/features/sync/sync_engine.dart
git commit -m "feat: add tags sync to cloud (push/pull tag definitions)"
```

---

### Task 12: Build, Test & Verify

**Files:**
- No new files

- [ ] **Step 1: Regenerate Drift code**

Run: `cd ai_assistant && dart run build_runner build --delete-conflicting-outputs`
Expected: Success

- [ ] **Step 2: Full analyze**

Run: `cd ai_assistant && dart analyze`
Expected: No errors

- [ ] **Step 3: Build macOS**

Run: `cd ai_assistant && flutter build macos --release`
Expected: Build success

- [ ] **Step 4: Run and verify**

Run: `cd ai_assistant && open build/macos/Build/Products/Release/ai_assistant.app`

Manual verification:
1. Open app — existing todos should still show with their migrated tags
2. Add a new todo — tag selector should appear instead of dropdown
3. Select multiple tags (up to 6)
4. Click "更多..." — expand, search, create temp tag
5. Click "管理" — add/delete/reorder/change color of tags
6. Edit an existing todo — tags should be pre-selected
7. Verify tag chips display in todo list

- [ ] **Step 5: Commit any fixes**

```bash
cd ai_assistant
git add -A
git commit -m "fix: address issues found during tag system integration testing"
```
