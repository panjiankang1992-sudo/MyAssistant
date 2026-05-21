# Data Model: WebDAV 同步策略重构

**Phase 1 output for spec 004**

## Entity Relationship

```
Todo ───── SyncIndex (dataId, dataType='todo')
Routine ── SyncIndex (dataId='uuid', dataType='routine')
SyncIndex ── DeviceSyncState (sync metadata)
```

## Todo (待办)

| 字段 | 类型 | 约束 | 变更 |
|------|------|------|------|
| `id` | TEXT | PK, UUID v4 | 现有 |
| `title` | TEXT | NOT NULL | 现有 |
| `description` | TEXT | NULLABLE | 现有 |
| `source` | TEXT | NOT NULL | 现有 |
| `type` | TEXT | NOT NULL | 现有 |
| `time` | TEXT | NOT NULL (e.g. "08:00") | 现有 |
| `date` | DATETIME | NOT NULL | 现有 |
| `completed` | BOOL | DEFAULT false | 现有 |
| `createdAt` | DATETIME | DEFAULT now | 现有 |
| `updatedAt` | DATETIME | DEFAULT now | 现有 |
| **`version`** | **INT** | **DEFAULT 1** | **新增** |
| **`deleted`** | **BOOL** | **DEFAULT false** | **新增** |

### 状态转换

```
created (version=1, deleted=false)
   │
   ├─→ updated (version++, updatedAt=now)
   │     └─→ updated (version++, updatedAt=now) × N
   │
   └─→ deleted (version++, deleted=true, updatedAt=now)
         └─→ [本地物理删除 after 30 days sync]
```

## Routine (例行)

| 字段 | 类型 | 约束 | 变更 |
|------|------|------|------|
| `id` | INT | PK, 自增 | 现有（保留作本地主键） |
| **`uuid`** | **TEXT** | **UNIQUE, UUID v4** | **新增（同步标识）** |
| `title` | TEXT | NOT NULL | 现有 |
| `description` | TEXT | NULLABLE | 现有 |
| `type` | TEXT | NOT NULL | 现有 |
| `time` | TEXT | NOT NULL | 现有 |
| `repeatRule` | TEXT | DEFAULT 'daily' | 现有 |
| `repeatDays` | TEXT | NULLABLE | 现有 |
| `createdAt` | DATETIME | DEFAULT now | 现有 |
| **`updatedAt`** | **DATETIME** | **DEFAULT now** | **新增** |
| **`version`** | **INT** | **DEFAULT 1** | **新增** |
| **`deleted`** | **BOOL** | **DEFAULT false** | **新增** |

### 同步标识

- `uuid` 为全局唯一同步标识（WebDAV 文件名 = `{uuid}.json`）
- `id` 保留为本地自增主键，仅用于 Drift 内部关联
- 多设备同步通过 `uuid` 匹配，非 `id`

## SyncIndex (同步索引 - 本地)

| 字段 | 类型 | 约束 | 说明 |
|------|------|------|------|
| `dataId` | TEXT | PK (composite) | Todo: uuid, Routine: uuid |
| `dataType` | TEXT | PK (composite) | 'todo' 或 'routine' |
| `localVersion` | INT | DEFAULT 1 | 本地的 version |
| `cloudVersion` | INT | DEFAULT 0 | 云端最后一次已知 version |
| `updatedAt` | DATETIME | DEFAULT now | 最后同步时间 |
| `syncStatus` | TEXT | DEFAULT 'synced' | 'synced', 'pending_upload' |

### 用途
- 差分对比：`localVersion > cloudVersion` → 推送；`cloudVersion on index > cloudVersion` → 拉取
- 无需本地独立索引文件——直接使用 SyncIndex 表作为版本追踪源

## DeviceSyncState (设备同步状态)

| 字段 | 类型 | 约束 | 说明 |
|------|------|------|------|
| `deviceId` | TEXT | PK | 设备标识 |
| `lastSyncTime` | DATETIME | NULLABLE | 上次同步完成时间 |
| `syncErrors` | INT | NULLABLE | 累计同步错误次数 |

## ChangeRecords (变更记录)

> **设计变更**: 此表在 spec 004 中被废弃。同步由 Repository 层直接触发 SyncScheduler，不再需要异步记录待推送变更队列。保留表结构用于向后兼容，但不再写入新数据。

## 云端路径映射

```
MyAssistant/{username}/
├── index/
│   ├── todos/
│   │   ├── todos_index.json      # 待办索引
│   │   └── routines_index.json   # 例行索引
│   ├── bills/
│   │   └── bills_index.json      # (后续扩展)
│   ├── notes/
│   │   └── notes_index.json      # (后续扩展)
│   └── copilot/
│       └── copilot_index.json    # (后续扩展)
├── todos/
│   ├── {year}/{month}/{day}/{uuid}.json   # 待办数据
│   └── routines/
│       └── {uuid}.json                    # 例行数据
├── bills/
├── notes/
├── copilot/
└── profile/
```

### 路径生成规则

| 数据类型 | 构建方法 |
|----------|----------|
| Todo | `MyAssistant/{username}/todos/{YYYY}/{YYYYMM}/{YYYYMMDD}/{uuid}.json` |
| Routine | `MyAssistant/{username}/todos/routines/{uuid}.json` |
| Todo Index | `MyAssistant/{username}/index/todos/todos_index.json` |
| Routine Index | `MyAssistant/{username}/index/todos/routines_index.json` |

## 数据库迁移 (v3 → v4)

```sql
-- v3→v4: 同步重构 - 新增 version, deleted, uuid 字段
ALTER TABLE todos ADD COLUMN version INTEGER NOT NULL DEFAULT 1;
ALTER TABLE todos ADD COLUMN deleted INTEGER NOT NULL DEFAULT 0;

ALTER TABLE routines ADD COLUMN uuid TEXT;
ALTER TABLE routines ADD COLUMN version INTEGER NOT NULL DEFAULT 1;
ALTER TABLE routines ADD COLUMN updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE routines ADD COLUMN deleted INTEGER NOT NULL DEFAULT 0;

-- 为现有例行记录生成 UUID
UPDATE routines SET uuid = lower(hex(randomblob(4)) || '-' || hex(randomblob(2)) || '-4' || substr(hex(randomblob(2)), 2) || '-' || substr('89ab', abs(random()) % 4 + 1, 1) || substr(hex(randomblob(2)), 2) || '-' || hex(randomblob(6))) WHERE uuid IS NULL;
```

> 注意：Drift 中 BOOL 列以 INTEGER 存储（0/1），`deleted` 字段需使用 `boolColumn`。

## 云端 JSON 信封格式

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "type": "todo",
  "version": 3,
  "updatedAt": "2026-05-21T10:30:00.000Z",
  "data": {
    "title": "买牛奶",
    "description": "全脂",
    "source": "manual",
    "type": "personal",
    "time": "18:00",
    "date": "2026-05-21",
    "completed": false,
    "createdAt": "2026-05-20T08:00:00.000Z"
  },
  "deleted": false
}
```

<!-- SPECKIT END -->
