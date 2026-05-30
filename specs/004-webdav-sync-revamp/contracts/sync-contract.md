# Sync Contract: WebDAV 同步模块 API

**Revised**: 2026-05-29

## Module Boundary

同步模块不要求业务 repository 调用 `markDirty()`。业务表变化由数据库触发器/表变化监控写入 `sync_data`，同步服务监听 `sync_data` 后自动执行。

## SyncEngine

```dart
class SyncEngine {
  Future<SyncResult> sync(String module);
  Future<SyncResult> fullSync(String module);

  Future<Map<String, dynamic>?> readCloudJson(String path);
  Future<void> writeCloudJson(String path, Object data);
}
```

`sync()` 执行顺序：

1. 确保 `{root}/MyAssistant/` 目录结构存在。
2. 拉取 `sync/sync_index.json`，对比本地 `sync` 表。
3. 下载需要更新的 index 文件。
4. 对比本地 `sync_index`，插入 `sync_data(download)`。
5. 静默消费下载任务并更新本地表。
6. 消费 `sync_data(upload)` 上传实体文件。
7. 最后消费附件上传/下载任务，避免主实体先引用不存在的附件。
8. 刷新实体 index 文件。
9. 刷新 `sync/sync_index.json`。

## DataSyncService

```dart
class DataSyncService {
  void start(); // 监听 sync_data + 每 10 分钟检测
  void dispose();
  Future<SyncResult?> manualSync({bool full = false});
  Future<SyncResult?> syncIfNeeded({String reason = 'periodic'});
}
```

`DataSyncService` 启动后监听未完成 `sync_data` 数量；数量大于 0 时触发同步。应用运行中每 10 分钟额外检测一次云端变化。

## LocalSyncDatasource

```dart
class LocalSyncDatasource {
  Future<T> runMuted<T>(Future<T> Function() action);
  Stream<int> watchPendingTaskCount();
  Future<bool> hasPendingTasks();
  Future<List<PendingSyncTask>> getPendingSyncTasks({String? operationType});
  Future<void> enqueueDownload(...);
  Future<void> markTaskCompleted(int id, {String? cloudPath});
  Future<void> markTaskError(int id, String error);
  Future<void> upsertSyncFile(...);
  Future<void> upsertSyncIndex(...);
}
```

`runMuted()` 是同步模块写库的强制入口，内部将 `sync_control.muted=true`，完成后恢复，避免下载合并触发上传队列。

## CloudPathBuilder

```dart
class CloudPathBuilder {
  CloudPathBuilder(String rootDirectory);

  String get appRoot;        // {root}/MyAssistant
  String get syncIndexPath;  // {root}/MyAssistant/sync/sync_index.json

  String buildFilePath(String dataType, String dateStr, String dataId);
  String buildIndexPath(String module, String subType);
  String buildDataFilePath(String module, String subType, String dataId, {String? dateStr});
  List<String> get requiredDirectories;
}
```

`rootDirectory` 是用户在 WebDAV 配置中选择/填写的远端目录。

## Attachment Contract

日记、文档、归档、Copilot chat/archive_chat 不直接保存附件内容，只保存附件 ID 列表。附件统一存入 `attachments` 表，并通过 `index/attachments/attachments_index.json` 与 `attachments/{YYYY}/{YYYY-MM}/attachment_{uuid}.json` 同步。

```dart
class AppAttachment {
  static const int maxSizeBytes = 20 * 1024 * 1024;

  final String id;
  final String ownerType;
  final String ownerId;
  final String attachmentType;
  final String fileName;
  final String? mimeType;
  final int sizeBytes;
  final String contentBase64;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
}
```

同步要求：

1. 上传前校验单个附件 `sizeBytes <= 20MB`，超限任务标记为 error。
2. 云端附件文件使用 JSON 信封，`data.contentBase64` 保存 base64 内容。
3. 下载附件时同样校验大小，超限不覆盖本地记录。
4. 附件任务在普通实体任务之后执行。

## Error Handling

| 场景 | 行为 |
|------|------|
| WebDAV 未配置 | 静默跳过自动同步，设置页可见 |
| `MyAssistant/` 不存在 | 创建完整目录结构 |
| `sync/sync_index.json` 不存在 | 回退到已知 index 路径或首次上传 |
| 实体文件不存在 | 对应 `sync_data` 标记 error |
| 下载写本地 | 必须使用 `runMuted()` |
| 附件超过 20MB | 对应 `sync_data` 标记 error，不上传/不覆盖 |
| 网络失败 | 保留未完成任务，下次继续 |
