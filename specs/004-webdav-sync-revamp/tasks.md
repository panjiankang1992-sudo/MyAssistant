# Tasks: WebDAV 同步策略重构

**Input**: Design documents from `/specs/004-webdav-sync-revamp/`

**Prerequisites**: plan.md (required), spec.md (required), data-model.md, contracts/sync-contract.md, research.md

**Tests**: 无自动化测试框架，手动验证（见 quickstart.md）

**Organization**: 按 User Story 分组，支持独立实现和增量交付

## Format: `[ID] [P?] [Story] Description`

- **[P]**: 可并行执行（不同文件，无依赖）
- **[Story]**: 所属 User Story（US1, US2, US3）
- 每条任务包含精确文件路径

## Path Conventions

项目根: `ai_assistant/lib/`

```
ai_assistant/lib/
├── core/database/           # Drift 数据库
├── domain/models/           # 领域模型
├── data/repositories/       # Repository 层
├── data/datasources/        # 数据源
├── features/sync/           # 同步引擎
│   └── providers/           # 同步 Provider
├── features/settings/       # 设置页
└── features/todo/providers/ # Todo/Routine Provider
```

---

## Phase 1: Setup (数据库迁移 + 模型变更)

**Purpose**: 为同步重构准备数据层基础——新增 version/deleted/uuid 字段，创建 v4 schema

- [x] T001 [P] 在 `ai_assistant/lib/core/database/tables/todos_table.dart` 中为 Todos 表新增 `version` (IntColumn, default 1) 和 `deleted` (BoolColumn, default false) 列
- [x] T002 [P] 在 `ai_assistant/lib/core/database/tables/routines_table.dart` 中为 Routines 表新增 `uuid` (TextColumn)、`version` (IntColumn, default 1)、`updatedAt` (DateTimeColumn, default now)、`deleted` (BoolColumn, default false) 列
- [x] T003 在 `ai_assistant/lib/core/database/database.dart` 中实现 v3→v4 迁移：ALTER TABLE todos/routines ADD COLUMN，并为现有 routine 记录自动生成 UUID（schemaVersion: 4）
- [x] T004 运行 `build_runner` 更新 `database.g.dart`，验证迁移无错误
- [x] T005 [P] 更新 `ai_assistant/lib/domain/models/todo.dart`：新增 `version` (int, default 1) 和 `deleted` (bool, default false) 字段，更新 `copyWith`
- [x] T006 [P] 更新 `ai_assistant/lib/domain/models/routine.dart`：新增 `uuid` (String)、`version` (int, default 1)、`updatedAt` (DateTime)、`deleted` (bool, default false) 字段，更新 `copyWith`
- [x] T007 更新 `ai_assistant/lib/data/datasources/local_datasource.dart` 中 Todo 的读/写逻辑以支持新增的 `version` 和 `deleted` 字段
- [x] T008 更新 `ai_assistant/lib/data/datasources/local_datasource.dart` 中 Routine 的读/写逻辑以支持新增的 `uuid`, `version`, `updatedAt`, `deleted` 字段

**Checkpoint**: 数据库 schema v4 就绪，model 层完成字段扩展——可开始同步引擎重构

---

## Phase 2: Foundational (路径修正 + 同步基础设施)

**Purpose**: 修正 CloudPathBuilder 路径，建立同步必需的 WebDAV 初始化和 Provider 骨架

**⚠️ CRITICAL**: 所有 User Story 之前必须完成此阶段

- [ ] T009 重写 `ai_assistant/lib/features/sync/cloud_path_builder.dart` 以生成新路径格式：
  - `MyAssistant/{username}/todos/{y}/{ym}/{ymd}/{uuid}.json`（待办）
  - `MyAssistant/{username}/todos/routines/{uuid}.json`（例行）
  - `MyAssistant/{username}/index/todos/todos_index.json`（待办索引）
  - `MyAssistant/{username}/index/todos/routines_index.json`（例行索引）
  - 新增 `get requiredDirectories` 返回首次同步需创建的全部目录列表
