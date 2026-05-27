# 设计文档 — MyAssistant Flutter App v2

> 基于 2026-05-24 实际代码，含本次改动

## 一、架构总览

```
lib/
├── main.dart                          # ProviderScope + App
├── my_app.dart                        # MaterialApp, AuthWrapper, HomePage (4 tabs)
├── core/
│   ├── theme/app_theme.dart           # AppColors, AppAnimations, lightTheme
│   ├── database/database.dart         # Drift schema v6, migration
│   ├── database/tables/*.dart         # Todos, Routines, ChangeRecords, SyncIndex, DeviceSyncState, Tags
│   ├── providers/core_providers.dart  # 所有顶层 Provider 注册
│   └── security/keychain_service.dart # 文件级 JWT/凭据存储
├── domain/models/
│   ├── todo.dart                      # Todo (id, title, description, source, type, tags, time, date, completed, priority, version, deleted)
│   ├── routine.dart                   # Routine (id, uuid, title, type, tags, time, repeatRule, repeatDays…)
│   └── tag.dart                       # Tag + TagPalette (8色调色板)
├── data/
│   ├── api/api_client.dart            # HTTP + JWT (localhost:23110)
│   ├── datasources/
│   │   ├── local_datasource.dart      # Drift CRUD + Tag编解码
│   │   ├── local_sync_datasource.dart # SyncIndex 读写
│   │   └── webdav_datasource.dart     # WebDAV 文件操作
│   └── repositories/
│       ├── todo_repository.dart       # auto-sync 触发
│       ├── routine_repository.dart
│       └── tag_repository.dart
├── features/
│   ├── todo/
│   │   ├── todo_page.dart             # 主待办页：标题+诗词+日历条+TodoList+FAB
│   │   ├── providers/
│   │   │   ├── todo_provider.dart     # TodoNotifier (CRUD + 例行生成)
│   │   │   ├── routine_provider.dart  # RoutineNotifier
│   │   │   └── selected_date_provider.dart
│   │   ├── services/todo_text_parser.dart  # 中文自然语言解析
│   │   └── widgets/
│   │       ├── todo_list.dart         # TodoList + _SwipeActions (左滑延期/删除 + 右滑完成)
│   │       ├── todo_item.dart         # TodoItem (checkbox动画 + 优先级左边框)
│   │       ├── add_todo_modal.dart    # 3Tab bottom sheet (智能/手动/例行)
│   │       ├── todo_detail_modal.dart # 查看/编辑 bottom sheet (弹簧动画)
│   │       ├── smart_input.dart       # 智能输入 + AI识别预览
│   │       ├── routine_tab.dart       # 例行管理 Tab (标签/时间/重复规则)
│   │       ├── routine_modal.dart     # 简化版例行管理 (独立bottom sheet)
│   │       ├── tag_selector.dart      # 标签选择器 (搜索/创建/管理)
│   │       ├── tag_manage_dialog.dart # 标签管理对话框 (增删改排序换色)
│   │       └── week_calendar_strip.dart # 无限翻页日历条 (1040页)
│   ├── copilot/
│   │   ├── copilot_page.dart          # AI对话页 (当前为模拟)
│   │   ├── providers/copilot_provider.dart
│   │   └── widgets/                   # ChatBubble, CopilotHero, CopilotInput, PromptCards
│   ├── profile/
│   │   ├── profile_panel.dart         # 右滑个人信息面板
│   │   └── profile_provider.dart      # UserProfile + ProfileNotifier
│   └── sync/
│       ├── sync_engine.dart           # 双向WebDAV同步 (索引+全量)
│       └── cloud_path_builder.dart
└── shared/widgets/
    ├── tag_chip.dart                  # TagChip (三种构造方式)
    └── empty_state.dart               # 空状态占位
```

---

## 二、核心交互流程

### 2.1 Todo 滑动操作 (_SwipeActions)

```
右滑 +50px  → 吸附到 +76px   → 绿色完成按钮  → tap = toggleComplete
左滑 -60px  → 吸附到 -80px   → 橙色"延期"按钮 → tap = 弹出延期菜单
左滑 -140px → 吸附到 -160px  → 红色删除按钮  → tap = 弹出删除确认
未达阈值   → 回弹到 0
已完成待办 → 禁用滑动
```

