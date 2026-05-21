# Feature Specification: WebDAV 同步策略重构

**Feature Branch**: `004-webdav-sync-revamp`

**Created**: 2026-05-21

**Status**: Draft

**Input**: User description: "当前的同步数据的策略有问题。请参照多文件+按Key分片方式重新实现。代办例行的数据同步也需要设计。"

## Clarifications

### Session 2026-05-21

- Q: 冲突解决策略选择？ → A: Last-Write-Wins（updatedAt 更大自动覆盖），且本地每次修改自动触发同步（先 check 再修改，乐观锁模式），无需用户干预冲突
- Q: 本地版本追踪存储在哪？ → A: Drift 本地数据库字段（todo/routine 表的 version+updatedAt+deleted 列），无需额外本地索引文件
- Q: 自动同步时网络不可用怎么处理？ → A: 静默忽略失败，本地修改照常保存，下次有网络时自动重试
- Q: 删除同步策略？ → A: 软删除+延期清理 — 云端保留 deleted=true 文件30天，索引标记 deleted，拉取端本地删除，30天后物理清理
- Q: 断点续传策略？ → A: 整体重试 — 每次同步是完整拉取+推送流程，失败则整体重试；索引差分本身保证传输量小，无需断点机制
- Q: 例行存储路径结构？ → A: 例行是规则元数据，不属于具体日期，扁平存储为 routines/{uuid}.json（无日期层级）；待办仍按日期分片为 todos/{year}/{month}/{day}/{uuid}.json
- Q: 云端路径中的用户标识？ → A: 使用具体用户名替换硬编码的 "user"，路径格式为 MyAssistant/{username}/，与现有 CloudPathBuilder 一致
- Q: 云端目录结构？ → A: MyAssistant/{username}/ 下有6个一级目录：index、todos、bills、notes、copilot、profile。routines 归属在 todos/ 下（todos/routines/{uuid}.json），索引按功能模块在 index/ 下分目录（index/todos/、index/bills/等）

## User Scenarios & Testing *(mandatory)*

### User Story 1 - 双向增量同步待办数据 (Priority: P1)

用户在设备 A 创建/修改/删除待办后，在设备 B 点击同步按钮，待办列表自动合并两端的变更（新增、修改、删除），最终两端数据一致。同理例行的重复规则也能同步。

**Why this priority**: 核心数据同步是最基础的能力，没有它多设备使用场景不存在。

**Independent Test**: 在两个设备上分别创建不同待办，点击同步后两端都能看到对方的待办；在一端删除一个待办后同步，另一端也消失。

**Acceptance Scenarios**:

1. **Given** 设备 A 有待办 "买牛奶"(未完成), **When** 设备 A 同步到 WebDAV, **Then** 待办 JSON 和索引文件成功上传，索引中包含该条目的 id、version、updatedAt
2. **Given** 设备 A 已同步, **When** 设备 B 拉取同步, **Then** 设备 B 本地新增 "买牛奶" 且内容和设备 A 一致
3. **Given** 两端都有 "买牛奶", **When** 设备 A 完成该待办并同步, **Then** 设备 B 同步后该待办也变为已完成（updatedAt 更大的版本覆盖）
4. **Given** 设备 A 删除了某个待办, **When** 同步, **Then** 设备 B 同步后该待办从本地删除（云端文件标记 deleted=true 或直接移除）

---

### User Story 2 - 例行规则同步 (Priority: P2)

用户在设备 A 创建一条例行规则（如"每个工作日早上9点写周报"），在设备 B 同步后能看到这条规则，且该规则在设备 B 也能根据日期自动生成待办。

**Why this priority**: 例行是待办的核心衍生功能，但依赖待办同步基础先完成。

**Independent Test**: 在设备 A 创建一条"每天早上8点跑步"的例行规则，同步后设备 B 也能看到该规则，且当日自动生成了对应待办。

**Acceptance Scenarios**:

