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

**Decision**: 同步模块通过 SQLite trigger / Drift 表变化监听自动捕获业务表 CUD，并写入 `sync_data`；Repository 不再调用同步队列 API。

**Rationale**: 同步是整体数据层能力，不能依赖具体业务模块逐个调用。触发器能保证任何写入路径都进入同步队列；同步模块执行远端下载合并时通过 `sync_control.muted=true` 排除自己的写入，避免形成回环。

**实现方式**:
1. 业务表 INSERT/UPDATE/DELETE → trigger 写入 `sync_data(operation_type=upload)`
2. `DataSyncService` 监听未完成队列数量 → 自动执行同步
3. 同步下载远端实体 → `LocalSyncDatasource.runMuted()` 静默写库
4. 应用运行中每 10 分钟额外检测云端变化

**降级**: 网络不可用时保留未完成任务，下次自动重试。

---

## R4: UUID 生成方案

**Decision**: 使用现有 `uuid` 包（已在代码中使用）。Routine 从自增 int id 迁移到 UUID 作为同步标识。

**Rationale**: 
- 待办已使用 UUID（`const Uuid().v4()`）
- 例行当前使用 `int autoIncrement`，多设备同步会冲突
- 新增 `uuid` 字段作为同步唯一标识，`id` 保留作本地主键

---

## R5: 索引文件格式设计

**Decision**: Cloud index JSON 存储实体摘要，`sync/sync_index.json` 存储 index 文件摘要。

```json
{
  "module": "todos",
  "updatedAt": "2026-05-21T10:30:00Z",
  "entries": [
    {
      "id": "uuid-v4",
      "version": 3,
      "updatedAt": "2026-05-21T10:30:00Z",
      "lastModifiedDevice": "macos-device-id",
      "path": "root/MyAssistant/todos/2026/2026-05/2026-05-29/todo_uuid-v4.json",
      "deleted": false
    }
  ]
}
```

**Rationale**: 仅含差分对比所需的最小字段，不含 data 内容。`sync/sync_index.json` 让客户端先判断哪些 index 文件需要下载，避免扫描全目录。

**拆分策略**: 按功能模块维护独立索引文件。todos 模块下例行使用 `index/todos/routine_index.json`。

---

## R6: 现有代码改造范围

| 文件 | 操作 | 说明 |
|------|------|------|
| `sync_engine.dart` | 重写 | 替换全量同步为索引差分增量同步 |
| `data_sync_service.dart` | 重写 | 监听 `sync_data` + 10 分钟周期 |
| `local_sync_datasource.dart` | 重写 | sync/sync_index/sync_data/sync_control 读写 |
| `cloud_path_builder.dart` | 修正 | 使用用户指定 WebDAV 目录作为 root |
| `change_tracker.dart` | 废弃 | 替换为数据库触发器自动入队 |
| `conflict_resolver.dart` | 重写 | 改为 Last-Write-Wins 自动解决 |
| `settings_page.dart` | 更新 | 硬编码路径替换 + 同步状态展示 |
| `todos_table.dart` | 新增列 | version, deleted |
| `routines_table.dart` | 新增列 | uuid, version, updatedAt, deleted |
| `todo.dart` | 新增字段 | version, deleted |
| `routine.dart` | 新增字段 | uuid, version, updatedAt, deleted |
| `todo_repository.dart` | 更新 | 移除显式同步依赖 |
| `routine_repository.dart` | 更新 | 移除显式同步依赖 |

---

## R7: 同步流程详细设计

### 拉取流程（先执行）
```
1. GET {root}/MyAssistant/sync/sync_index.json
2. 对比本地 sync 表，找出需要更新的 index 文件
3. GET 需要更新的 index 文件
4. 对比本地 sync_index，写入 sync_data(download)
5. 消费 download 任务，使用 runMuted() 下载实体并写入本地表
6. 更新 sync 与 sync_index
```

### 推送流程（后执行）
```
1. 查询 sync_data 中未完成 upload 任务
2. 按任务 local_table 读取本地实体
3. PUT 实体文件到 `{root}/MyAssistant/...`
4. 更新实体 index 文件
5. 更新 `sync/sync_index.json`
6. 标记 sync_data 任务完成
```

### 异常处理
- 索引文件 404：视为首次同步，全量推送
- 数据文件 404（索引有但文件丢失）：跳过，下次索引重建时修复
- PUT 失败（网络中断）：静默忽略，下次自动重试

---

## R8: 附件同步策略

**Decision**: 日记、文档、归档、Copilot chat/archive_chat 中出现的图片、录音、文件等附件统一拆入 `attachments` 表，业务实体只保存附件 ID。附件云端文件使用 base64 JSON 信封同步，单个附件限制 20MB，且附件任务在普通实体任务之后执行。

**Rationale**:
- 附件体积明显大于普通实体，拆表后主实体 index 和内容文件保持轻量。
- 主实体先同步，附件最后同步，可以让数据引用关系先稳定下来，失败时也只影响附件任务重试。
- base64 JSON 保持 WebDAV 同步格式一致，不需要引入二进制多部分上传协议。

**Cloud paths**:

```text
{root}/MyAssistant/index/attachments/attachments_index.json
{root}/MyAssistant/attachments/{YYYY}/{YYYY-MM}/attachment_{uuid}.json
```

**Constraints**:
- 上传和下载都必须校验 `sizeBytes <= 20MB`。
- 超限附件的 `sync_data` 任务标记为 error，不覆盖本地数据。
- 后续随手记/Copilot UI 和旧数据迁移需要把内嵌附件内容转为 `attachmentIds`。
