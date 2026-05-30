# Implementation Plan: WebDAV 同步策略重构

**Branch**: `004-webdav-sync-revamp` | **Revised**: 2026-05-29 | **Spec**: [spec.md](./spec.md)

## Summary

将 WebDAV 同步改为独立数据层模块：用户配置 WebDAV 时保存远端同步目录，云端根为 `用户指定目录/MyAssistant/`；同步模块通过数据库触发器/表变化监听自动把业务表变更写入 `sync_data`，再统一执行上传/下载。业务 repository 不再调用同步队列 API。同步引擎下载远端数据时使用 `sync_control` 静默上下文，避免把远端覆盖误判为本地新增上传。

随手记日记/文档/归档与 Copilot 聊天中的图片、录音、文件等附件统一拆入 `attachments` 表，业务实体只保存附件 ID。附件云端使用 base64 JSON 文件同步，单个附件限制 20MB，并在每轮同步中最后处理。

## Technical Context

**Language/Version**: Dart 3.x / Flutter 3.41.7

**Primary Dependencies**: Riverpod 3.x, Drift, build_runner, webdav_plus

**Storage**: Drift SQLite + WebDAV JSON 文件

**Testing**: `flutter analyze`, `flutter test`

**Target Platform**: macOS 优先，Android + 鸿蒙 NEXT 后续验证

**Performance Goals**: 1000 条实体、10 条变更时只传输相关 index 和实体文件；常规增量同步 <5 秒

**Constraints**: 离线可用；WebDAV 失败不阻断本地操作；自动同步周期为 10 分钟

## Architecture

```text
业务表 CUD
   │
   ▼
SQLite Trigger / Drift table monitor
   │  排除 sync_control.muted=true 的同步写入
   ▼
sync_data(upload/download queue)
   │
   ▼
DataSyncService
   │  监听队列 + 10 分钟周期 + app 启动 + 手动同步
   ▼
SyncEngine
   ├─ pull sync/sync_index.json
   ├─ pull changed index files
   ├─ enqueue download tasks
   ├─ runMuted(download entity -> local tables)
   ├─ consume upload tasks
   ├─ consume attachment tasks last
   ├─ upload entity index files
   └─ upload sync/sync_index.json
```

## Project Structure

```text
ai_assistant/lib/
├── core/
│   ├── database/
│   │   ├── database.dart
│   │   └── tables/
│   │       ├── sync_files_table.dart      # local table name: sync
│   │       ├── sync_index_table.dart
│   │       ├── sync_data_table.dart
│   │       ├── sync_control_table.dart
│   │       └── attachments_table.dart
│   └── security/
│       └── keychain_service.dart          # WebDAV credential + sync root
├── data/
│   └── datasources/
│       ├── local_datasource.dart
│       ├── local_sync_datasource.dart
│       └── webdav_datasource.dart
└── features/
    ├── sync/
    │   ├── cloud_path_builder.dart
    │   ├── data_sync_service.dart
    │   ├── sync_engine.dart
    │   └── providers/sync_provider.dart
    └── settings/settings_page.dart
```

## Implementation Decisions

| Decision | Rationale |
|----------|-----------|
| DB triggers for table changes | Keeps sync module independent from business repositories |
| `sync_control.muted` | Prevents remote downloads from enqueueing upload tasks |
| `sync_data` as durable queue | Retries survive app restart and network failures |
| User-selected WebDAV root | Matches user ownership and avoids hardcoded username paths |
| `sync/sync_index.json` manifest | Avoids scanning every index directory on each sync |
| Dedicated `attachments` table | Notes/Copilot records can reference stable IDs while large base64 payloads sync independently and last |

## Current Implementation Status

- Added local `sync`, `sync_index`, `sync_data`, `sync_control` schema support.
- Added triggers for current Drift-backed sync tables: `todos`, `routines`, `tags`, `metadata_options`.
- Removed repository-level explicit sync queue calls for todo/routine/tag.
- Added WebDAV sync directory field to settings and saved it locally.
- Updated path builder to generate `{root}/MyAssistant/...`.
- Added queue-driven upload/download foundation in `SyncEngine`.
- Added `attachments` table/model, 20MB validation, base64 cloud envelope, attachment index path, and attachment-last task ordering.
- Updated the notes editor so picked images/files are stored as attachment rows; note content keeps text/snapshots while `QuickNote.attachmentIds` carries attachment references.

## Remaining Work

- Migrate file-backed modules (`bills`, `notes`, `copilot`, `profile`) into sync-owned tables or a generic local entity store.
- Wire Copilot chat attachment picker/input flow into the `attachments` table.
- Add a one-time migration for legacy note content that already contains `[图片]`/`[附件]` local path blocks.
- Add conflict backup table/flow before overwriting local records.
- Expand triggers/index mapping for every new sync-owned table.
- Run real WebDAV two-device/manual verification.
