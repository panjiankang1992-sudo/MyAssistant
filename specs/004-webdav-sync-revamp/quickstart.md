# Quickstart: WebDAV 同步策略重构

**Revised**: 2026-05-29

## Build & Verify

```bash
cd ai_assistant
flutter pub run build_runner build
flutter analyze
flutter test
```

## WebDAV 配置验证

1. 打开设置页。
2. 填写 WebDAV 服务器、用户名、密码/授权码。
3. 填写同步目录，例如 `Documents/MyAssistantData`。
4. 点击验证。
5. 保存后应用应立即触发一次同步。

远端目录应为：

```text
Documents/MyAssistantData/MyAssistant/
```

## 首次同步验证

保存 WebDAV 配置后检查远端目录：

```text
{root}/MyAssistant/sync/sync_index.json
{root}/MyAssistant/index/todos/todos_index.json
{root}/MyAssistant/index/todos/routine_index.json
{root}/MyAssistant/index/attachments/attachments_index.json
{root}/MyAssistant/todos/{YYYY}/{YYYY-MM}/{YYYY-MM-DD}/todo_{uuid}.json
{root}/MyAssistant/todos/routine/routine_{uuid}.json
{root}/MyAssistant/attachments/{YYYY}/{YYYY-MM}/attachment_{uuid}.json
```

## 表变化自动入队验证

使用 SQLite 客户端查看：

```sql
SELECT * FROM sync_data WHERE is_completed = 0 ORDER BY id DESC;
```

验证步骤：

1. 新增待办。
2. `sync_data` 自动出现 `local_table='todos'`、`operation_type='upload'`。
3. 修改例行。
4. `sync_data` 自动出现 `local_table='routines'`、`operation_type='upload'`。
5. 同步完成后任务 `is_completed=1`。

## 附件同步验证

使用 SQLite 客户端查看附件任务：

```sql
SELECT id, owner_type, owner_id, size_bytes FROM attachments ORDER BY updated_at DESC;
SELECT * FROM sync_data WHERE local_table = 'attachments' ORDER BY id DESC;
```

验证步骤：

1. 为日记、文档或归档添加图片/录音/文件附件；Copilot chat 接入附件输入后复用同一验证流程。
2. 随手记保存后正文只保留文字/网页快照，图片和文件转为 `attachmentIds`。
3. `sync_data` 自动出现 `local_table='attachments'`、`operation_type='upload'`。
4. 同步时先上传普通实体，最后上传附件文件和 `index/attachments/attachments_index.json`。
5. 单个附件超过 20MB 时，上传任务应进入 error 状态。

## 静默下载验证

1. 在 WebDAV 上准备更新时间更新的实体文件和 index。
2. 触发同步。
3. 本地实体被更新。
4. 同步下载写入本地期间不新增 `operation_type='upload'` 的任务。

## Current Limitations

- 当前代码触发器已覆盖 `todos`、`routines`、`tags`、`metadata_options`、`attachments`。
- `bills`、`notes`、`copilot`、`profile` 仍有 JSON/本地存储路径，后续需要迁移为同步模块托管的本地表。
- 随手记编辑器已接入附件表写入流程；Copilot chat 附件输入仍需接入，模型和同步层已支持 `attachmentIds`。
- 冲突备份表尚未落地；当前基础策略仍以最后修改时间优先。
