# Feature Specification: WebDAV 同步策略重构

**Feature Branch**: `004-webdav-sync-revamp`

**Created**: 2026-05-21

**Revised**: 2026-05-29

**Status**: In Progress

## Summary

同步模块作为独立数据层能力存在，不依赖待办、记账、随手记、Copilot、Profile 等具体业务模块主动调用。业务表发生新增、更新、删除时，由本地数据库触发器/表变化监控自动写入 `sync_data` 队列；同步引擎统一消费上传/下载任务。同步引擎自己执行云端下载合并时必须进入静默上下文，避免远端覆盖本地记录时再次产生上传任务。

用户配置 WebDAV 时必须手动指定远端同步数据存放目录。本地保存该目录地址，后续所有云端操作都基于：

```text
用户指定目录/MyAssistant/
```

首次配置 WebDAV 后立即同步；每次本地业务表变化后自动同步；应用使用中每 10 分钟检测一次；每次打开应用执行一次同步。

## Clarifications

### Session 2026-05-29

- Q: WebDAV 云端根目录如何确定？ -> A: 配置 WebDAV 时由用户手动填写/选择同步数据存放目录，本地持久保存，后续统一在该目录下创建或复用 `MyAssistant/`。
- Q: 同步是否由具体模块调用？ -> A: 否。同步模块监控可同步表的数据变化，排除同步模块自己的写入，自动插入 `sync_data`。
- Q: 本地同步任务如何记录？ -> A: 使用 `sync_data` 队列表，操作类型只区分 `upload` 和 `download`，完成/异常状态在队列表内记录。
- Q: 冲突策略？ -> A: 以 `last_modified_at`/`updatedAt` 最新者胜出；本地和云端都变更时，保留失败/覆盖前记录的备份能力作为后续任务。

## Cloud Directory Contract

```text
用户指定目录/MyAssistant/
├── sync/
│   └── sync_index.json
├── index/
│   ├── todos/
│   │   ├── todos_index.json
│   │   └── routine_index.json
│   ├── bills/
│   │   ├── bills_index.json
│   │   └── category_index.json
│   ├── notes/
│   │   ├── notes_index.json
│   │   ├── diary_index.json
│   │   └── archive_index.json
│   ├── copilot/
│   │   ├── chat_index.json
│   │   ├── archive_chat_index.json
│   │   └── memory_index.json
│   ├── profile/
│   │   └── profile_index.json
│   └── attachments/
│       └── attachments_index.json
├── todos/
│   ├── {YYYY}/{YYYY-MM}/{YYYY-MM-DD}/todo_{uuid}.json
│   └── routine/routine_{uuid}.json
├── bills/
│   ├── {YYYY}/{YYYY-MM}/{YYYY-MM-DD}/bill_{uuid}.json
│   └── category/category_{uuid}.json
├── notes/
│   ├── {YYYY}/{YYYY-MM}/{YYYY-MM-DD}/diary_{uuid}.json
│   ├── notes/note_{uuid}.json
│   └── archive/{category}/archive_{uuid}.json
├── copilot/
│   ├── chat/chat_{uuid}.json
│   ├── archive_chat/archive_chat_{uuid}.json
│   └── memory.json
├── profile/
    ├── user_profile.json
    ├── theme_setting.json
    ├── copilot_setting.json
    ├── data_setting.json
    ├── tags_setting.json
    └── feedback.json
└── attachments/
    └── {YYYY}/{YYYY-MM}/attachment_{uuid}.json
```

`sync/sync_index.json` 存储 `index/` 下每个索引文件的云端路径和最后修改时间。`index/` 下各文件存储实体摘要列表，列表项必须包含：实体 UUID、最后修改设备、最后修改时间戳、实体云端路径、软删除状态。

附件是跨模块实体。随手记中的日记、文档、归档，以及 Copilot 聊天记录中出现的图片、普通附件、录音等，都必须写入统一 `attachments` 表；日记/文档/归档/聊天消息表只保存对应 `attachmentIds`，不保存附件内容。附件云端文件使用 base64 内容同步，单个附件原始大小不得超过 20MB。

## User Stories

### US1 - 用户指定 WebDAV 同步目录 (P1)

用户配置 WebDAV 时选择同步数据存放目录。保存后应用立即在该目录下检查 `MyAssistant/` 是否存在：存在则拉取数据，不存在则创建完整目录结构并上传本地数据。

**Acceptance**:

1. 保存 WebDAV 配置时必须保存同步目录。
2. 首次保存配置后立即触发一次同步。
3. 远端不存在 `MyAssistant/` 时创建 `sync/`、`index/` 和所有实体目录。
4. 远端已存在 `MyAssistant/` 时先拉取远端索引和实体数据。

### US2 - 表变化自动入队 (P1)

任意可同步业务表发生新增、更新、删除时，同步模块自动写入 `sync_data` 上传任务；业务模块不需要调用同步 API。

**Acceptance**:

1. 修改 `todos`、`routines`、可同步配置表后，本地自动插入 `sync_data(operation_type=upload)`。
2. 同步引擎下载远端数据并写入本地表时，不产生新的上传任务。
3. `sync_data` 中未完成任务会在下一次同步周期继续执行。

### US3 - 索引差分下载 (P1)

同步开始时先拉取 `sync/sync_index.json`，对比本地 `sync` 表，找出需要更新的 index 文件；再解析 index 文件，对比本地 `sync_index` 表，生成下载任务。

**Acceptance**:

