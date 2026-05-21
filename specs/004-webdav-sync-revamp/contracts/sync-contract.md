# Sync Contract: WebDAV 同步引擎公共 API

**Phase 1 output for spec 004**

## 核心接口

### SyncEngine

```dart
class SyncEngine {
  /// 执行完整同步周期（拉取→推送）
  /// 返回同步结果摘要
  Future<SyncResult> sync(String module);

  /// 仅拉取（从云端下载变更）
  Future<int> pull(String module);

  /// 仅推送（上传本地变更到云端）
  Future<int> push(String module);

  /// 首次全量同步（云端无数据时）
  Future<SyncResult> fullSync(String module);
}
```

### SyncResult

```dart
class SyncResult {
  final String module;       // 'todos' 等
  final int pullCount;       // 拉取条数
  final int pushCount;       // 推送条数
  final int errorCount;      // 错误条数
  final DateTime timestamp;  // 同步完成时间
  final bool hasErrors;
}
```

### SyncScheduler

```dart
class SyncScheduler {
  /// 由 Repository 层调用，触发一次同步
  /// 自动检查网络：在线则执行，离线则静默忽略
  Future<void> syncNow(String module);

  /// 网络恢复时自动触发同步
  void onNetworkRestored(void Function() callback);

  /// 监听同步结果（供 UI 层消费）
  Stream<SyncResult> get syncStream;
}
```

### CloudPathBuilder

```dart
class CloudPathBuilder {
  final String username;

  /// 构建数据文件路径
  /// dataType: 'todo' | 'routine'
  /// dateStr:  YYYY-MM-DD 格式
  /// dataId:   UUID v4
  String buildFilePath(String dataType, String dateStr, String dataId);

  /// 构建索引文件路径
  /// module: 'todos' | 'bills' | 'notes' | 'copilot'
  /// subType: 'todos' | 'routines' | 'bills' | 'notes' | 'copilot'
  String buildIndexPath(String module, String subType);

  /// 创建完整的远端目录结构（首次同步）
  List<String> get requiredDirectories;
}
```

## Provider 接口

```dart
// sync_provider.dart

/// 同步状态（UI 消费）
class SyncState {
  final DateTime? lastSyncTime;
  final int lastPullCount;
  final int lastPushCount;
  final bool syncing;          // 是否正在同步
  final String? error;
}

final syncProvider = StateNotifierProvider<SyncNotifier, SyncState>((ref) {
  return SyncNotifier(ref);
});

class SyncNotifier extends StateNotifier<SyncState> {
  /// 从外部触发同步
  Future<void> triggerSync([String module = 'todos']);

  /// 获取上次同步结果
  SyncResult? get lastResult;
}
```

## Repository 集成点

```dart
// TodoRepository - 每次 CUD 操作后调用
class TodoRepository {
  Future<void> addTodo(Todo todo) async {
    await _localDs.insertTodo(todo);
    await _scheduler.syncNow('todos');  // ← 新增
  }

  Future<void> updateTodo(Todo todo) async {
    await _localDs.updateTodo(todo);
    await _scheduler.syncNow('todos');  // ← 新增
  }

  Future<void> deleteTodo(String id) async {
    await _localDs.softDeleteTodo(id);
    await _scheduler.syncNow('todos');  // ← 新增
  }
}
```

> RoutineRepository 同理（module='todos'），因为 routine 归属在 todos 模块。

## 错误处理约定

| 场景 | 行为 |
|------|------|
| 网络不可用 | `syncNow()` 静默返回，不抛出异常 |
| WebDAV 未配置 | `syncNow()` 静默返回，`error` = "未配置" |
| 索引文件 404 | 回退为全量推送（首次同步） |
| 数据文件 404 | 跳过该条目，下次全量修复 |
| PUT/GET 失败 | 单条失败不影响其他条目，记录到 `errorCount` |
| 服务器 403 | 标记 `hasErrors=true`，用户可在设置页查看 |
