# Data Model: WebDAV 同步策略重构

**Revised**: 2026-05-29

## Local Tables

### sync

本地 `sync` 表与云端 `sync/sync_index.json` 语义一致，记录所有 index 文件的同步摘要。

| 字段 | 类型 | 说明 |
|------|------|------|
| `cloud_path` | TEXT PK | index 文件云端路径 |
| `module` | TEXT | todos / bills / notes / copilot / profile |
| `index_name` | TEXT | 如 `todos_index.json` |
| `last_modified_device` | TEXT | 最后修改设备 |
| `updated_at` | DATETIME | index 文件最后修改时间 |

### sync_index

本地实体索引表，与云端 `index/**.json` 条目一致。

| 字段 | 类型 | 说明 |
|------|------|------|
| `data_id` | TEXT PK(part) | 实体 UUID |
| `data_type` | TEXT PK(part) | todo / routine / bill / category / note 等 |
| `local_version` | INT | 本地版本 |
| `cloud_version` | INT | 已知云端版本 |
| `updated_at` | DATETIME | 本地最后修改时间 |
| `sync_status` | TEXT | synced / pending_upload / conflict |
| `sync_index_path` | TEXT | 对应 index 文件路径 |
| `cloud_path` | TEXT | 实体云端文件路径 |
| `last_modified_device` | TEXT | 最后修改设备 |
| `cloud_updated_at` | DATETIME | 已知云端最后修改时间 |
| `is_deleted` | BOOL | 软删除标记 |

### sync_data

同步任务队列。

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | INTEGER PK | 任务 ID |
| `sync_index_id` | TEXT | 对应 sync_index 逻辑 ID |
| `data_id` | TEXT | 实体 ID |
| `local_table` | TEXT | 本地表名 |
| `cloud_path` | TEXT | 实体云端文件路径，上传前可为空 |
| `operation_type` | TEXT | upload / download |
| `is_completed` | BOOL | 是否完成 |
| `status` | TEXT | pending / completed / error |
| `error` | TEXT | 异常信息 |
| `updated_at` | DATETIME | 最后更新时间 |

### sync_control

同步模块写库静默控制。

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | TEXT PK | 固定 `default` |
| `muted` | BOOL | true 时触发器不写入 `sync_data` |
| `updated_at` | DATETIME | 更新时间 |

### attachments

随手记中的日记、文档、归档，以及 Copilot 聊天记录中的图片、录音、文件等附件统一落到独立附件表。业务实体表只保存附件 ID 列表，不直接保存附件二进制或 base64 内容。

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | TEXT PK | 附件 UUID |
| `owner_type` | TEXT | diary / note / archive / chat / archive_chat |
| `owner_id` | TEXT | 所属业务实体 ID |
| `attachment_type` | TEXT | image / audio / file 等 |
| `file_name` | TEXT | 原始文件名 |
| `mime_type` | TEXT NULL | MIME 类型 |
| `size_bytes` | INT | 原始附件大小，单个附件不得超过 20MB |
| `content_base64` | TEXT | base64 编码后的附件内容 |
| `created_at` | DATETIME | 创建时间 |
| `updated_at` | DATETIME | 最后修改时间 |
| `is_deleted` | BOOL | 软删除标记 |

## Entity Tables

所有可同步实体/配置表必须包含：

| 字段 | 说明 |
|------|------|
| 实体 ID | UUID 或雪花 ID |
| `is_deleted`/`deleted` | 软删除 |
| `created_at`/`createdAt` | 创建时间 |
| `updated_at`/`updatedAt` | 最后修改时间 |

展示时间必须使用单独字段，例如待办 `date`、账单 `date`、日记 `date`，不得复用创建时间。

当前代码已覆盖 Drift 表：`todos`、`routines`、`tags`、`metadata_options`、`attachments`。账单、随手记、Copilot、Profile 中仍使用 JSON 文件/本地存储的部分，需要迁移为表或由同步模块统一托管；日记/文档/归档/Copilot chat 迁移后只记录 `attachmentIds`。

## Cloud JSON

实体文件统一信封：

```json
{
  "id": "uuid",
  "type": "todo",
  "version": 3,
  "is_deleted": false,
  "created_at": "2026-05-29T10:00:00.000Z",
  "updated_at": "2026-05-29T11:00:00.000Z",
  "data": {
    "title": "买牛奶",
    "date": "2026-05-29"
  }
}
```

现有 Dart 模型仍保留 camelCase 字段，序列化层负责兼容 `createdAt/updatedAt/deleted` 和 `created_at/updated_at/is_deleted`。

附件实体文件也使用同一信封，`data.contentBase64` 保存 base64 内容，下载和上传前都必须校验 `sizeBytes <= 20MB`。

```json
{
  "id": "attachment-uuid",
  "type": "attachment",
  "version": 1,
  "is_deleted": false,
  "created_at": "2026-05-29T10:00:00.000Z",
  "updated_at": "2026-05-29T11:00:00.000Z",
  "data": {
    "ownerType": "diary",
    "ownerId": "diary-uuid",
    "attachmentType": "image",
    "fileName": "receipt.jpg",
    "mimeType": "image/jpeg",
    "sizeBytes": 102400,
    "contentBase64": "..."
  }
}
```

## Cloud Paths

| 类型 | 路径 |
|------|------|
| Sync manifest | `{root}/MyAssistant/sync/sync_index.json` |
| Todo index | `{root}/MyAssistant/index/todos/todos_index.json` |
| Routine index | `{root}/MyAssistant/index/todos/routine_index.json` |
| Todo | `{root}/MyAssistant/todos/{YYYY}/{YYYY-MM}/{YYYY-MM-DD}/todo_{uuid}.json` |
| Routine | `{root}/MyAssistant/todos/routine/routine_{uuid}.json` |
| Bill | `{root}/MyAssistant/bills/{YYYY}/{YYYY-MM}/{YYYY-MM-DD}/bill_{uuid}.json` |
| Category | `{root}/MyAssistant/bills/category/category_{uuid}.json` |
| Note | `{root}/MyAssistant/notes/notes/note_{uuid}.json` |
| Diary | `{root}/MyAssistant/notes/{YYYY}/{YYYY-MM}/{YYYY-MM-DD}/diary_{uuid}.json` |
| Attachment index | `{root}/MyAssistant/index/attachments/attachments_index.json` |
| Attachment | `{root}/MyAssistant/attachments/{YYYY}/{YYYY-MM}/attachment_{uuid}.json` |
| Copilot memory | `{root}/MyAssistant/copilot/memory.json` |
| Profile setting | `{root}/MyAssistant/profile/*.json` |
