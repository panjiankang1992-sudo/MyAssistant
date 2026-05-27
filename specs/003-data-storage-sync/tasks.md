# Tasks: 数据存储与同步机制

**Input**: Design documents from `/specs/003-data-storage-sync/`

**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/

**Tests**: 不生成独立测试任务（spec 未要求 TDD）。

**Organization**: 任务按用户故事分组，支持独立实现和测试。

## Format: `[ID] [P?] [Story] Description`

- **[P]**: 可并行执行
- **[Story]**: 所属用户故事（US2, US3, US4, US5）
- 描述中包含精确文件路径

---

## Phase 1: Setup（依赖安装 + 配置）

**Purpose**: 添加同步相关依赖包，配置 macOS 安全权限

- [x] T001 添加同步依赖到 `ai_assistant/pubspec.yaml`：webdav_plus ^1.2.2, flutter_secure_storage ^10.2.0, connectivity_plus ^7.1.1, xml ^6.6.1
- [x] T002 运行 `flutter pub get` 安装新依赖
- [x] T003 [P] 配置 macOS entitlements：在 `ai_assistant/macos/Runner/DebugProfile.entitlements` 和 `Release.entitlements` 中添加 `keychain-access-groups` 权限

---

## Phase 2: Foundational（数据库扩展 + 基础设施）

**Purpose**: 新增 3 张同步表，Keychain 服务，WebDAV 客户端，网络监控

**⚠️ CRITICAL**: 此阶段完成后才能开始用户故事

### 数据库扩展

- [ ] T004 创建 ChangeRecords 表 `ai_assistant/lib/core/database/tables/change_records_table.dart`（参考 data-model.md）
- [ ] T005 [P] 创建 SyncIndex 表 `ai_assistant/lib/core/database/tables/sync_index_table.dart`（复合主键 dataId + dataType）
- [ ] T006 [P] 创建 DeviceSyncState 表 `ai_assistant/lib/core/database/tables/device_state_table.dart`（deviceId 主键）
- [ ] T007 更新 AppDatabase `ai_assistant/lib/core/database/database.dart`：注册 ChangeRecords、SyncIndex、DeviceSyncState 表，schemaVersion → 2
- [ ] T008 运行 `dart run build_runner build` 生成数据库代码

### 安全存储

- [ ] T009 创建 KeychainService `ai_assistant/lib/core/security/keychain_service.dart`（flutter_secure_storage 封装：saveCredentials / getCredentials / deleteCredentials）

### WebDAV 客户端

- [ ] T010 创建 WebDavDatasource `ai_assistant/lib/data/datasources/webdav_datasource.dart`（webdav_plus 封装：initialize / listDirectory / getFile / putFile / deleteFile / exists / createDirectory）

### 网络监控

- [ ] T011 创建 NetworkMonitor `ai_assistant/lib/core/network/network_monitor.dart`（connectivity_plus 封装：hasConnection / isOnWifi / onConnectivityChanged stream）

### 数据源扩展

- [ ] T012 创建 LocalSyncDatasource `ai_assistant/lib/data/datasources/local_sync_datasource.dart`（Drift 操作：upsertChangeRecord / getPendingChanges / markPushed / upsertSyncIndex / getSyncIndex / getDeviceState / updateDeviceState）

---

## Phase 3: User Story 2 - 数据变更追踪与推送 (Priority: P1)

**Goal**: 所有本地数据修改自动记录到变更表，网络可用时推送到云端并清除记录

**Independent Test**: 断网添加待办 → ChangeRecords 有记录 → 连网后自动推送 → 记录被清除 → 云端文件出现

### 变更追踪

- [ ] T013 [US2] 创建 ChangeTracker `ai_assistant/lib/features/sync/change_tracker.dart`（注入各 Repository：recordChange / recordCreate / recordUpdate / recordDelete，写 ChangeRecord 表）
- [ ] T014 [US2] 修改 TodoRepository `ai_assistant/lib/data/repositories/todo_repository.dart`：addTodo/deleteTodo/toggleTodo 方法中注入 changeTracker.recordChange() 调用
- [ ] T015 [P] [US2] 创建 SyncRepository `ai_assistant/lib/data/repositories/sync_repository.dart`（变更记录查询 / 标记已推送 / 设备状态读写）

### 推送引擎

- [ ] T016 [US2] 实现 pushToCloud 方法 `ai_assistant/lib/features/sync/sync_engine.dart`：读取 ChangeRecords → 按 dataType 分组 → 构建云端文件路径 → PUT 上传 → 标记 pushed=true → 清除已推送记录

---

## Phase 4: User Story 3 - 云端数据拉取与合并 (Priority: P1)

**Goal**: 启动时 + 每 10 分钟从云端拉取变更，暂存后合并到本地

**Independent Test**: 设备 A 同步后 → 设备 B 启动 → 拉取到 A 的数据 → 主表出现新待办

### 拉取引擎

