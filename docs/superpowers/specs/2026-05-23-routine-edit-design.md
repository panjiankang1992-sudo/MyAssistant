# 例行待办编辑功能设计

## 目标

在例行管理列表中为每个例行代办增加编辑入口（笔图标）和滑动删除（与待办列表一致），编辑后自动级联更新未来待办。

## 交互设计

### 例行列表项

每个列表项右侧有两个操作入口：

- **笔图标**（主要操作）：点击打开编辑弹窗，风格与删除图标一致
- **向左滑动**：显示删除按钮（与待办列表 `_SwipeToDelete` 组件一致），点击删除

笔图标和删除按钮视觉风格统一：都是 24×24 触控区域，使用 SVG 图标，笔图标颜色 `AppColors.textSecondary`，删除图标颜色 `AppColors.danger`。

### 编辑弹窗

复用现有的添加例行弹窗逻辑，但预填充当前例行的数据（标题、时间、标签、重复规则等）。弹窗标题改为"编辑例行待办"，保存按钮文案改为"保存"。

### 级联更新逻辑

编辑例行保存时：

1. 更新本地数据库中的例行记录（version +1）
2. 删除未来不符合新规则的待办（时间 > now 的、但不再符合 `shouldGenerateOn` 的）
3. 生成新的未来待办（时间 > now 的、且符合新 `shouldGenerateOn` 的）

具体时间判断：以**当前时间**为基准，`HH:mm` 格式的时间字符串转分钟数比较。时间字符串 `HH:mm` → `hour * 60 + minute`，比这个分钟数大的视为"未来时间"。

编辑后重新生成待办的范围：明天起向后30天内。

## 数据模型

无新增数据模型变更。Routine 模型已有 `tags`、`version` 等字段。

## 代码改动范围

| 文件 | 改动 |
|------|------|
| `features/todo/widgets/routine_modal.dart` | 将 `_confirmDelete` 改为滑动删除；添加编辑入口和编辑弹窗 |
| `features/todo/providers/routine_provider.dart` | 添加 `updateRoutine` 方法（含级联逻辑） |
| `features/todo/providers/todo_provider.dart` | 添加 `updateRoutineTodos` 方法：删除未来待办 + 生成新待办 |
| `data/repositories/routine_repository.dart` | 添加 `updateRoutine` 方法 |
| `data/datasources/local_datasource.dart` | 添加 `updateRoutine` 方法（upsert by uuid） |

## 级联算法

```dart
Future<void> cascadeUpdate(Routine oldRoutine, Routine newRoutine) async {
  final now = DateTime.now();
  final nowMinutes = now.hour * 60 + now.minute;

  // 解析新时间
  final parts = newRoutine.time.split(':');
  final newMinutes = int.parse(parts[0]) * 60 + int.parse(parts[1]);

  // 明天起向后30天
  for (int offset = 1; offset <= 30; offset++) {
    final date = today.add(Duration(days: offset));

    // 不再符合新规则 → 删除
    if (!newRoutine.shouldGenerateOn(date)) {
      await _deleteRoutineTodo(newRoutine.title, date);
      continue;
    }

    // 原本就不符合旧规则且不符合新规则 → 跳过
    if (!oldRoutine.shouldGenerateOn(date)) continue;

    // 原本符合但新时间 > nowMinutes → 删除旧的，重新生成
    // 注意：这里判断的是"原本的日期"是否应该生成，
    // 而"时间"只在编辑了时间字段时需要重新判断
    final dateStr = date.toIso8601String().split('T').first;
    await _deleteRoutineTodo(newRoutine.title, date);
    await _generateRoutineTodo(newRoutine, date);
  }
}
```

**简化逻辑**：编辑例行后，直接对明天起30天进行遍历：
- 如果该日期**不符合新规则的 `shouldGenerateOn`** → 软删除对应的待办
- 如果该日期**符合新规则** → 软删除旧的（按标题+日期匹配），然后生成新的

时间字段变更时无需特殊处理——因为旧待办按标题+日期匹配会被删除，新待办以新时间生成。
