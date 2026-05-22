# 历史待办查看功能设计

## 概述

在待办页顶部添加周历条（WeekCalendarStrip），支持按日期切换查看历史待办。历史日期的待办为只读，今天待办保持原有全部交互。

## UI 布局

当前布局：`标题行 → TodoList`

新布局：`标题行 → WeekCalendarStrip → TodoList`

### WeekCalendarStrip 交互

- 显示当前周 7 天（周一到周日），每天一格：星期缩写 + 日期数字
- 左右滑动切换上一周/下一周（PageView 实现）
- 点击某天加载该天待办
- 今天：主色圆形背景 + 白色文字
- 选中非今天：浅主色圆形背景 + 主色数字
- 未选中：普通文字
- 高度约 60-70pt，固定在标题下方不随列表滚动

### 标题区变化

- 选中今天：显示"今日待办"（与当前一致）
- 选中非今天：显示"3月15日 待办"格式
- 诗词轮播保持不变

### 只读行为

- 非今天日期：隐藏 FAB 新增按钮，长按不弹删除菜单，完成勾选不可点击
- 今天：所有操作不变（新增、完成、删除、长按删除）

## 状态管理

### selectedDateProvider

新增 `StateProvider<DateTime>`，默认值为今天零时（`DateTime(now.year, now.month, now.day)`）。

文件：`features/todo/providers/selected_date_provider.dart`

### TodoNotifier 改为 family provider

```dart
final todoNotifierProvider = NotifierProvider.family<TodoNotifier, List<Todo>, DateTime>(TodoNotifier.new);
```

- `build(selectedDate)` 中根据 selectedDate 加载对应日期待办
- selectedDate 变化时自动重新加载
- 例行待办生成逻辑仅在 selectedDate == today 时执行

### TodoPage 消费方式

```dart
final selectedDate = ref.watch(selectedDateProvider);
final todos = ref.watch(todoNotifierProvider(selectedDate));
final isToday = selectedDate == DateTime(now.year, now.month, now.day);
```

## 数据层

无需改动。`LocalDatasource.getTodosByDate(date)` 已支持按任意日期查询。

## 组件拆分

### 新增

| 组件 | 文件 | 说明 |
|------|------|------|
| `WeekCalendarStrip` | `features/todo/widgets/week_calendar_strip.dart` | 周历条，入参 selectedDate + onDateSelected |
| `selectedDateProvider` | `features/todo/providers/selected_date_provider.dart` | 选中日期状态 |

### 修改

| 组件 | 变更 |
|------|------|
| `TodoPage` | 嵌入 WeekCalendarStrip，标题动态化，非今天隐藏 FAB |
| `TodoNotifier` | 改为 family provider，依赖 selectedDate 加载 |
| `TodoList` | 新增 `readOnly` 参数，readOnly 时禁用长按删除 |

### 不改动

- `LocalDatasource`、`TodoRepository` — 已有按日期查询能力
- `TodoItem` — 交互不变
- 数据库 schema — 无需变更