1. **Given** 设备 A 创建例行 "每天8点跑步" (repeatRule=daily), **When** 同步到 WebDAV, **Then** routines 目录下出现该例行 JSON 文件，索引更新
2. **Given** 设备 B 同步后获得该例行, **When** 当天打开 App, **Then** 自动生成一条 "跑步" 待办（来源=routine）
3. **Given** 设备 A 修改例行的重复规则为"仅工作日", **When** 同步后, **Then** 设备 B 的规则也变为"仅工作日"

---

### User Story 3 - 同步状态可见 (Priority: P3)

用户在设置页能看到上次同步时间、同步方向（拉取N条/推送N条）。冲突自动以 Last-Write-Wins 策略解决，无需用户干预。

**Why this priority**: 提升用户体验和信任度，但不阻塞基本同步功能。

**Independent Test**: 同步完成后设置页显示"上次同步: 3分钟前, 拉取2条, 推送5条"。

**Acceptance Scenarios**:

1. **Given** 同步完成, **When** 用户查看设置页, **Then** 显示上次同步时间、拉取数量、推送数量

---

### Edge Cases

- 同步过程中网络断开：整体重试，无需断点续传；索引差分保证重试成本低
- 自动同步失败（无网络等）：静默忽略，不弹提示，不阻断操作，下次有网络时自动重试
- 索引文件损坏或不存在：回退到全量拉取
- 同一数据在两端被删除：删除优先（deleted=true 标记），不产生幽灵数据；两端都修改时 Last-Write-Wins 自动解决
- 首次使用（云端无数据）：直接上传本地全部数据，在 `MyAssistant/{username}/` 下创建完整目录结构和索引文件
- 大量数据同步（1000+待办）：索引差分机制确保只传输变更部分
- 时区差异：全部使用 UTC ISO8601 格式，显示时转为本地时区

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: 同步引擎 MUST 采用索引差分机制：客户端先拉取 `MyAssistant/{username}/index/{module}/` 下的索引文件（只含 id、version、updatedAt），对比本地版本号，仅下载有变更的文件
- **FR-002**: 待办数据 MUST 按日期分片存储，路径为 `MyAssistant/{username}/todos/{year}/{month}/{day}/{uuid}.json`；例行数据作为待办的衍生规则 MUST 归属在 todos 模块下，扁平存储为 `MyAssistant/{username}/todos/routines/{uuid}.json`（无日期层级）。{username} 为登录用户名，非硬编码 "user"
- **FR-003**: 每条数据文件 MUST 包含统一的信封格式：`{id, type, version, updatedAt, data: {...}, deleted}`
- **FR-004**: 客户端 MUST 在本地维护每条数据的 version 和 updatedAt 字段，每次修改 version 自增、updatedAt 更新
- **FR-005**: 推送同步 MUST 仅上传本地 version 大于云端 version 的文件（增量）
- **FR-006**: 拉取同步 MUST 仅下载云端 updatedAt 晚于本地 updatedAt 的文件（增量）
- **FR-007**: 删除操作 MUST 采用软删除策略：云端保留 `deleted=true` 标记文件 30 天（防误删恢复），索引中标记该条目 `deleted:true`；拉取端看到 `deleted=true` 后从本地数据库物理删除；30 天后云端标记文件由同步引擎物理清理
- **FR-008**: 例行规则 MUST 与待办使用相同的同步框架（type=routine，存入 `todos/routines/` 子目录），索引文件在 `index/todos/` 下
- **FR-009**: 索引文件 MUST 按功能模块分目录存放：`index/todos/`（含 `todos_index.json` 和 `routines_index.json`）、`index/bills/`、`index/notes/`、`index/copilot/`，仅包含摘要字段（id、version、updatedAt、deleted）
- **FR-010**: 同步过程 MUST 在设置页显示上次同步时间、拉取条数、推送条数
- **FR-011**: 同步操作 MUST 同时执行拉取（先拉）和推送（后推），确保双向数据一致性
- **FR-012**: 设备首次同步（云端无数据）时 MUST 执行全量上传，建立索引文件
- **FR-013**: 同步失败时 MUST 整体重试（无需断点续传）；每次同步是完整的拉取+推送流程，索引差分保证传输量小，失败后下次触发时重新执行全流程
- **FR-014**: 用户数据（待办、例行）的 version MUST 从 1 开始，每次本地修改自增+1
- **FR-015**: 本地每次修改（创建/更新/删除待办或例行）MUST 自动触发同步流程：先拉取远端索引检查版本（乐观锁 check-then-write），再推送本地变更
- **FR-016**: 冲突解决 MUST 采用 Last-Write-Wins 策略（updatedAt 更大的版本自动覆盖），无需用户手动选择
- **FR-017**: 自动同步因网络不可用而失败时 MUST 静默忽略，本地修改照常保存不阻断用户操作，待下次网络恢复时（手动同步或下次自动触发）自动重试