1. 云端 index 文件更新时间晚于本地 `sync` 记录时，下载该 index 文件。
2. index 条目的更新时间晚于本地 `sync_index` 记录时，插入 `sync_data(operation_type=download)`。
3. 下载实体文件成功后，静默覆盖/更新本地实体表，并更新 `sync` 与 `sync_index`。
4. 云端实体文件不存在时，任务标记为异常，不影响其他任务。

### US4 - 上传队列与索引刷新 (P1)

同步上传阶段扫描 `sync_data` 中未完成的上传任务，读取对应本地实体表，将记录写为云端 JSON 文件，再刷新实体索引和 `sync/sync_index.json`。

**Acceptance**:

1. 本地新增/修改/软删除后，只上传对应实体文件。
2. 上传成功后更新实体 index 文件。
3. index 文件上传成功后更新 `sync/sync_index.json`。
4. `sync_data` 对应任务标记完成。

### US5 - 全量同步范围覆盖 (P2)

所有可修改的数据表和配置表都必须能同步，包括待办、例行、账单、分类、随手记、日记、归档、聊天、归档聊天、记忆、用户资料、主题、Copilot 设置、数据设置、标签设置、反馈。

**Acceptance**:

1. 每个可修改实体都有本地表、index 条目和云端实体路径。
2. 文件型旧存储需要迁移到本地表或由同步模块统一托管，不再由业务模块自行同步。
3. 配置类数据按新表格式导入并保留本地备份。

### US6 - 附件独立同步 (P1)

日记、文档、归档和 Copilot 聊天记录中的图片、普通附件、录音统一进入附件表，并在主实体同步完成后最后同步附件。

**Acceptance**:

1. 日记/文档/归档/聊天消息表只记录 `attachmentIds`。
2. 附件表记录归属实体、附件类型、文件名、MIME、大小、base64 内容、软删除和时间戳。
3. 单个附件超过 20MB 时不得进入同步队列，任务标记异常或 UI 拒绝。
4. 同步执行顺序中附件上传/下载排在其他实体之后。

## Functional Requirements

- **FR-001**: WebDAV 配置 MUST 保存用户指定同步目录，目录为空不得保存。
- **FR-002**: 同步根 MUST 为 `用户指定目录/MyAssistant/`，不得再使用 `MyAssistant/{username}/` 作为固定根。
- **FR-003**: 首次配置 WebDAV 后 MUST 立即执行同步。
- **FR-004**: 应用启动时 MUST 执行一次同步。
- **FR-005**: 应用运行中 MUST 每 10 分钟检测一次同步。
- **FR-006**: 本地可同步表变化后 MUST 自动插入 `sync_data` 上传任务并触发同步。
- **FR-007**: 同步模块自己的下载合并写入 MUST 不触发表变化上传任务。
- **FR-008**: 本地 MUST 维护 `sync` 表，结构和数据语义与云端 `sync/sync_index.json` 一致。
- **FR-009**: 本地 MUST 维护 `sync_index` 表，结构和云端 index 条目一致。
- **FR-010**: 本地 MUST 维护 `sync_data` 队列表，包含 ID、sync_index ID、数据实体 ID、本地表名、云端实体文件路径、操作类型、完成状态、最后更新时间戳。
- **FR-011**: 所有实体文件 MUST 包含统一固定字段：实体 ID、`is_deleted`、`created_at`、`updated_at`；展示时间字段必须与创建时间分离。
- **FR-012**: 删除 MUST 使用 `is_deleted` 软删除字段同步。
- **FR-013**: 冲突 MUST 采用最后修改时间优先，并保留扩展点用于冲突备份/恢复。
- **FR-014**: 下载流程 MUST 先比较 `sync/sync_index.json`，再比较实体 index，最后下载实体文件。
- **FR-015**: 上传流程 MUST 先消费上传任务，再刷新实体 index，最后刷新 `sync/sync_index.json`。
- **FR-016**: 附件 MUST 使用独立 `attachments` 表同步，主实体只保存 `attachmentIds`。
- **FR-017**: 附件云端 JSON MUST 使用 base64 保存文件内容，单个附件原始大小 MUST <= 20MB。
- **FR-018**: 同步任务执行时附件 MUST 最后上传、最后下载。

## Key Entities

- **Sync**: 本地 `sync` 表，对应云端 `sync/sync_index.json`，记录 index 文件路径、模块、索引名、最后修改设备、最后修改时间。
- **SyncIndex**: 本地实体索引表，对应云端 `index/**.json`，记录实体 ID、实体类型/表名、最后修改设备、最后修改时间、云端实体路径、软删除状态。
- **SyncData**: 本地同步任务队列，记录上传/下载任务执行状态。
- **SyncControl**: 本地同步静默控制，标记同步模块正在写库，触发器据此跳过自动入队。
- **Attachment**: 跨随手记和 Copilot 的附件实体，保存 ownerType、ownerId、attachmentType、fileName、mimeType、sizeBytes、contentBase64、createdAt、updatedAt、isDeleted。

## Success Criteria

- **SC-001**: 配置 WebDAV 并保存目录后，立即创建/复用 `用户指定目录/MyAssistant/` 并完成一次同步。
- **SC-002**: 修改待办或例行后，无需 repository 调用同步 API，`sync_data` 自动出现上传任务。
- **SC-003**: 同步下载远端数据时不会产生新的上传任务。
- **SC-004**: 1000 条实体中只有 10 条变更时，只传输相关 index 和 10 个实体文件。
- **SC-005**: `flutter analyze` 和现有 `flutter test` 通过。
