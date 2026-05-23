# 待办标签系统设计

## 目标

将待办的单一 `type` 字段替换为多标签系统，支持多选标签、自定义标签、标签管理，同时保持查询性能和同步兼容。

## 架构

**混合存储方案**：新建 `tags` 表存标签元数据（需同步），todo 表新增 `tags` JSON 字段直接存完整标签信息（冗余但查询快）。查询待办只读 todo 表，新增/编辑待办时查 tags 表获取可用标签列表。废弃 `type` 字段。

**数据流**：标签定义变更 → 写 tags 表 → 同步到云端；待办变更 → tags JSON 跟随 todo 数据自然同步。

## 数据模型

### tags 表（新增）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | TEXT | UUID，主键 |
| name | TEXT | 标签名，最长6个字 |
| colorKey | TEXT | 调色板键名（如 `blue`, `purple`, `pink`） |
| sortOrder | INTEGER | 排序序号，越小越靠前 |
| isPreset | BOOLEAN | 是否为预设标签（个人/工作/账单/健康） |
| createdAt | DATETIME | 创建时间 |
| updatedAt | DATETIME | 更新时间 |

### todo 表变更

- **新增** `tags` 字段：TEXT 类型，存 JSON 数组，如 `[{"id":"uuid1","name":"个人","colorKey":"purple"},{"id":"uuid2","name":"工作","colorKey":"blue"}]`
- **废弃** `type` 字段：保留列不删除（兼容旧数据），新代码不再使用

### routine 表变更

- 同 todo 表：新增 `tags` 字段，废弃 `type` 字段

### 预设标签

| name | colorKey | 颜色 |
|------|----------|------|
| 个人 | purple | 背景 #F3E8FF，文字 #AF52DE |
| 工作 | blue | 背景 #E8F2FD，文字 #4A90D9 |
| 账单 | pink | 背景 #FCE4EC，文字 #E91E63 |
| 健康 | green | 背景 #E8FAF3，文字 #1ABC9C |

### 调色板（8色）

| colorKey | 背景色 | 文字色 |
|----------|--------|--------|
| blue | #E8F2FD | #4A90D9 |
| purple | #F3E8FF | #AF52DE |
| pink | #FCE4EC | #E91E63 |
| green | #E8FAF3 | #1ABC9C |
| orange | #FEF3E0 | #E67E22 |
| indigo | #F0E6FF | #7C3AED |
| lime | #EAF5EA | #27AE60 |
| sky | #E3F2FD | #2196F3 |

## 数据迁移

schema v4 → v5 迁移：

1. 创建 `tags` 表
2. 给 todo 表新增 `tags` 列（TEXT，默认 `'[]'`）
3. 给 routine 表新增 `tags` 列（TEXT，默认 `'[]'`）
4. 插入4个预设标签到 tags 表
5. 遍历所有 todo，将 `type` 值转为 tags JSON：
   - `personal` → `[{"id":"<预设uuid1>","name":"个人","colorKey":"purple"}]`
   - `work` → `[{"id":"<预设uuid2>","name":"工作","colorKey":"blue"}]`
   - `bill` → `[{"id":"<预设uuid3>","name":"账单","colorKey":"pink"}]`
   - `health` → `[{"id":"<预设uuid4>","name":"健康","colorKey":"green"}]`
   - 其他值 → `[{"id":"<预设uuid1>","name":"个人","colorKey":"purple"}]`（兜底为个人）
6. 同样迁移 routine 表

## UI 交互

### 标签选择器（新增/编辑待办时）

替换现有 `DropdownButtonFormField` 为标签选择行：

- **已选标签**：显示在上方，带 ✕ 按钮可取消，最多6个
- **未选标签**：显示在下方，点击选中，每个标签带对应颜色
- **"更多..."按钮**：固定在行尾，点击后下方展开区域：
  - 搜索输入框
  - 3排标签网格（所有可用标签，已选的不重复显示）
  - 输入框支持：搜索已有标签直接选中，或输入不存在的内容直接创建临时标签（仅本次使用，不存入 tags 表，最多6个字）
- **"管理"按钮**：固定在行尾，点击打开标签管理弹窗

### 标签管理弹窗

- **顶部**：标签名输入框 + 8色调色板选择 + "添加"按钮
- **标签列表**：
  - 每行：标签名 + 颜色预览圆点 + ↑↓排序按钮 + 🗑删除按钮
  - 点击颜色预览圆点可弹出调色板修改颜色
  - 预设标签不允许删除（隐藏删除按钮）
- 添加新标签：输入名称 + 选颜色 → 存入 tags 表，全局可用

### 待办列表展示

- 每条待办显示标签 TagChip，空间不足时显示前几个 + "..."省略
- TagChip 样式与现有一致（圆角药丸形，带颜色）
- 原有 `type` 的 TagChip 改为从 tags 字段渲染

### 待办详情页

- 查看模式：显示所有标签 TagChip
- 编辑模式：使用标签选择器组件

## 同步

### 标签元数据同步

tags 表作为独立模块同步：
- 云端路径：`MyAssistant/{username}/tags/index.json`（存所有标签定义）
- 推送：标签增删改时，上传整个 index.json
- 拉取：同步时下载 index.json，合并本地标签（以 id 为准，云端覆盖本地）

### 待办 tags 字段同步

无需额外逻辑——tags JSON 作为 todo 数据的一部分，随现有的 todo 文件同步流程自然走。

## NLP 解析适配

`todo_text_parser.dart` 的 type 推断逻辑适配：
- 匹配到 `work` → 标签 `工作`
- 匹配到 `bill` → 标签 `账单`
- 匹配到 `health` → 标签 `健康`
- 默认 → 标签 `个人`
- 返回标签 id 列表而非 type 字符串

## 代码改动范围

| 文件 | 改动 |
|------|------|
| `core/database/database.dart` | schema v5 迁移 |
| `core/database/tables/tags_table.dart` | 新建 |
| `core/database/tables/todos_table.dart` | 新增 tags 列 |
| `core/database/tables/routines_table.dart` | 新增 tags 列 |
| `domain/models/todo.dart` | 新增 tags 字段，废弃 type |
| `domain/models/routine.dart` | 新增 tags 字段，废弃 type |
| `domain/models/tag.dart` | 新建 |
| `data/datasources/local_datasource.dart` | 标签 CRUD + todo 映射适配 |
| `data/datasources/local_sync_datasource.dart` | tags 表同步索引 |
| `data/repositories/tag_repository.dart` | 新建 |
| `features/todo/widgets/add_todo_modal.dart` | 标签选择器替换下拉框 |
| `features/todo/widgets/todo_detail_modal.dart` | 标签选择器替换下拉框 |
| `features/todo/widgets/routine_modal.dart` | 标签选择器替换下拉框 |
| `features/todo/widgets/tag_selector.dart` | 新建，标签选择器组件 |
| `features/todo/widgets/tag_manage_dialog.dart` | 新建，标签管理弹窗 |
| `features/todo/widgets/todo_item.dart` | 从 tags 渲染 TagChip |
| `shared/widgets/tag_chip.dart` | 支持从 Tag 模型渲染 |
| `core/theme/app_theme.dart` | 新增调色板常量 |
| `features/todo/services/todo_text_parser.dart` | 返回标签 id 列表 |
| `features/sync/sync_engine.dart` | 新增 tags 同步逻辑 |
| `features/sync/cloud_path_builder.dart` | 新增 tags 路径 |
