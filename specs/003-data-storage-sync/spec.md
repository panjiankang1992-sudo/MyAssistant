# Feature Specification: 数据存储与同步机制

**Feature Branch**: `003-data-storage-sync`

**Created**: 2026-05-20

**Status**: Draft

**Input**: User description: "本地SQLite + 云端WebDAV双层存储，索引差分同步。本地存三类数据（主数据、待推送变更、云端拉取变更），云端按年/月/日层级存放。"

## Clarifications

### Session 2026-05-20

- Q: WebDAV 认证方式与凭据存储策略？ → A: Basic Auth + HTTPS 传输，凭据加密存储于系统 Keychain
- Q: 设备 ID 生成方式与数据版本递增策略？ → A: UUID 设备 ID（首次启动生成），每条数据每次修改 version += 1（整数递增）

## User Scenarios & Testing *(mandatory)*

### User Story 1 - 本地数据持久化与实时访问 (Priority: P1)

作为用户，我希望所有核心数据保存在本地，应用启动后立即可见，无需等待网络。

**Why this priority**: 本地数据是应用运行的基础——即使无网络，用户也能查看和管理所有数据。

**Independent Test**: 断网状态下打开应用 → 待办、记账等所有数据正常显示 → 添加一条待办 → 刷新页面 → 数据仍在。

**Acceptance Scenarios**:

1. **Given** 用户首次打开应用, **When** 本地数据库初始化完成, **Then** 待办列表显示种子数据
2. **Given** 用户添加一条待办, **When** 关闭应用后重新打开, **Then** 该待办仍然存在
3. **Given** 设备处于断网状态, **When** 用户查看待办列表和聊天记录, **Then** 所有历史数据正常显示
4. **Given** 用户修改个人信息, **When** 保存后立即查看, **Then** 修改内容已生效

---

### User Story 2 - 数据变更追踪与推送 (Priority: P1)

作为系统，我希望记录所有本地新增/修改/删除的数据变更，在网络可用时自动推送到云端，推送成功后清除本地变更记录。

**Why this priority**: 变更追踪是双向同步的基础——确保用户操作不会丢失，且避免重复上传。

**Independent Test**: 断网时添加待办 → 检查本地变更表有该记录 → 连网后系统自动推送 → 变更表该记录被清除 → 云端文件出现对应数据。

**Acceptance Scenarios**:

1. **Given** 用户断网状态下修改了一条待办的标题, **When** 查看本地变更记录表, **Then** 该待办的 ID、修改内容、时间戳已记录
2. **Given** 本地有 3 条待推送变更, **When** 网络恢复后同步触发, **Then** 3 条变更依次推送到云端，本地变更表清空
3. **Given** 上传过程中网络中断, **When** 网络再次恢复, **Then** 未上传成功的变更在下次同步周期重试

---

### User Story 3 - 云端数据拉取与合并 (Priority: P1)

作为系统，我希望每次应用启动和每 10 分钟自动从云端拉取变更数据，先暂存到本地临时区，再合并到主数据存储。

**Why this priority**: 拉取是实现多设备数据一致性的核心——用户在手机上的操作应同步到桌面端。

**Independent Test**: 在设备 A 添加待办并同步到云端 → 在设备 B 打开应用 → 10 分钟内设备 B 看到该待办。

**Acceptance Scenarios**:

1. **Given** 云端有 2 条其他设备推送的新待办, **When** 用户启动应用, **Then** 应用拉取云端索引，识别出 2 条新数据并下载到本地临时区
2. **Given** 本地临时区有下载的云端数据, **When** 合并完成, **Then** 主数据表出现新待办，临时区数据被清除
3. **Given** 应用已运行超过 10 分钟, **When** 定时器触发, **Then** 自动执行一次云端拉取和合并

---

### User Story 4 - 云端文件层级组织 (Priority: P2)

作为系统，我希望云端数据按 `MyAssistant/{用户名}/{类型}/{年}/{年月}/{年月日}/` 的层级结构存放，每个数据条目为独立文件，便于增量同步和故障排查。

**Why this priority**: 良好的文件组织结构使同步更高效（按日期范围拉取），也便于人工检查和数据恢复。

**Independent Test**: 查看云端 WebDAV 目录 → 确认 `MyAssistant/testuser/todos/2026/202605/20260520/xxx.json` 路径结构存在。

**Acceptance Scenarios**:

1. **Given** 用户在 2026-05-20 创建了一条待办, **When** 数据同步到云端, **Then** 文件存放在 `MyAssistant/{用户名}/todos/2026/202605/20260520/` 目录下
2. **Given** 用户创建了一条帐单记录, **When** 同步到云端, **Then** 文件存放在 `MyAssistant/{用户名}/bills/2026/202605/20260520/` 目录下
3. **Given** 用户创建了一条随手记, **When** 同步到云端, **Then** 文件存放在 `MyAssistant/{用户名}/notes/2026/202605/20260520/` 目录下

---

### User Story 5 - 索引加速同步 (Priority: P2)

作为系统，我希望每次同步时优先拉取云端索引文件，对比本地版本后仅下载/上传有变更的文件，避免全量传输。

**Why this priority**: 索引差分同步大幅减少网络流量和同步延迟。

**Independent Test**: 云端有 1000 条数据但仅 2 条有变更 → 同步仅传输这 2 条 → 流量 < 50KB。