### Key Entities

- **Todo (待办)**: id、title、description、source、type、time、date、completed、createdAt、updatedAt、version、deleted
- **Routine (例行)**: id、title、description、type、time、repeatRule、repeatDays、createdAt、updatedAt、version、deleted
- **SyncIndex (同步索引)**: 远端索引文件（`MyAssistant/{username}/index/{todos|routines}_index.json`），仅包含摘要字段（id、version、updatedAt、deleted）。本地版本追踪直接使用 Drift 数据库字段，不维护独立本地索引文件
- **WebDAV 文件结构**: `MyAssistant/{username}/` 下有6个一级目录：
  ```
  MyAssistant/{username}/
  ├── index/           # 索引（按功能模块分子目录）
  │   ├── todos/       # 含 todos_index.json 和 routines_index.json
  │   ├── bills/       # 含 bills_index.json
  │   ├── notes/       # 含 notes_index.json
  │   └── copilot/     # 含 copilot_index.json
  ├── todos/           # 待办数据（按日期分片）
  │   ├── {year}/{month}/{day}/{uuid}.json
  │   └── routines/    # 例行数据（扁平，无日期层级）
  │       └── {uuid}.json
  ├── bills/           # 账单数据
  ├── notes/           # 随手记数据
  ├── copilot/         # AI Copilot 数据
  └── profile/        # 用户资料
  ```

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 用户点击同步按钮后，1000 条待办中仅有变更部分被传输，同步完成时间 < 5 秒（索引差分生效）
- **SC-002**: 双向同步后，两端待办列表完全一致，无数据丢失或重复
- **SC-003**: 设置页清晰展示上次同步时间、拉取/推送条数
- **SC-004**: 例行规则同步后，设备端能正确生成当日待办
- **SC-005**: 网络断开后重连，同步能自动恢复，不丢失已完成的传输
- **SC-006**: 首次使用场景：空云端 → 上传所有本地数据 + 建立索引，耗时 < 10 秒（100 条数据内）

## Assumptions

- 用户提供有效的 WebDAV 凭据（通过服务器 profile 接口自动同步到本地 Keychain）
- WebDAV 服务支持 PROPFIND/LIST/MKCOL/PUT/GET/DELETE 操作
- 所有时间戳使用 UTC ISO8601 格式存储，显示时转为本地时区
- 每个数据条目的 id 为 UUID v4，全局唯一，无冲突
- 版本号（version）使用简单递增整数，不做分布式版本向量
- 冲突策略采用"最后修改胜出"（Last-Write-Wins），即 updatedAt 更新的版本自动覆盖旧版本，无需用户干预
- 本地每次修改（创建/更新/删除）自动触发同步：先拉取远端最新版本检查（乐观锁），再推送本地变更，确保数据一致性
- 手动同步按钮保留，用于首次同步或网络恢复后的手动触发
- 例行规则在设备间同步后，各设备独立根据规则生成当日待办（内容一致但 id 不同）。例行的云端路径归属在 `todos/routines/` 子目录下，因为例行是待办的衍生规则
- macOS 平台优先实现，Android 和鸿蒙 NEXT 后续跟进
- 索引文件大小控制在 100KB 以内（1000 条数据约 50KB）