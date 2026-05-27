# Quickstart: Sync Engine Integration

**Feature**: 003-data-storage-sync

## Prerequisites

- 已完成 `002-env-todo-copilot` 的环境搭建，Flutter 项目可编译运行
- WebDAV 服务已部署（如 Nextcloud 或自建 WebDAV 服务器）
- WebDAV 服务启用了 HTTPS 和 Basic Auth

## Step 1: Add Dependencies

```yaml
# pubspec.yaml additions
dependencies:
  http: ^1.2.0
  flutter_secure_storage: ^9.2.0
  connectivity_plus: ^6.0.0
  xml: ^6.5.0  # for WebDAV PROPFIND response parsing
```

## Step 2: Create Sync Tables

Add to `lib/core/database/database.dart`:
```dart
@DriftDatabase(tables: [Todos, Routines, ChangeRecords, SyncIndex, DeviceSyncState])
class AppDatabase extends _$AppDatabase { ... }
```

Run `dart run build_runner build`.

## Step 3: Configure WebDAV Connection

1. User enters WebDAV URL + credentials in Settings
2. Credentials stored via `FlutterSecureStorage`
3. Connection tested via `GET` request to root directory

## Step 4: Initialize Sync Engine

```dart
// In main.dart or app initialization
final syncEngine = SyncEngine(
  webdav: WebDavDatasource(baseUrl, secureStorage),
  changeTracker: ChangeTracker(database),
  indexManager: IndexManager(database),
);

// Start periodic sync
SyncScheduler(syncEngine).start();
```

## Step 5: Verify

1. Add a todo item → check `ChangeRecords` table has a record
2. Wait for sync cycle → check WebDAV server for new file
3. Delete the file from WebDAV → restart app → check file re-uploaded
