# Implementation Plan: 数据存储与同步机制

**Branch**: `003-data-storage-sync` | **Date**: 2026-05-20 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/003-data-storage-sync/spec.md`

## Summary

在现有 Flutter 项目基础上扩展双层存储架构：本地 SQLite (Drift) 管理三类数据表（主数据、变更记录、临时暂存），云端 WebDAV 按年/月/日层级存放 JSON 文件，通过索引差分实现增量双向同步。安全方面使用 Basic Auth + HTTPS + 系统 Keychain 凭据存储。

## Technical Context

**Language/Version**: Dart 3.11.5+ (Flutter 3.41.7 stable)

**Primary Dependencies**: flutter_riverpod ^3.2.1, drift ^2.33.0, http ^1.2.0, flutter_secure_storage ^9.2.0, connectivity_plus ^6.0.0, uuid ^4.4.0

**Storage**: 本地 SQLite (Drift) + 云端 WebDAV (HTTP/HTTPS JSON 文件)

**Testing**: flutter_test (widget + unit tests)

**Target Platform**: macOS 桌面优先 (Android 后续)

**Project Type**: 跨平台移动 + 桌面应用（现有项目的存储层扩展）

**Performance Goals**: 启动同步 <5s (1000 条, 10 变更), 索引文件 <100KB

**Constraints**: 离线可用, HTTPS 传输, 凭据 Keychain 存储, 10 分钟定时同步

**Scale/Scope**: 5 类主数据实体，3 张新数据表，1 个同步引擎，1 个 WebDAV 客户端

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

> 项目宪章（constitution.md）当前为模板状态，未定义具体的核心原则。本次规划按标准 Flutter 项目最佳实践执行。

| Gate | Status | Notes |
|------|--------|-------|
| Constitution defined | ⚠️ Skipped | 宪章为模板 |
| Architecture compliance | N/A | 扩展 feature-first 分层架构 |
| Testing requirements | N/A | unit test for sync engine |

**Gate Result**: PASS

## Project Structure

### Documentation (this feature)

```text
specs/003-data-storage-sync/
├── spec.md
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
│   ├── sync-api.md      # Sync engine API contract
│   └── webdav-storage.md # Cloud storage layout contract
└── tasks.md             # Phase 2 output
```

### Source Code (repository root — extending ai_assistant/)

```text
ai_assistant/lib/
├── core/
│   ├── database/
│   │   ├── database.dart               # UPDATE: add ChangeRecords, SyncIndex, DeviceState tables
│   │   └── tables/
│   │       ├── change_records_table.dart   # NEW
│   │       ├── sync_index_table.dart       # NEW
│   │       └── device_state_table.dart     # NEW
│   └── security/
│       └── keychain_service.dart           # NEW: Keychain CRUD for credentials
│
├── data/
│   ├── repositories/
│   │   └── sync_repository.dart            # NEW: sync state management
│   └── datasources/
│       ├── webdav_datasource.dart          # NEW: WebDAV HTTP client
│       └── local_sync_datasource.dart      # NEW: DB ops for sync tables
│
└── features/
    └── sync/                               # NEW: Sync feature module
        ├── sync_engine.dart                # Core sync orchestrator (pull→compare→merge→push)
        ├── sync_scheduler.dart             # 10-min timer + on-start trigger
        ├── index_manager.dart              # Index file CRUD + version comparison
        ├── conflict_resolver.dart          # Last-write-wins + conflict backup
        ├── change_tracker.dart             # Intercepts data mutations, writes ChangeRecord
        └── providers/
            └── sync_provider.dart          # Riverpod providers for sync state
```

**Structure Decision**: 在现有 feature-first 架构上新增 `features/sync/` 模块。同步引擎作为横向切面，通过 `change_tracker.dart` 拦截各数据模块的修改操作。云端 `webdav_datasource.dart` 封装 HTTP 客户端，与 `LocalDatasource` 对应。

## Complexity Tracking

| Decision | Rationale | Simpler Alternative Rejected |
|----------|-----------|------------------------------|
| 独立 sync 模块而非嵌入各 feature | 同步是横向关注点，集中管理避免代码重复 | 各 feature 各自同步（维护成本高） |
| WebDAV 直接 HTTP 而非第三方库 | 操作简单 (GET/PUT/DELETE/PROPFIND)，减少依赖 | webdav_client package（API 不稳定） |
| 变更追踪在 Repository 层拦截 | 所有数据操作经过 Repository，单点注入 | 在各 Widget/Provider 中手动记录（易遗漏） |
| 10 分钟定时器（Timer.periodic） | 简单可靠，无需 WorkManager | background_fetch（Android 专用，不跨平台） |
