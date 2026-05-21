# Implementation Plan: WebDAV 同步策略重构

**Branch**: `004-webdav-sync-revamp` | **Date**: 2026-05-21 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/004-webdav-sync-revamp/spec.md`

## Summary

重构 WebDAV 同步引擎，从当前的按日期目录全量推送/拉取升级为**索引差分增量同步**。核心变化：双向同步（先拉后推），本地每次修改自动触发同步（乐观锁 check-then-write），Last-Write-Wins 冲突策略，软删除+30天清理。路径结构从硬编码 `user` 改为 `MyAssistant/{username}/`，6个一级目录（index、todos、bills、notes、copilot、profile），例行的数据和索引归属在 todos 模块下。

## Technical Context

**Language/Version**: Dart 3.x / Flutter 3.27+

**Primary Dependencies**: Riverpod 3.x (状态管理), Drift (SQLite ORM), build_runner (代码生成), webdav_plus (WebDAV 客户端), json_annotation (JSON 序列化)

**Storage**: Drift SQLite (本地) + WebDAV (远端)

**Testing**: flutter test (手动验证，无自动化测试框架)

**Target Platform**: macOS 优先 (Flutter desktop)，后续 Android + 鸿蒙 NEXT

**Project Type**: Flutter desktop application

**Performance Goals**: 1000 条数据同步完成 <5 秒（索引差分），首次同步 <10 秒（100 条数据）

**Constraints**: macOS ad-hoc 签名环境，`usesDataProtectionKeychain: false`，离线本地修改不受阻断

**Scale/Scope**: 单用户多设备，<5000 条待办/例行

## Constitution Check

*GATE: Constitution 模板未填写（项目初始阶段），无预设门禁。跳过。*

## Project Structure

### Documentation (this feature)

```text
specs/004-webdav-sync-revamp/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
│   └── sync-contract.md # Sync engine public API contract
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code (repository root)

```text
ai_assistant/lib/
├── core/
│   ├── database/
│   │   ├── database.dart              # Drift DB (schema v3→v4 迁移)
│   │   ├── database.g.dart
│   │   └── tables/
│   │       ├── todos_table.dart        # 新增 version, deleted 列
│   │       ├── routines_table.dart     # 新增 uuid, version, updatedAt, deleted 列
│   │       ├── change_records_table.dart  # 现有，保留
│   │       ├── sync_index_table.dart   # 现有，调整字段用途
│   │       └── device_state_table.dart # 现有，保留
│   ├── network/
│   │   └── network_monitor.dart       # 现有，用于判断自动同步时机
│   └── security/
│       └── keychain_service.dart      # 现有 WebDAV 凭据存储
├── data/
│   ├── datasources/
│   │   ├── local_datasource.dart      # 现有，新增 version 字段处理
│   │   ├── local_sync_datasource.dart # 现有，调整路径生成
│   │   └── webdav_datasource.dart     # 现有，保持 WebDAV CRUD 封装
│   └── repositories/
│       ├── todo_repository.dart       # 现有，新增 version 自增和自动同步触发
│       └── routine_repository.dart    # 现有，新增 version 自增和自动同步触发
├── domain/
│   └── models/
│       ├── todo.dart                  # 现有，新增 version, deleted
│       └── routine.dart               # 现有，新增 uuid, version, updatedAt, deleted
├── features/
│   ├── sync/
│   │   ├── sync_engine.dart           # 【重构】索引差分引擎，替换现有全量推送
│   │   ├── sync_scheduler.dart        # 【重构】自动同步调度（监听本地变更）
│   │   ├── index_manager.dart         # 【重构】索引对比 + 云端索引更新
│   │   ├── cloud_path_builder.dart    # 【修正】路径改为 MyAssistant/{username}/...
│   │   ├── conflict_resolver.dart     # 【重写】Last-Write-Wins 自动解决
│   │   ├── change_tracker.dart        # 【废弃】替换为直接在 repository 层触发
│   │   ├── webdav_provisioner.dart    # 现有，保留
│   │   └── providers/
│   │       └── sync_provider.dart     # 【重构】暴露 syncState（lastSyncTime, pullCount, pushCount）
│   ├── settings/
│   │   ├── settings_page.dart         # 【更新】展示同步状态，移除旧的全量同步按钮
│   │   └── settings_provider.dart     # 现有，保留
│   └── todo/
│       └── providers/
│           ├── todo_provider.dart     # 【更新】addTodo/updateTodo/deleteTodo 触发同步
│           └── routine_provider.dart  # 【更新】addRoutine/deleteRoutine 触发同步
```

**Structure Decision**: 单项目结构（Flutter + clean architecture）。同步逻辑集中在 `features/sync/` 模块，通过 provider 层解耦。

## Complexity Tracking

> Constitution 模板未填写，无违规需记录。

| 项 | 说明 |
|----|------|
| 数据库迁移 | v3→v4：新增 columns（version, deleted, uuid），无破坏性变更 |
| 路径硬编码删除 | `settings_page.dart`、`sync_engine.dart`、`index_manager.dart` 中 `MyAssistant/user/` 替换为 `CloudPathBuilder` 统一管理 |
| 废弃代码 | `change_tracker.dart` 替换为 repository 层直接调用 `SyncScheduler` |
