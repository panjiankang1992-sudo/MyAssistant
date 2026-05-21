# Feature Specification: WebDAV 同步策略重构

**Feature Branch**: `004-webdav-sync-revamp`

**Created**: 2026-05-21

**Status**: Draft

**Input**: User description: "当前的同步数据的策略有问题。请参照多文件+按Key分片方式重新实现。代办例行的数据同步也需要设计。"

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

### User Story 3 - 同步状态可见与冲突提示 (Priority: P3)

用户在设置页能看到上次同步时间、同步方向（拉取N条/推送N条）、以及当检测到同一待办在两端都修改过时，提示用户选择保留哪个版本。

**Why this priority**: 提升用户体验和信任度，但不阻塞基本同步功能。

**Independent Test**: 同步完成后设置页显示"上次同步: 3分钟前, 拉取2条, 推送5条"。两端编辑同一待办后同步，显示冲突提示。

**Acceptance Scenarios**:

1. **Given** 同步完成, **When** 用户查看设置页, **Then** 显示上次同步时间、拉取数量、推送数量
2. **Given** 设备 A 和 B 都修改了同一待办, **When** B 拉取同步, **Then** 弹出冲突提示让用户选择保留本地版或云端版

---

### Edge Cases

- 同步过程中网络断开：已完成的部分保留，未完成的下次重试
- 索引文件损坏或不存在：回退到全量拉取
- 同一数据在两端被删除：删除优先，不产生幽灵数据
- 首次使用（云端无数据）：直接上传本地全部数据
- 大量数据同步（1000+待办）：索引差分机制确保只传输变更部分
- 时区差异：全部使用 UTC ISO8601 格式，显示时转为本地时区

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: 同步引擎 MUST 采用索引差分机制：客户端先拉取 `index/` 下的索引文件（只含 id、version、updatedAt），对比本地版本号，仅下载有变更的文件
- **FR-002**: 每个待办/例行数据 MUST 存储为独立 JSON 文件，按 `数据类型/年/月/日/<uuid>.json` 的层级存放
- **FR-003**: 每条数据文件 MUST 包含统一的信封格式：`{id, type, version, updatedAt, data: {...}, deleted}`
- **FR-004**: 客户端 MUST 在本地维护每条数据的 version 和 updatedAt 字段，每次修改 version 自增、updatedAt 更新
- **FR-005**: 推送同步 MUST 仅上传本地 version 大于云端 version 的文件（增量）
- **FR-006**: 拉取同步 MUST 仅下载云端 updatedAt 晚于本地 updatedAt 的文件（增量）
- **FR-007**: 删除操作 MUST 在云端保留标记文件（deleted=true），或在索引中标记该条目已删除，并在本地同步时执行删除
- **FR-008**: 例行规则 MUST 与待办使用相同的同步框架（独立 type=routine，存入 routines/ 目录）
- **FR-009**: 索引文件 MUST 按数据类型分别生成（todo_index.json、routine_index.json），仅包含摘要字段（id、version、updatedAt、deleted）
- **FR-010**: 同步过程 MUST 在设置页显示上次同步时间、拉取条数、推送条数
- **FR-011**: 同步操作 MUST 同时执行拉取（先拉）和推送（后推），确保双向数据一致性
- **FR-012**: 设备首次同步（云端无数据）时 MUST 执行全量上传，建立索引文件
- **FR-013**: 网络中断时 MUST 保留已有进度，下次同步从断点继续
- **FR-014**: 用户数据（待办、例行）的 version MUST 从 1 开始，每次本地修改自增+1

### Key Entities

- **Todo (待办)**: id、title、description、source、type、time、date、completed、createdAt、updatedAt、version、deleted
- **Routine (例行)**: id、title、description、type、time、repeatRule、repeatDays、createdAt、updatedAt、version、deleted
- **SyncIndex (同步索引)**: 数据类型→条目摘要列表（id、version、updatedAt、deleted）
- **WebDAV 文件结构**: `cloud/user_data/{todos|routines}/{year}/{month}/{day}/{uuid}.json` + `cloud/user_data/index/{todos|routines}_index.json`

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
- 冲突策略采用"最后修改胜出"（Last-Write-Wins），即 updatedAt 更新的版本覆盖旧版本
- 同步为手动触发（点击按钮），不做自动定时同步（后续版本再考虑）
- 例行规则在设备间同步后，各设备独立根据规则生成当日待办（内容一致但 id 不同）
- macOS 平台优先实现，Android 和鸿蒙 NEXT 后续跟进
- 索引文件大小控制在 100KB 以内（1000 条数据约 50KB）