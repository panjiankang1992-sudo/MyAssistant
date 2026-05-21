# Research: WebDAV Sync Revamp

**Phase 0 output for spec 004**

## R1: WebDAV 客户端库能力验证

**Decision**: 使用现有 `webdav_plus` 包，无需更换。

**Rationale**: 现有 `WebDavDatasource` 已封装了所需全部操作：`listDirectory` (PROPFIND/LIST)、`getFile` (GET)、`putFile` (PUT)、`deleteFile` (DELETE)、`createDirectory` (MKCOL)、`exists`。索引差分同步不需要额外能力。

**Alternatives considered**:
- `dio` 直接构造 WebDAV 请求：增加复杂度，无收益
- `webdav_client` 替代包：API 类似，迁移成本高无必要

---

## R2: Drift 数据库迁移方案

**Decision**: Schema v3→v4 使用 `ALTER TABLE ADD COLUMN` 增量迁移。

**Rationale**: 现有 v2→v3 迁移已使用此模式（`repeat_rule`、`repeat_days` 列）。Drift 对 SQLite 的 ALTER TABLE 能力已足够。

**具体迁移**:
```sql
-- todos 表
ALTER TABLE todos ADD COLUMN version INTEGER NOT NULL DEFAULT 1;
ALTER TABLE todos ADD COLUMN deleted INTEGER NOT NULL DEFAULT 0;  -- bool stored as int

-- routines 表
ALTER TABLE routines ADD COLUMN uuid TEXT;
ALTER TABLE routines ADD COLUMN version INTEGER NOT NULL DEFAULT 1;
ALTER TABLE routines ADD COLUMN updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE routines ADD COLUMN deleted INTEGER NOT NULL DEFAULT 0;
```

**Risks**: 无。SQLite `ALTER TABLE ADD COLUMN` 向后兼容。

---

## R3: 自动同步触发机制

**Decision**: 在 Repository 层（TodoRepository, RoutineRepository）的每个 CUD 操作后触发 `SyncScheduler.syncNow()`，而非使用 `ChangeTracker` 记录等价类再批量推送。

**Rationale**: FR-015 要求"本地每次修改自动触发同步"，最简单的实现是 Repository 操作完成后直接调用同步。旧的 `ChangeTracker` 模式（记录变更→批量推送）与实时同步需求冲突，应废弃。

**实现方式**:
1. `TodoRepository.addTodo()` 返回后 → 调用 `syncProvider.triggerSync()`
2. `RoutineRepository.addRoutine()` 返回后 → 调用 `syncProvider.triggerSync()`
3. `SyncScheduler.syncNow()` 检查网络 → 在线则执行拉取+推送

**降级**: 网络不可用时静默忽略（FR-017）。

---

## R4: UUID 生成方案

**Decision**: 使用现有 `uuid` 包（已在代码中使用）。Routine 从自增 int id 迁移到 UUID 作为同步标识。

**Rationale**: 
- 待办已使用 UUID（`const Uuid().v4()`）
- 例行当前使用 `int autoIncrement`，多设备同步会冲突
- 新增 `uuid` 字段作为同步唯一标识，`id` 保留作本地主键

---

## R5: 索引文件格式设计

**Decision**: Cloud index JSON 格式如下：

```json
{
  "module": "todos",
  "updatedAt": "2026-05-21T10:30:00Z",
  "entries": [
    {
      "id": "uuid-v4",
      "version": 3,
      "updatedAt": "2026-05-21T10:30:00Z",
      "deleted": false
    }
  ]
}
```

**Rationale**: 仅含差分对比所需的最小字段（id, version, updatedAt, deleted），不含 data 内容。索引文件大小控制在 100KB 以内。

**拆分策略**: 按功能模块（todos, bills, notes, copilot）分别维护独立索引文件。todos 模块下的例行在 `index/todos/` 中持有独立的 `routines_index.json`。

---

## R6: 现有代码改造范围

| 文件 | 操作 | 说明 |
|------|------|------|
| `sync_engine.dart` | 重写 | 替换全量同步为索引差分增量同步 |
| `sync_scheduler.dart` | 重写 | 改为被 Repository 调用触发，非定时器轮询 |
| `index_manager.dart` | 重写 | 新路径格式 + 模块化索引 |
| `cloud_path_builder.dart` | 修正 | 用户名参数已正确，确保调用方统一使用 |
| `change_tracker.dart` | 废弃 | 替换为 Repository 层直接调用 |
| `conflict_resolver.dart` | 重写 | 改为 Last-Write-Wins 自动解决 |
| `settings_page.dart` | 更新 | 硬编码路径替换 + 同步状态展示 |
| `todos_table.dart` | 新增列 | version, deleted |
| `routines_table.dart` | 新增列 | uuid, version, updatedAt, deleted |
| `todo.dart` | 新增字段 | version, deleted |
| `routine.dart` | 新增字段 | uuid, version, updatedAt, deleted |
| `todo_repository.dart` | 更新 | CUD 操作后触发同步 |
| `routine_repository.dart` | 更新 | CUD 操作后触发同步 |

---

## R7: 同步流程详细设计

### 拉取流程（先执行）
```
1. GET MyAssistant/{username}/index/todos/todos_index.json
2. GET MyAssistant/{username}/index/todos/routines_index.json
3. 遍历索引 entries，对比本地 version：
   - 云端 version > 本地 version → 下载对应数据文件
   - 云端 deleted=true → 本地物理删除（先检查 version）
   - 本地无记录 → 新数据，下载
4. 下载后本地 version 更新为云端 version
```

### 推送流程（后执行）
```
1. 遍历本地所有数据（todos + routines），筛选本地 version > SyncIndex 记录的 cloudVersion
2. 逐条 PUT 到对应路径：
   - todo: MyAssistant/{username}/todos/{y}/{ym}/{ymd}/{uuid}.json
   - routine: MyAssistant/{username}/todos/routines/{uuid}.json
3. 更新云端索引文件（todos_index.json + routines_index.json）
4. 更新本地 SyncIndex.cloudVersion = 最新 version
```

### 异常处理
- 索引文件 404：视为首次同步，全量推送
- 数据文件 404（索引有但文件丢失）：跳过，下次索引重建时修复
- PUT 失败（网络中断）：静默忽略，下次自动重试
