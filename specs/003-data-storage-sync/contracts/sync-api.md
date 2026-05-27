# Sync Engine API Contract

**Feature**: 003-data-storage-sync

---

## SyncEngine

Core orchestrator for bidirectional data sync.

### Methods

```
// Full sync cycle: pull → merge → push
Future<SyncResult> fullSync() 

// Pull only: download index → compare → download changed files → merge
Future<PullResult> pullFromCloud()

// Push only: read ChangeRecords → upload to cloud → clear pushed records
Future<PushResult> pushToCloud()

// Get current sync status
SyncStatus get status  // idle / pulling / pushing / merging / error
```

### SyncResult

```dart
class SyncResult {
  final int pulledCount;     // 从云端下载的数据条数
  final int pushedCount;     // 推送到云端的数据条数
  final int conflictCount;   // 冲突数量
  final int errorCount;      // 失败数量
  final Duration duration;   // 同步耗时
  final DateTime timestamp;
}
```

### Sync Flow (pseudocode)

```
fullSync():
  1. checkConnectivity() → if offline, skip
  2. status = pulling
  3. for each dataType in [todo, bill, note, chat, profile]:
     a. cloudIndex = webdav.getIndex(dataType)
     b. if cloudIndex == null → webdav.createIndex(本地全量)
     c. diff = compareVersions(localIndex, cloudIndex)
     d. download diff.cloudNewer files → store in temp table
     e. upload diff.localNewer files from ChangeRecords
  4. status = merging
  5. mergeTempToMain() // resolve conflicts: last-write-wins
  6. status = idle
  7. update device lastSyncTime
```

---

## WebDAV Datasource

HTTP client for WebDAV operations.

### Methods

```
// Directory listing
Future<List<String>> listDirectory(String path)

// Download file
Future<String> getFile(String path)  // returns file content as string

// Upload file
Future<void> putFile(String path, String content)

// Delete file
Future<void> deleteFile(String path)

// Create directory (recursive)
Future<void> createDirectory(String path)

// Get index file
Future<SyncIndexFile?> getIndex(String dataType)

// Update index file  
Future<void> updateIndex(String dataType, SyncIndexFile index)

// Authentication
Future<void> authenticate(String username, String password)
```

### URL Construction

```
baseUrl = "https://{server}/remote.php/dav/files/{username}/"
path = "MyAssistant/{username}/{dataType}/{year}/{yearMonth}/{yearMonthDay}/{id}.json"
fullUrl = baseUrl + path
```

### Error Handling

| HTTP Status | Action |
|-------------|--------|
| 401 | 凭据过期 → 提示重新登录 |
| 404 | 文件不存在 → 视为首次同步，创建索引 |
| 409 | 冲突 → 重试 |
| 5xx | 服务器错误 → 下次周期重试 |
| 超时 | 网络超时 → 跳过此次 |

---

## Change Tracker

Interceptor that records all data mutations.

### Integration Point

Each repository (TodoRepository, etc.) calls changeTracker after mutation:

```dart
class TodoRepository {
  final ChangeTracker _tracker;

  Future<void> addTodo(Todo todo) async {
    await _datasource.insertTodo(todo);
    await _tracker.recordChange(
      dataId: todo.id,
      dataType: 'todo',
      operation: 'create',
      version: todo.version,
      content: jsonEncode(todo),
    );
  }
}
```

### Index Manager

Compares local and cloud versions to determine sync direction.

```
compareVersions(local, cloud) → {toUpload: [...], toDownload: [...]}

Rules:
- cloud.version > local.version → toDownload
- local.version > cloud.version → toUpload
- equal → skip
- local exists, cloud not → toUpload
- cloud exists, local not → toDownload
- cloud.deleted = true, local exists → delete local
```

---

## Conflict Resolver

### Strategy: Last-Write-Wins (LWW)

```
resolve(local: Entity, cloud: Entity) → Entity

if cloud.updatedAt > local.updatedAt:
  use cloud version  // 但在云端保留冲突副本
else:
  keep local version // 本地变更更强，标记为待推送
```

### Conflict Backup

冲突发生时，在云端保存副本：`{id}_conflict_{timestamp}.json`
