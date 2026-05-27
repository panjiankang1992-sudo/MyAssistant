# Data Model: 数据存储与同步机制

**Feature**: 003-data-storage-sync
**Source**: spec.md → Key Entities + Data Classification

---

## Entity: ChangeRecord（变更记录）

记录所有尚未推送到云端的本地数据变更。

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| record_id | int (auto-inc) | Yes | 主键 |
| data_id | String | Yes | 被修改数据的 ID |
| data_type | String | Yes | 数据类型标识（todo/bill/note/chat/profile） |
| operation | String | Yes | create / update / delete |
| change_content | String (JSON) | Yes | 变更内容（JSON 序列化） |
| version | int | Yes | 变更后的版本号 |
| created_at | DateTime | Yes | 变更发生时间 |
| pushed | bool | Yes | 是否已推送，默认 false |

### Drift Table

```dart
class ChangeRecords extends Table {
  IntColumn get recordId => integer().autoIncrement()();
  TextColumn get dataId => text()();
  TextColumn get dataType => text()();
  TextColumn get operation => text()();
  TextColumn get changeContent => text()();
  IntColumn get version => integer()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get pushed => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {recordId};
}
```

---

## Entity: SyncIndex（同步索引）

维护每条数据在本地和云端的版本对照。

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| data_id | String | Yes | 数据 ID（联合主键） |
| data_type | String | Yes | 数据类型（联合主键） |
| local_version | int | Yes | 本地版本号，默认 1 |
| cloud_version | int | Yes | 云端已知版本号，默认 0 |
| updated_at | DateTime | Yes | 最后更新时间 |
| sync_status | String | Yes | synced / pending_push / pending_pull / conflict |

### State Transitions

```
synced ──local modify──→ pending_push ──push success──→ synced
synced ──cloud newer────→ pending_pull ──pull & merge──→ synced
synced ──both modified──→ conflict ──resolved──────────→ synced
```

### Drift Table

```dart
class SyncIndex extends Table {
  TextColumn get dataId => text()();
  TextColumn get dataType => text()();
  IntColumn get localVersion => integer().withDefault(const Constant(1))();
  IntColumn get cloudVersion => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get syncStatus => text().withDefault(const Constant('synced'))();

  @override
  Set<Column> get primaryKey => {dataId, dataType};
}
```

---

## Entity: DeviceSyncState（设备同步状态）

记录当前设备的同步元数据。

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| device_id | String (UUID) | Yes | 设备唯一标识（主键） |
| last_sync_time | DateTime? | No | 上次完成同步的时间 |
| last_pull_time | DateTime? | No | 上次成功拉取的时间 |
| last_push_time | DateTime? | No | 上次成功推送的时间 |
| sync_errors | int | Yes | 累计同步错误数，默认 0 |

### Drift Table

```dart
class DeviceSyncState extends Table {
  TextColumn get deviceId => text()();
  DateTimeColumn get lastSyncTime => dateTime().nullable()();
  DateTimeColumn get lastPullTime => dateTime().nullable()();
  DateTimeColumn get lastPushTime => dateTime().nullable()();
  IntColumn get syncErrors => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {deviceId};
}
```

---

## Cloud File Format（云端 JSON 文件）

每个数据条目在 WebDAV 上存储为一个 JSON 文件。

```json
{
  "id": "abc123-def456",
  "type": "todo",
  "version": 5,
  "updatedAt": "2026-05-20T09:30:00Z",
  "deviceId": "dev-uuid-001",
  "data": {
    "title": "缴纳本月物业费",
    "type": "bill",
    "time": "09:00",
    "date": "2026-05-20",
    "completed": false
  },
  "deleted": false
}
```

### Index File Format

```json
{
  "type": "todo",
  "updatedAt": "2026-05-20T09:30:00Z",
  "entries": [
    {"id": "abc123", "version": 5, "updatedAt": "2026-05-20T09:30:00Z"},
    {"id": "def456", "version": 2, "updatedAt": "2026-05-19T14:00:00Z"}
  ]
}
```

---

## Entity Relationships

```
┌─────────────────┐     ┌─────────────────┐     ┌──────────────────┐
│   Main Tables    │────→│  ChangeRecord    │────→│   WebDAV Cloud   │
│ (todos, bills,   │     │ (data_id, type,  │     │ MyAssistant/{user}│
│  notes, chats,   │     │  op, version)    │     │ /{type}/{year}/   │
│  profile)        │     └─────────────────┘     │ {yearmonth}/      │
└─────────────────┘                              │ {yearmonthday}/   │
        │                                        │ {id}.json        │
        │ version                                └──────────────────┘
        ▼                                                │
┌─────────────────┐                                      │ index pull
│   SyncIndex      │←────────────────────────────────────┘
│ (data_id+type,   │
│  local_ver,      │
│  cloud_ver,      │
│  sync_status)    │
└─────────────────┘
        │
        ▼
┌──────────────────┐
│ DeviceSyncState   │
│ (device_id UUID,  │
│  last_sync_time,  │
│  sync_errors)     │
└──────────────────┘
```