- [ ] T010 [P] 更新 `ai_assistant/lib/features/sync/providers/sync_provider.dart`：定义 `SyncState`（lastSyncTime, lastPullCount, lastPushCount, syncing, error），暴露 `triggerSync()` 和 `lastResult`，提供 `syncProvider` StreamProvider
- [ ] T011 [P] 建立 WebDAV 客户端初始化流程：在 App 启动后从 Keychain 读取凭据 → 调用 `WebDavDatasource.initialize()` → 标记 `isReady` 状态
- [ ] T012 更新 `ai_assistant/lib/features/settings/settings_page.dart` 中硬编码的 `MyAssistant/user/` 路径，替换为 `CloudPathBuilder` 统一管理

**Checkpoint**: 路径规范就绪，同步 Provider 骨架完成——可开始 US1 实现

---

## Phase 3: User Story 1 - 双向增量同步待办数据 (Priority: P1)

**Goal**: 实现索引差分增量同步引擎，待办的创建/修改/删除自动同步到 WebDAV

**Independent Test**: 在两设备分别创建不同待办，同步后两端都能看到对方待办；一端删除待办后同步，另一端也消失

### Implementation for User Story 1

- [ ] T013 [US1] 重写 `ai_assistant/lib/features/sync/sync_engine.dart` 中的 `pull(String module)` 方法：
  - 1) GET `index/todos/todos_index.json` → 解析 entries
  - 2) 遍历 entries 对比本地 SyncIndex：云端 version > 本地 cloudVersion → GET 数据文件
  - 3) `deleted=true` 条目的数据 → 本地软删除（设置 deleted=true）
  - 4) 新条目（本地不存在） → 插入本地 DB
  - 5) 更新本地 SyncIndex.cloudVersion = 云端 version
  - 6) 返回拉取条数
- [ ] T014 [US1] 在 `ai_assistant/lib/features/sync/sync_engine.dart` 中实现 `push(String module)` 方法：
  - 1) 查询本地 SyncIndex 中 `localVersion > cloudVersion` 的条目
  - 2) 按 `dataType` 构建路径 → PUT JSON 文件到对应 WebDAV 路径
  - 3) 更新云端索引文件（PUT index JSON）
  - 4) 更新本地 SyncIndex.cloudVersion = localVersion
  - 5) 返回推送条数
- [ ] T015 [US1] 在 `ai_assistant/lib/features/sync/sync_engine.dart` 中实现 `sync(String module)` 方法：先拉取 → 再推送 → 返回 `SyncResult(pullCount, pushCount, errorCount, timestamp)`
- [ ] T016 [US1] 在 `ai_assistant/lib/features/sync/sync_engine.dart` 中实现 `fullSync(String module)` 方法：首次同步（索引文件 404 时触发），全量上传本地数据 + 建立索引
- [ ] T017 [US1] 重写 `ai_assistant/lib/features/sync/index_manager.dart`：使用新 `CloudPathBuilder` 生成模块化索引路径，实现索引版本对比逻辑（`compareWithLocal()` 返回 `{toUpload, toDownload}` 差分列表）
- [ ] T018 [US1] 重写 `ai_assistant/lib/features/sync/sync_scheduler.dart`：
  - 废弃定时器轮询
  - 新增 `syncNow(String module)` 方法（被 Repository 调用）
  - `syncNow()` 内部：检查网络 `NetworkMonitor.hasConnection()` → 在线则调用 `SyncEngine.sync()` → 离线则静默返回
  - 新增 `onNetworkRestored()` 回调（网络恢复时自动同步）
  - 通过 Stream 广播 `SyncResult` 供 UI 消费