**Acceptance Scenarios**:

1. **Given** 云端有 50 条待办数据, **When** 拉取同步索引 `todos_index.json`, **Then** 获得所有待办的 ID、版本号和更新时间列表
2. **Given** 本地有 48 条待办的版本与云端一致, 2 条云端版本更高, **When** 对比完成后, **Then** 仅下载这 2 条待办文件
3. **Given** 本地有 3 条待办的版本高于云端, **When** 对比完成后, **Then** 这 3 条待办被标记为待上传

---

### Edge Cases

- 当云端索引文件不存在（首次使用）时，系统应自动创建初始索引并上传全部本地数据
- 当本地和云端对同一条数据都有修改时（冲突），系统应采用"最后修改时间优先"策略，并保留冲突副本
- 当 WebDAV 服务不可用时，本地所有操作正常进行，变更累积在待推送队列中
- 当同步过程中应用被关闭，未完成的同步在下次启动时从中断点继续
- 当 WebDAV 认证凭据过期或无效时，系统应提示用户重新登录，暂停同步但不影响本地使用

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: 系统 MUST 在本地使用结构化存储保存所有核心数据（待办、帐单、随手记、聊天记录、个人信息），支持增删改查
- **FR-002**: 系统 MUST 维护本地变更记录表，记录所有尚未推送到云端的新增/修改/删除操作
- **FR-003**: 系统 MUST 在每次数据创建/修改/删除时自动向变更记录表追加记录
- **FR-004**: 系统 MUST 在应用启动时立即执行一次云端数据拉取
- **FR-005**: 系统 MUST 每 10 分钟自动执行一次云端数据拉取和本地变更推送
- **FR-006**: 系统 MUST 在网络可用时自动推送本地变更记录到云端，推送成功后清除对应记录
- **FR-007**: 云端 MUST 按 `MyAssistant/{用户名}/{数据类型}/{年}/{年月}/{年月日}/{id}.json` 的层级存放数据文件
- **FR-008**: 每条云端数据文件 MUST 包含 id、type、version、updatedAt、data 和 deleted 字段
- **FR-009**: 系统 MUST 在每个数据类型目录下维护索引文件，仅含每条数据的 id、version、updatedAt
- **FR-010**: 同步流程 MUST 优先拉取索引文件进行版本对比，仅传输有差异的文件
- **FR-011**: 系统 MUST 在本地临时区暂存从云端下载的变更数据，合并完成后清除
- **FR-012**: 系统 MUST 记录每个设备的同步状态
- **FR-013**: 同步冲突 MUST 以"最后修改时间优先"策略自动解决
- **FR-014**: 用户 MUST 能在离线状态下正常使用所有功能
- **FR-016**: 系统 MUST 在首次启动时生成 UUID 作为设备唯一标识，持久保存；每条数据的版本号 MUST 在每次修改时递增 1

### Key Entities

- **主数据实体**：Todo、Bill、Note、ChatMessage、UserProfile
- **变更记录 (ChangeRecord)**：record_id, data_id, data_type, operation(create/update/delete), change_content(json), created_at, pushed(bool)
- **同步索引 (SyncIndex)**：data_id, data_type, local_version(int), cloud_version(int), updated_at, sync_status(pending_push/pending_pull/synced/conflict)
- **设备同步状态 (DeviceSyncState)**：device_id(UUID), last_sync_time, last_pull_version, last_push_version
- **云端数据文件 (CloudDataFile)**：id, type, version(int), updatedAt, data:{...}, deleted

### Data Classification

| 分类 | 存储位置 | 包含数据 | 生命周期 |
|------|---------|---------|---------|
| 主数据 | 本地主表 | 待办、帐单、随手记、聊天记录、个人信息 | 永久，实时更新 |
| 待推送变更 | 本地变更表 | 主数据的所有未推送修改 | 推送成功后清空 |
| 云端拉取暂存 | 本地临时表 | 从云端下载的增量数据 | 合并到主表后清空 |
| 索引 | 本地 + 云端 | 所有数据的版本摘要 | 每次同步更新 |
| 云端存档 | WebDAV 远程 | 所有数据的永久副本 | 永久，按日期分层 |

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 应用启动 3 秒内本地数据可交互（无需等待网络）
- **SC-002**: 单次同步周期在有 1000 条数据且 10 条变更时，总耗时不超过 5 秒
- **SC-003**: 推送本地变更到云端更新的端到端延迟不超过 30 秒
- **SC-004**: 离线状态下用户操作不受任何影响
- **SC-005**: 同步冲突自动解决率达到 90% 以上
- **SC-006**: 索引文件大小在 1000 条数据时不超过 100KB

## Assumptions

- 用户已完成注册并登录，云端 WebDAV 服务已配置并可访问
- 单个用户的数据总量在 10MB 以内（不含附件）
- 时钟偏差在不同设备间不超过 5 分钟（用于冲突检测）
- WebDAV 服务支持标准的 GET/PUT/DELETE/PROPFIND 操作，使用 HTTPS 加密传输，认证方式为 Basic Auth（用户名/密码）
- 本 Phase 仅实现数据存储和同步的基础架构，UI 层面的同步状态提示延后到下一 Phase
- 待办、帐单、随手记按日期目录存储的"日期"指数据的创建日期或所属日期
