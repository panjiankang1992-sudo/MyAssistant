# 设计文档 — MyAssistant Flutter App v4

> 更新时间：2026-05-24。基于当前代码刷新，覆盖例行编辑、多标签、时间选择、来源/动作元数据、个人信息页与新增流程。

## 本次修正重点

- 例行编辑：按 `routines.id` 更新，不再使用 upsert 插入新行。
- 例行标签：新增/编辑均支持最多 6 个标签，保存到 `Routine.tags`。
- 新增代办：合并“智能新增/手动新增”为“新增代办”。
- AI 分析：标题输入框右侧提供 AI 图标，点击后解析标题并填充详情、标签、日期、时间、动作、优先级、来源，等待用户确认保存。
- 时间选择：`TimeInputField` 同时支持手动输入和系统时间选择器。
- 来源：固定为 AI、例行、日历、消息，使用 `SourceSelector` 图标 chip。
- 动作：固定为无动作、记账、打开应用、拨打电话、发消息，使用 `ActionSelector` 图标 chip。
- 待办卡片：右侧展示来源图标和动作图标；来源只展示，不直接操作。
- 右滑完成：滑出完成按钮后开始约 1.5 秒读秒，按钮逐步变深绿色，读秒结束自动标记完成。
- 个人信息页：去掉左上角“账户”；菜单点击后的展示逻辑统一为先关闭侧栏再打开目标；编辑个人信息去除图片按钮和输入框底纹感。

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
  id, name, color_key, sort_order, is_preset,
  created_at, updated_at

metadata_options
  id, kind(source/action), value, label, icon_key, color_key,
  sort_order, is_preset, updated_at
```

## 同步

- `tags/index.json` 同步标签元数据。
- `metadata/index.json` 同步来源/动作元数据。
- 待办和例行待办 JSON 中内联保存 `tags` 与 `action`，列表展示不联查元数据表。

## 关键交互

```text
新增代办
  标题输入 + AI 图标
    点击 AI → TodoTextParser 解析 → 回填表单
  表单确认保存

例行管理
  已有例行列表
    编辑图标 → 编辑弹窗
    左滑 → 删除按钮
  新增例行按钮
    新增弹窗，与编辑弹窗使用同一表单空间

待办列表
  右滑 → 完成倒计时 → 自动完成
  左滑 → 延期按钮 + 删除按钮
```

## 视觉规则

- 来源、动作、标签均使用轻量图标 chip，选中态使用浅色底 + 细边框。
- 时间输入框左侧为时间图标，右侧为选择按钮，中间允许直接输入。
- 个人信息页使用白底、分割线、圆形线框图标，不使用文字底纹或大面积彩色背景。