- [ ] T019 [US1] 重写 `ai_assistant/lib/features/sync/conflict_resolver.dart`：实现 Last-Write-Wins 策略——对比 `updatedAt`，保留最新版本，记录冲突日志（供调试）
- [ ] T020 [US1] 更新 `ai_assistant/lib/data/repositories/todo_repository.dart`：`addTodo()` 方法内 version 设为 1，操作完成后调用 `SyncScheduler.syncNow('todos')`；`updateTodo()` 方法内 version++，操作后同样触发同步；`deleteTodo()` 改为软删除（deleted=true, version++），操作后触发同步
- [ ] T021 [US1] 更新 `ai_assistant/lib/features/todo/providers/todo_provider.dart`：确保 `addTodo()`、`updateTodo()`、`deleteTodo()` 通过 Repository 触发同步，不直接操作 Datasource

**Checkpoint**: US1 完成——待办的双向增量同步可独立验证。创建/修改/删除待办后自动同步到 WebDAV

---

## Phase 4: User Story 2 - 例行规则同步 (Priority: P2)

**Goal**: 例行规则随待办同步框架一起同步，多设备间保持一致

**Independent Test**: 在设备 A 创建例行规则，同步后设备 B 能看到规则，且自动生成对应待办

### Implementation for User Story 2

- [ ] T022 [US2] 更新 `ai_assistant/lib/data/repositories/routine_repository.dart`：`addRoutine()` 中生成 UUID (`const Uuid().v4()`)，设置 version=1, updatedAt=now, deleted=false；`deleteRoutine()` 改为软删除（deleted=true, version++）；每个 CUD 操作后调用 `SyncScheduler.syncNow('todos')`
- [ ] T023 [US2] 在 `ai_assistant/lib/features/sync/sync_engine.dart` 中扩展 pull 逻辑以处理 `type: 'routine'` 的数据：
  - 拉取 `routines_index.json`
  - routine 数据文件路径：`MyAssistant/{username}/todos/routines/{uuid}.json`（扁平，无日期层级）
  - 同步后更新本地 Routines 表
- [ ] T024 [US2] 更新 `ai_assistant/lib/features/todo/providers/routine_provider.dart`：确保 `addRoutine()` 和 `deleteRoutine()` 通过 Repository 触发同步
- [ ] T025 [US2] 更新 `ai_assistant/lib/features/todo/providers/todo_provider.dart` 的 `_generateRoutineTodos()` 逻辑：从同步后的 routine 数据生成待办时，使用 routine 的 UUID 作为生成待办的识别字段（避免多设备重复生成）

**Checkpoint**: US2 完成——例行规则可双向同步，各设备独立生成待办不冲突

---

## Phase 5: User Story 3 - 同步状态可见 (Priority: P3)

**Goal**: 设置页展示上次同步时间、拉取/推送条数，用户可直观了解同步状态

**Independent Test**: 同步完成后设置页显示"上次同步: 3分钟前, 拉取2条, 推送5条"

### Implementation for User Story 3

- [ ] T026 [US3] 更新 `ai_assistant/lib/features/settings/settings_page.dart`：使用 `syncProvider` 展示同步状态
  - 上次同步时间（格式化："3分钟前" / "刚刚" / "从未同步"）
  - 上次拉取条数 / 上次推送条数
  - 同步中状态指示器（加载 spin）
  - 错误状态（同步失败时显示简要错误信息）
  - 保留"手动同步"按钮
- [ ] T027 [US3] 更新 `ai_assistant/lib/features/settings/settings_page.dart`：WebDAV 配置信息卡保持只读展示（serverUrl, username, maskedPassword）
- [ ] T028 [US3] 更新 `ai_assistant/lib/features/sync/providers/sync_provider.dart`：`SyncNotifier.triggerSync()` 完成后更新 `SyncState`，通过 Riverpod 通知 UI 刷新

**Checkpoint**: US3 完成——用户可在设置页看到同步状态，手动触发同步

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: 清理废弃代码，最终验证

