# Quickstart: WebDAV 同步策略重构

**Phase 1 output for spec 004**

## 前置条件

1. Flutter 3.27+ 已安装
2. macOS 环境 + Homebrew
3. 后端 MyTools 服务已运行（提供 WebDAV 凭据）
4. WebDAV 服务器可访问

## 数据库迁移

首次运行 v4 版本时，Drift 自动执行迁移：

```bash
cd ai_assistant
flutter clean
SQLITE3_LIB_DIR="/opt/homebrew/opt/sqlite/lib" flutter pub get
SQLITE3_LIB_DIR="/opt/homebrew/opt/sqlite/lib" flutter pub run build_runner build --delete-conflicting-outputs
```

迁移内容（自动）：
- `todos` 表新增 `version`, `deleted` 列
- `routines` 表新增 `uuid`, `version`, `updated_at`, `deleted` 列
- 现有例行记录自动生成 UUID

## 关键文件改动

| 文件 | 操作 | 说明 |
|------|------|------|
| `domain/models/todo.dart` | 新增字段 | `version`, `deleted` |
| `domain/models/routine.dart` | 新增字段 | `uuid`, `version`, `updatedAt`, `deleted` |
| `core/database/tables/todos_table.dart` | 新增列 | `version`, `deleted` |
| `core/database/tables/routines_table.dart` | 新增列 | `uuid`, `version`, `updatedAt`, `deleted` |
| `core/database/database.dart` | schemaVersion→4 | 新增 v4 迁移代码 |
| `data/repositories/todo_repository.dart` | 新增 | CUD 后触发同步 |
| `data/repositories/routine_repository.dart` | 新增 | CUD 后触发同步 |
| `features/sync/cloud_path_builder.dart` | 修正 | 路径格式对齐新规范 |
| `features/sync/sync_engine.dart` | **重写** | 索引差分增量同步 |
| `features/sync/index_manager.dart` | **重写** | 模块化索引 |
| `features/sync/sync_scheduler.dart` | **重写** | Repository 驱动 |
| `features/sync/providers/sync_provider.dart` | **重写** | SyncState 状态暴露 |
| `features/settings/settings_page.dart` | 更新 | 同步状态展示 |

## 验证步骤

### 1. 数据库迁移验证

```bash
# 启动 app 后检查数据库
ls ~/Library/Containers/com.example.aiAssistant/Data/Documents/ai_assistant_db
```

使用 SQLite 客户端检查新列：
```sql
PRAGMA table_info(todos);
PRAGMA table_info(routines);
```

### 2. 首次同步验证

1. 登录后创建一条待办
2. 自动触发同步 → 检查 WebDAV 远端是否有新文件：
   ```
   MyAssistant/{username}/todos/{YYYY}/{YYYYMM}/{YYYYMMDD}/{uuid}.json
   MyAssistant/{username}/index/todos/todos_index.json
   ```

### 3. 双向同步验证

1. 创建设备 A 待办 "测试A"
2. 等待自动同步完成
3. 在设备 B（或同一设备重新创建）创建待办 "测试B"
4. 点击设置页手动同步
5. 验证两端都可见 "测试A" 和 "测试B"

### 4. 例行同步验证

1. 创建例行 "每天8点跑步" (daily)
2. 检查远端 `MyAssistant/{username}/todos/routines/{uuid}.json`
3. 检查远端 `MyAssistant/{username}/index/todos/routines_index.json`
4. 修改重复规则为 "仅工作日"
5. 同步后验证规则已更新

### 5. 离线行为验证

1. 断开网络
2. 创建/修改/删除待办 → 操作正常完成，不报错
3. 恢复网络 → 自动同步新变更到云端

## 已知限制

- 仅实现 `todos` 模块同步（bills/notes/copilot/profile 目录已预留，实现延后）
- 手动同步按钮保留，用于首次同步或网络恢复后手动触发
- 30天软删除清理功能在后续版本实现
- macOS 专属功能，Android/鸿蒙同步延后