延期菜单选项：
- 延期至明天
- 延期至下周一
- 延期至下周同日
- 自定义日期 (DatePicker)

### 2.2 优先级系统

| 值 | 标签 | 列表左边框 | 表单 Chip 颜色 |
|----|------|-----------|---------------|
| 0 | 普通 | 无 | 灰色(默认) |
| 1 | 重要 | 橙色 3px | 橙色实心 |
| 2 | 紧急 | 红色 3px | 红色实心 |

### 2.3 智能输入解析 (TodoTextParser)

关键词识别：
- **时间**: 明天/后天/下周X/周X | 早上(08:00)/上午(10:00)/中午(12:00)/下午(15:00)/晚上(19:00) | X点/X:X
- **类型**: 会议/汇报/周报 → work | 账单/缴费/付款 → bill | 健身/跑步/体检 → health
- **附加描述**: 会议→"请提前准备相关材料" | 付款→"请保留支付凭证" | 运动→"记得带运动装备"

### 2.4 例行自动生成

- 登录时生成未来30天例行待办
- 防重复：检查 title + source + date 是否已存在
- 编辑例行 → 批量软删除旧例行未来待办 → 按新规则重新生成
- 删除例行 → 软删除未来待办，保留今日已过期的

---

## 三、数据库 Schema (v6)

```
todos:          id, title, description?, source, type, tags(JSON), time, date, 
                completed, priority, createdAt, updatedAt, version, deleted

routines:       id(自增), uuid?, title, description?, type, tags(JSON), time,
                repeatRule, repeatDays?, createdAt, updatedAt, version, deleted

tags:           id, name, colorKey, sortOrder, isPreset, createdAt, updatedAt

change_records: id, entityType, entityId, fieldName, oldValue?, newValue?, 
                changedAt, syncStatus

sync_index:     id, dataId, dataType, localVersion, cloudVersion, updatedAt, syncStatus

device_sync_state: deviceId, lastSyncAt, lastPullAt, lastPushAt
```

---

## 四、设计系统

### 4.1 颜色 (AppColors)

| 常量 | 值 | 用途 |
|------|-----|------|
| primary | #0071E3 | 主按钮、选中态 |
| scaffoldBg | #F5F5F7 | 页面背景 |
| surface | #FFFFFF | 卡片背景 |
| text | #1D1D1F | 主文字 |
| textSecondary | #636366 | 次要文字 |
| textTertiary | #8E8E93 | 辅助文字 |
| success | #34C759 | 完成/对勾 |
| warning | #FF9500 | 延期/重要 |
| danger | #FF3B30 | 删除/紧急 |
| workBg | #E8F2FD | 工作标签背景 |

### 4.2 字体

- 中文：PingFang SC
- 等宽：SF Mono → Menlo → Monaco
- 回退：.SF Pro Text → system-ui → sans-serif

### 4.3 动画

- Checkbox：弹性缩放 (elasticOut, 300ms)
- 列表入场：渐入 + 上滑 (staggered 60ms/item)
- Tab切换：AnimatedSwitcher (200ms)
- 详情弹窗：弹性缩放 (elasticOut, 500ms)
- 卡片按压：scale 0.985 (100ms)
- 诗词轮播：fadeOut → 换行 → fadeIn (8s间隔)

---

## 五、已知状态

| 模块 | 状态 |
|------|------|
| 待办 CRUD + 滑动操作 + 优先级 | ✅ 完成 |
| 智能输入解析 | ✅ 完成 |
| 标签系统 (8色+自定义+管理) | ✅ 完成 |
| 例行系统 (重复规则+自动生成) | ✅ 完成 |
| WebDAV 双向同步 (含标签) | ✅ 完成 |
| WeekCalendarStrip 无限翻页 | ✅ 完成 |
| Profile 面板 (头像+信息+菜单) | ✅ UI完成，菜单功能空 |
| Copilot 对话 | ⚠️ 模拟回复，未接入AI |
| 记账 Tab | ❌ 占位页面 |
| 随手记 Tab | ❌ 占位页面 |
| 暗色主题 | ❌ 未实现 |
| 单元测试 | ❌ test/ 为空 |