- [ ] T029 [P] 标记 `ai_assistant/lib/features/sync/change_tracker.dart` 为废弃（添加 `// deprecated: replaced by direct sync trigger in Repository` 注释，移除调用引用）
- [ ] T030 [P] 移除 `ai_assistant/lib/features/sync/sync_scheduler.dart` 中的定时器轮询代码（`Timer.periodic`），保留网络恢复监听
- [ ] T031 [P] 在 `ai_assistant/lib/features/settings/settings_page.dart` 中移除旧的按日期范围全量同步代码（`syncByDateRange` 等已废弃方法）
- [ ] T032 运行 `flutter analyze` 确保 0 错误
- [ ] T033 运行 `build_runner` 重新生成代码，验证 0 错误
- [ ] T034 按 `quickstart.md` 执行完整验证流程：数据库迁移 → 首次同步 → 双向同步 → 离线行为

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: 无依赖——可立即开始
- **Foundational (Phase 2)**: 依赖 Phase 1（需要新的 model 字段和 DB schema）——**阻塞所有 User Story**
- **User Story 1 (Phase 3)**: 依赖 Phase 2——核心同步引擎
- **User Story 2 (Phase 4)**: 依赖 Phase 3（依赖 US1 的同步引擎）——例行为同步框架的扩展
- **User Story 3 (Phase 5)**: 依赖 Phase 3（依赖 US1 的 SyncResult 数据）——可并行于 US2
- **Polish (Phase 6)**: 依赖所有 User Story 完成

### User Story Dependencies

- **US1 (P1)**: 可在 Foundational 完成后开始——无其他 Story 依赖
- **US2 (P2)**: 依赖 US1 的 SyncEngine（使用相同的 pull/push 框架）——应在 US1 核心方法完成（T013-T016）后开始
- **US3 (P3)**: 依赖 US1 的 SyncResult 数据——可在 US1 完成后独立进行，不阻塞 US2

### Within Each User Story

- Models and DB schema (Phase 1) before sync engine (Phase 3)
- CloudPathBuilder (Phase 2) before path-dependent tasks
- SyncEngine pull/push (T013, T014) before sync scheduler (T018)
- Repositories (T020-T021) after sync engine core methods

### Parallel Opportunities

- Phase 1: T001 || T002，T005 || T006
- Phase 2: T010 || T011
- Phase 3: T017 (index_manager) 可并行于 T013-T016（sync_engine pull/push）
- Phase 5 (US3) 可并行于 Phase 4 (US2) ——不同模块，无冲突
- Phase 6: T029 || T030 || T031

---

## Parallel Example: User Story 1

```bash
# 同步引擎核心方法（必须顺序依赖）：
Task: "T013: 重写 sync_engine.dart pull 方法"
Task: "T014: 实现 sync_engine.dart push 方法"
Task: "T015: 实现 sync_engine.dart sync 方法"

# 以下可并行于 T013-T015：
Task: "T017: 重写 index_manager.dart"
Task: "T019: 重写 conflict_resolver.dart"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup（数据库迁移 + model 字段）
2. Complete Phase 2: Foundational（路径修正 + Provider 骨架）
3. Complete Phase 3: User Story 1（增量同步引擎）
4. **STOP and VALIDATE**: 创建待办 → 自动同步 → 验证 WebDAV 远端文件
5. 可在 MVP 阶段交付基本同步能力

### Incremental Delivery

1. Phase 1+2 → 数据基础就绪
2. +US1 → 待办增量同步可用（MVP!）
3. +US2 → 例行规则同步可用
4. +US3 → 同步状态可见
5. +Polish → 代码清理，最终验证
6. 每个阶段独立可验证，不破坏已有功能

---

## Notes

- [P] 标记的任务 = 不同文件，无依赖，可并行执行
- [Story] 标签将任务映射到具体 User Story，便于跟踪
- 每个 User Story 应可独立完成和测试
- 每完成一个任务或逻辑组后 commit
- 在任何 Checkpoint 停止以独立验证 Story
- 避免：模糊任务、同文件冲突、跨 Story 非必要依赖
