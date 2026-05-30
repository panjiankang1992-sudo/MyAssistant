# Tasks: WebDAV 同步策略重构

**Revised**: 2026-05-29

## Phase 1: 同步模块底座

- [x] T001 新增本地 `sync` 表，对应云端 `sync/sync_index.json`
- [x] T002 扩展 `sync_index` 表，补齐 index 条目字段：云端路径、最后修改设备、云端更新时间、软删除
- [x] T003 新增 `sync_data` 队列表，记录 upload/download 任务
- [x] T004 新增 `sync_control` 静默控制表
- [x] T005 在数据库迁移中创建同步表和表变化触发器
- [x] T006 为 `todos`、`routines`、`tags`、`metadata_options` 建立自动入队触发器
- [x] T007 实现 `LocalSyncDatasource.runMuted()`，同步写库时关闭自动入队

## Phase 2: 用户指定 WebDAV 目录

- [x] T008 在 WebDAV 配置页增加同步目录字段
- [x] T009 将同步目录保存到本地 Keychain 存储
- [x] T010 保存 WebDAV 配置后立即触发首次同步
- [x] T011 重写 `CloudPathBuilder`，以 `{root}/MyAssistant/` 作为云端根
- [x] T012 首次同步前创建/复用完整远端目录结构

## Phase 3: 队列驱动同步

- [x] T013 `DataSyncService` 监听 `sync_data` 未完成任务
- [x] T014 自动检测周期改为 10 分钟
- [x] T015 从 todo/routine/tag repository 移除显式同步队列调用
- [x] T016 拉取阶段根据 index 差异写入 `sync_data(download)`
- [x] T017 下载阶段通过 `runMuted()` 写入本地表
- [x] T018 上传阶段消费 `sync_data(upload)`
- [x] T019 上传实体后刷新实体 index 文件
- [x] T020 上传实体 index 后刷新 `sync/sync_index.json`

## Phase 3.5: 附件独立同步

- [x] T021 新增 `attachments` 表，承载日记、文档、归档、Copilot 聊天附件
- [x] T022 为 `attachments` 建立自动入队触发器
- [x] T023 为随手记和 Copilot 消息模型增加 `attachmentIds`
- [x] T024 设计附件云端路径和 `index/attachments/attachments_index.json`
- [x] T025 附件实体使用 base64 JSON 信封同步，并限制单个附件不超过 20MB
- [x] T026 调整同步任务排序，附件上传/下载最后执行
- [x] T026a 接入随手记编辑器，保存图片/文件时写入附件表并在笔记中记录 `attachmentIds`

## Phase 4: 全量同步范围补齐

- [ ] T027 将账单 entries/categories 从 JSON 文件迁移为可同步表
- [ ] T028 将随手记 notes/diary/archive 从 JSON 文件迁移为可同步表，并补齐旧内容中的内嵌附件迁移
- [ ] T029 将 Copilot chat/archive_chat/memory 从文件/Storage 迁移为可同步表，并把聊天附件迁移为 `attachmentIds`
- [ ] T030 将 profile/theme/copilot/data/tags/feedback 配置统一迁移为可同步表
- [ ] T031 为新增表安装自动入队触发器
- [ ] T032 将旧 JSON/Storage 数据备份后导入新表

## Phase 5: 冲突与恢复

- [ ] T033 新增冲突备份表或本地备份文件
- [ ] T034 Last-Write-Wins 覆盖前保存本地旧值
- [ ] T035 设置页展示最近同步异常和冲突备份入口

## Phase 6: 验证

- [x] T036 运行 `flutter pub run build_runner build`
- [x] T037 运行 `flutter analyze`
- [x] T038 运行 `flutter test`
- [ ] T039 macOS 真 WebDAV 首次同步验证
- [ ] T040 Android 真机同步验证
- [ ] T041 鸿蒙 NEXT 同步验证
