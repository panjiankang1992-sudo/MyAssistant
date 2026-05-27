# 设计文档 — MyAssistant Flutter App v3

> 更新时间：2026-05-24。基于当前 `ai_assistant/lib` 代码实现刷新。

## 当前代码结构

- `core/database`：Drift 本地库，当前 schema v7。核心表包括 `todos`、`routines`、`tags`、`sync_index`、`device_sync_state`。
- `domain/models`：`Todo`、`Routine`、`Tag`。待办和例行待办都已支持 `tags` 与 `action`。
- `features/todo`：待办主页、历史日期、待办新增/编辑、例行管理、滑动操作、标签管理。
- `features/sync`：WebDAV 双向同步，待办、例行待办、标签元数据同步。
- `features/profile`：右侧用户信息面板与编辑弹窗。

## 本次刷新后的信息架构

```text
今日待办
├─ 顶部：头像 / 日期标题 / 日历图标
├─ WeekCalendarStrip：当前选择日期所在周
├─ TodoList
│  ├─ 右滑：完成
│  └─ 左滑：延期 + 删除
└─ 新增弹窗
   ├─ 智能新增
   ├─ 手动新增
   │  ├─ 标题 / 详情
   │  ├─ 标签选择
   │  ├─ 日期
   │  ├─ 时间输入
   │  ├─ 动作选择
   │  ├─ 来源
   │  └─ 优先级
   └─ 例行管理
      ├─ 已有例行列表：编辑图标 + 左滑删除
      └─ 共用例行表单：标签 / 时间 / 动作 / 重复规则
```

## 数据模型

```text
todos
  id, title, description, source, type(deprecated), tags(JSON),
  action, time, date, completed, priority,
  created_at, updated_at, version, deleted

routines
  id, uuid, title, description, type(deprecated), tags(JSON),
  action, time, repeat_rule, repeat_days,
  created_at, updated_at, version, deleted

tags
  id, name, color_key, sort_order, is_preset, created_at, updated_at
```

说明：
- `type` 保留兼容旧数据，新增/编辑主要使用 `tags`。
- `tags` 直接存储紧凑标签 JSON，列表展示无需联查 `tags` 表。
- `action` 是待办/例行待办的动作选项，当前为内置枚举，不做管理入口。

## 交互设计

### 待办左滑

- 左滑一段显示两个圆形按钮。
- 靠近待办的是“延期”，图标为 `more_time_rounded`，橙色细边框。
- 外侧是“删除”，使用统一垃圾桶 SVG，红色细边框。
- 点击延期弹出日期选择，默认选项包含明天、下周一、下周同日、自定义日期。

### 时间输入

- 新增 `TimeInputField`，替换原来的小时/分钟下拉框。
- 支持手动输入 `9`、`9:30`、`09:30`、`9点30`。
- 存储时归一化为 `HH:mm`。

### 动作选择

当前内置动作：
- 无动作
- 记账
- 打开应用
- 拨打电话
- 发消息

展示为一排可换行图标标签，待办卡片右侧圆形图标会随动作变化。

### 标签管理

- 新增标签区域改成轻量面板：输入框、颜色点、添加按钮。
- 标签列表改成单行管理项：标签预览、颜色点、上移、下移、删除。
- 颜色修改从脆弱的 Overlay 改为底部颜色面板，避免弹窗刷新导致崩溃。

### 用户信息页

- 右侧面板由卡片堆叠改为白底轻量列表。
- 去除菜单项的背景块和厚阴影。
- 图标统一使用圆形细边框容器。
- 退出登录使用弱红色描边按钮。

## 同步设计

- `Todo.action`、`Routine.action` 已纳入 WebDAV JSON。
- `Todo.tags`、`Routine.tags` 继续随条目内联同步。
- `tags/index.json` 作为标签元数据同步源。

## 视觉原则

- 所有高频操作按钮使用圆形、细边框、低饱和背景。
- 标签不使用厚重实心色，统一为浅底、细边、深色文字。
- 表单控件避免下拉框堆叠，优先使用直接输入和图标选项。
- 用户信息页避免文字底纹、黄色底纹、大面积色块。