- [ ] T017 [US3] 实现 pullFromCloud 方法 `ai_assistant/lib/features/sync/sync_engine.dart`：遍历 dataTypes → PROPFIND 获取远端文件列表 → 对比本地版本 → 下载变更文件 → 存入临时暂存区
- [ ] T018 [US3] 实现 mergeToMain 方法 `ai_assistant/lib/features/sync/sync_engine.dart`：读取暂存区 → 按 dataType 分类 → 插入/更新主数据表 → 更新 SyncIndex → 清除暂存区

### 定时器

- [ ] T019 [US3] 创建 SyncScheduler `ai_assistant/lib/features/sync/sync_scheduler.dart`：应用启动时自动 fullSync + Timer.periodic(10min) 定时 pull + 网络恢复时触发同步

### Provider

- [ ] T020 [US3] 创建 SyncProvider `ai_assistant/lib/features/sync/providers/sync_provider.dart`（Riverpod Notifier：syncStatus / fullSync / lastSyncTime，依赖 SyncEngine + SyncScheduler）

---

## Phase 5: User Story 5 - 索引加速同步 (Priority: P2)

**Goal**: 优先拉取索引文件（仅 id+version），对比后仅传输差异文件

**Independent Test**: 1000 条数据仅 2 条变更 → 同步流量 < 50KB

### 索引管理

- [ ] T021 [US5] 创建 IndexManager `ai_assistant/lib/features/sync/index_manager.dart`：生成索引 JSON / 拉取云端索引 / 版本对比（local vs cloud）→ 输出 toUpload / toDownload 列表
- [ ] T022 [US5] 实现 updateIndex 方法 `ai_assistant/lib/features/sync/index_manager.dart`：同步完成后更新本地 SyncIndex 表 + PUT 云端索引文件

---

## Phase 6: User Story 4 - 云端文件层级组织 (Priority: P2)

**Goal**: 数据按 `MyAssistant/{user}/{type}/{year}/{yearMonth}/{yearMonthDay}/{id}.json` 存放

**Independent Test**: 查看 WebDAV 服务器 → 文件路径结构正确

### 路径构建

- [ ] T023 [US4] 实现路径构建工具 `ai_assistant/lib/features/sync/cloud_path_builder.dart`：根据 dataType + date 生成目录路径 + 文件名（参考 contracts/webdav-storage.md）
- [ ] T024 [US4] 集成路径构建器到 WebDavDatasource 和 SyncEngine：确保 PUT/GET 使用正确的路径层级

---

## Phase 7: Polish & Edge Cases

- [ ] T025 实现冲突检测与解决 `ai_assistant/lib/features/sync/conflict_resolver.dart`（Last-Write-Wins + 云端保留冲突副本 `{id}_conflict_{timestamp}.json`）
- [ ] T026 [P] 添加离线/网络错误处理：WebDAV 不可用时本地操作不受影响，错误累计到 DeviceSyncState.syncErrors
- [ ] T027 [P] 添加凭据过期处理：401 响应 → 提示用户重新配置 WebDAV 连接，暂停同步
- [ ] T028 运行 `flutter analyze` 验证零错误，`flutter build macos` 验证构建成功

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: 无依赖
- **Foundational (Phase 2)**: 依赖 Setup → **阻塞所有用户故事**
- **US2 - Change Tracking (Phase 3)**: 依赖 Foundational → 可独立开始
- **US3 - Cloud Pull (Phase 4)**: 依赖 Foundational + US2（共享 SyncEngine 基础设施）
- **US5 - Index Sync (Phase 5)**: 依赖 Foundational + US3（共享 SyncEngine 基础设施）
- **US4 - Path Builder (Phase 6)**: 依赖 Foundational（共享 WebDavDatasource）
- **Polish (Phase 7)**: 依赖 US2-US5 完成

### Parallel Opportunities

```text
Phase 2 内部：T004 ∥ T005 ∥ T006 (三个表定义独立)
          T009 ∥ T010 ∥ T011 (Keychain/WebDAV/Network 独立服务)

Phase 3-6：US4（Phase 6）可与 US3（Phase 4）并行
          US5（Phase 5）依赖 US3
          US2（Phase 3）可完全独立
```

---

## Implementation Strategy

### MVP (US2 + US3)

1. Phase 1: Setup
2. Phase 2: Foundational
3. Phase 3: US2 - Change Tracking + Push
4. Phase 4: US3 - Cloud Pull + Merge
5. **验证**: 双向同步可用

### Full Delivery

MVP + Phase 5 (索引加速) + Phase 6 (目录结构) + Phase 7 (Polish)

---

## Notes

- [P] 任务 = 不同文件，无依赖 → 可并行
- 当前分支 `003-data-storage-sync` 上已有 `002-env-todo-copilot` 的完整代码
- WebDAV 连接信息（URL/用户名/密码）通过 Settings UI 配置，暂不在此 Phase
- macOS entitlements 修改后需 `flutter clean && flutter build` 生效
