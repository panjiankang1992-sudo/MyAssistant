# 例行待办编辑功能实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add edit icon + swipe-to-delete to routine list items, edit dialog pre-fills routine data, edit cascades to regenerate future routine todos.

**Architecture:** Edit button opens a dialog pre-filled with routine data. Save updates routine in DB and cascades: tomorrow+30d dates that no longer match `shouldGenerateOn` get soft-deleted; dates that still match get regenerated with new routine data.

**Tech Stack:** Flutter 3.41, Riverpod 3.x, Drift ORM

---

## File Structure

| File | Responsibility |
|------|---------------|
| `data/datasources/local_datasource.dart` | Add `updateRoutine` upsert by uuid |
| `data/repositories/routine_repository.dart` | Add `updateRoutine` method |
| `features/todo/providers/todo_provider.dart` | Add `updateRoutineTodos` for cascade regenerate |
| `features/todo/providers/routine_provider.dart` | Add `updateRoutine` with cascade logic |
| `features/todo/widgets/routine_modal.dart` | Edit icon, swipe-to-delete, edit dialog |
| `assets/icons/edit.svg` | New SVG edit icon (24×24) |

---

### Task 1: Data Layer — updateRoutine

**Files:**
- Modify: `ai_assistant/lib/data/datasources/local_datasource.dart`
- Modify: `ai_assistant/lib/data/repositories/routine_repository.dart`

- [ ] **Step 1: Add `updateRoutine` to LocalDatasource**

Read `local_datasource.dart` first. Add this method to the `LocalDatasource` class. The existing `insertRoutine` uses `insertOnConflictUpdate` keyed by uuid, so to update an existing routine we can reuse that pattern — just pass the existing uuid and incremented version:

```dart
Future<void> updateRoutine(Routine routine) async {
  await _db.into(_db.routines).insertOnConflictUpdate(
    RoutinesCompanion(
      uuid: Value(routine.uuid ?? ''),
      title: Value(routine.title),
      description: Value(routine.description),
      type: Value(routine.type),
      tags: Value(encodeTags(routine.tags)),
      time: Value(routine.time),
      repeatRule: Value(routine.repeatRule),
      repeatDays: Value(routine.repeatDays),
      updatedAt: Value(DateTime.now()),
      version: Value(routine.version + 1),
      deleted: const Value(false),
    ),
  );
}
```

Note: The uuid is the conflict key. If uuid is null, use empty string as a fallback.

- [ ] **Step 2: Add `updateRoutine` to RoutineRepository**

Read `routine_repository.dart` first. Add:

```dart
Future<void> updateRoutine(Routine routine) async {
  await _datasource.updateRoutine(routine);
  _trySync();
}
```

- [ ] **Step 3: Verify**

Run: `cd /Users/pankang/mycode/MyAssistant/ai_assistant && dart analyze lib/data/datasources/local_datasource.dart lib/data/repositories/routine_repository.dart`

- [ ] **Step 4: Commit**

```bash
cd ai_assistant
git add lib/data/datasources/local_datasource.dart lib/data/repositories/routine_repository.dart
git commit -m "feat: add updateRoutine to datasource and repository"
```

---

### Task 2: Cascade Logic — updateRoutineTodos

**Files:**
- Modify: `ai_assistant/lib/features/todo/providers/todo_provider.dart`
- Modify: `ai_assistant/lib/features/todo/providers/routine_provider.dart`

- [ ] **Step 1: Add `updateRoutineTodos` to TodoProvider**

Read `todo_provider.dart` first. This method takes the old and new routine, then cascades for tomorrow+30 days. Add to `TodoNotifier`:

```dart
Future<void> updateRoutineTodos(Routine oldRoutine, Routine newRoutine) async {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  for (int offset = 1; offset <= 30; offset++) {
    final date = today.add(Duration(days: offset));

    // 不再符合新规则 → 软删除旧的
    if (!newRoutine.shouldGenerateOn(date)) {
      await _softDeleteRoutineTodo(newRoutine.title, date);
      continue;
    }

    // 原本就不符合旧规则 → 跳过
    if (!oldRoutine.shouldGenerateOn(date)) continue;

    // 符合新规则 → 软删除旧的，重新生成
    await _softDeleteRoutineTodo(newRoutine.title, date);
    await _generateSingleRoutineTodo(newRoutine, date);
  }
}

Future<void> _softDeleteRoutineTodo(String routineTitle, DateTime date) async {
  final datasource = ref.read(datasourceProvider);
  await datasource.softDeleteFutureRoutineTodos(routineTitle, date);
}

Future<void> _generateSingleRoutineTodo(Routine routine, DateTime date) async {
  final datasource = ref.read(datasourceProvider);
  final allTodos = await datasource.getAllTodos();
  final alreadyExists = allTodos.any(
    (t) => t.title == routine.title && t.source == 'routine' && t.date == date,
  );
  if (alreadyExists) return;

  final now = DateTime.now();
  final todo = Todo(
    id: const Uuid().v4(),
    title: routine.title,
    description: routine.description,
    source: 'routine',
    type: routine.type,
    tags: routine.tags,
    time: routine.time,
    date: date,
    createdAt: now,
    updatedAt: now,
  );
  final repo = ref.read(todoRepoProvider);
  await repo.addTodo(todo);
}
```

Note: The `_generateSingleRoutineTodo` creates a single todo for one date. Use `const Uuid().v4()` import at top.

Also add import for `package:uuid/uuid.dart` if not already present.

- [ ] **Step 2: Add `updateRoutine` to RoutineNotifier**

Read `routine_provider.dart` first. Add:

```dart
Future<void> updateRoutine(Routine newRoutine) async {
  final repo = ref.read(routineRepoProvider);
  final todoNotifier = ref.read(todoNotifierProvider.notifier);

  // 找到旧的 routine 用于级联判断
  final oldRoutine = state.where((r) => r.id == newRoutine.id).firstOrNull;

  // 更新 routine
  await repo.updateRoutine(newRoutine);
  await loadRoutines();

  // 级联：更新未来待办
  if (oldRoutine != null) {
    await todoNotifier.updateRoutineTodos(oldRoutine, newRoutine);
    await todoNotifier.loadTodayTodos();
  }
}
```

Add import for `package:uuid/uuid.dart` at top of `routine_provider.dart` if not present.

- [ ] **Step 3: Verify**

Run: `cd /Users/pankang/mycode/MyAssistant/ai_assistant && dart analyze lib/features/todo/providers/todo_provider.dart lib/features/todo/providers/routine_provider.dart`

- [ ] **Step 4: Commit**

```bash
cd ai_assistant
git add lib/features/todo/providers/todo_provider.dart lib/features/todo/providers/routine_provider.dart
git commit -m "feat: add updateRoutine with cascade to future todos"
```

---

### Task 3: UI — Edit Icon + Swipe Delete + Edit Dialog

**Files:**
- Create: `ai_assistant/assets/icons/edit.svg`
- Modify: `ai_assistant/lib/features/todo/widgets/routine_modal.dart`
- Modify: `ai_assistant/pubspec.yaml` (add edit.svg to assets if not already)

- [ ] **Step 1: Create edit.svg icon**

Create `ai_assistant/assets/icons/edit.svg`:

```xml
<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none">
  <path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
```

- [ ] **Step 2: Verify pubspec.yaml assets**

Read `pubspec.yaml` to confirm `assets/icons/` is listed in flutter assets. If not, add:

```yaml
flutter:
  assets:
    - assets/icons/
```

- [ ] **Step 3: Update routine_modal.dart — replace list item with swipe + edit icon**

Read `routine_modal.dart` first. The current `ListView.builder` at line 240-268 has a `ListTile` with a delete `IconButton`. Replace the entire item builder with a swipe-to-delete pattern + edit icon.

Replace the `ListView.builder` section with:

```dart
ListView.builder(
  shrinkWrap: true,
  itemCount: routines.length,
  itemBuilder: (context, index) {
    final routine = routines[index];
    return _RoutineListItem(
      routine: routine,
      onEdit: () => _showEditDialog(routine),
      onDelete: () => _confirmDelete(routine),
    );
  },
),
```

Add this new widget at the bottom of the file (before the closing `}` of `_RoutineModalContentState`):

```dart
class _RoutineListItem extends StatelessWidget {
  final Routine routine;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RoutineListItem({
    required this.routine,
    required this.onEdit,
    required this.onDelete,
  });

  String _getTypeLabel(String type) {
    switch (type) {
      case 'bill': return '帐单';
      case 'work': return '工作';
      case 'personal': return '个人';
      case 'health': return '健康';
      default: return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SwipeToDeleteRoutine(
      onDelete: onDelete,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (routine.tags.isNotEmpty)
                        ...routine.tags.take(3).map((tag) => Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: TagChip.fromTag(label: tag.name, colorKey: tag.colorKey),
                        ))
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(_getTypeLabel(routine.type), style: const TextStyle(fontSize: 11, color: AppColors.primary)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(routine.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(routine.time, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
            ),
            GestureDetector(
              onTap: onEdit,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: SvgPicture.asset(
                  'assets/icons/edit.svg',
                  width: 18,
                  height: 18,
                  colorFilter: const ColorFilter.mode(AppColors.textSecondary, BlendMode.srcIn),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwipeToDeleteRoutine extends StatefulWidget {
  final VoidCallback onDelete;
  final Widget child;

  const _SwipeToDeleteRoutine({required this.onDelete, required this.child});

  @override
  State<_SwipeToDeleteRoutine> createState() => _SwipeToDeleteRoutineState();
}

class _SwipeToDeleteRoutineState extends State<_SwipeToDeleteRoutine>
    with SingleTickerProviderStateMixin {
  double _offset = 0;
  bool _dragging = false;
  late AnimationController _controller;
  late Animation<double> _animation;

  static const double _deleteWidth = 76.0;
  static const double _triggerThreshold = 40.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _animation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    )..addListener(() {
        if (!_dragging) setState(() => _offset = _animation.value);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _animateTo(double target) {
    _animation = Tween<double>(begin: _offset, end: target).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final showDelete = _offset < -10;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (showDelete)
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 0),
              child: Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: _deleteWidth,
                  height: double.infinity,
                  child: Center(
                    child: GestureDetector(
                      onTap: () {
                        _animateTo(0);
                        widget.onDelete();
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.danger.withValues(alpha: 0.08),
                          border: Border.all(color: AppColors.danger.withValues(alpha: 0.25), width: 1.2),
                        ),
                        child: Center(
                          child: SvgPicture.asset(
                            'assets/icons/delete.svg',
                            width: 17,
                            height: 17,
                            colorFilter: const ColorFilter.mode(AppColors.danger, BlendMode.srcIn),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        GestureDetector(
          onHorizontalDragStart: (_) => _dragging = true,
          onHorizontalDragUpdate: (details) {
            setState(() {
              _offset += details.delta.dx;
              if (_offset > 0) _offset = 0;
              if (_offset < -_deleteWidth) _offset = -_deleteWidth;
            });
          },
          onHorizontalDragEnd: (details) {
            _dragging = false;
            if (_offset < -_triggerThreshold) {
              _animateTo(-_deleteWidth);
            } else {
              _animateTo(0);
            }
          },
          child: Transform.translate(
            offset: Offset(_offset, 0),
            child: widget.child,
          ),
        ),
      ],
    );
  }
}
```

Add import for `package:flutter_svg/flutter_svg.dart` at top of routine_modal.dart.

- [ ] **Step 4: Add `_showEditDialog` method to `_RoutineModalContentState`**

Add this method to `_RoutineModalContentState`. This pre-fills the add dialog with existing routine data:

```dart
Future<void> _showEditDialog(Routine routine) async {
  final titleController = TextEditingController(text: routine.title);
  final formKey = GlobalKey<FormState>();
  List<Tag> tags = List.from(routine.tags);
  final timeParts = routine.time.split(':');
  int hour = int.tryParse(timeParts[0]) ?? 9;

  await showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('编辑例行待办'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: '标题',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return '请输入标题';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TagSelector(
                    selectedTags: tags,
                    onChanged: (value) => setState(() => tags = value),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: hour,
                    decoration: const InputDecoration(
                      labelText: '时间',
                      border: OutlineInputBorder(),
                    ),
                    items: List.generate(
                      24,
                      (i) => DropdownMenuItem(
                        value: i,
                        child: Text('${i.toString().padLeft(2, '0')}:00'),
                      ),
                    ),
                    onChanged: (value) {
                      if (value != null) setState(() => hour = value);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () {
                  if (!formKey.currentState!.validate()) return;
                  final newRoutine = routine.copyWith(
                    title: titleController.text.trim(),
                    type: tags.isNotEmpty ? tags.first.name : routine.type,
                    tags: tags,
                    time: '${hour.toString().padLeft(2, '0')}:00',
                    updatedAt: DateTime.now(),
                  );
                  ref.read(routineNotifierProvider.notifier).updateRoutine(newRoutine);
                  Navigator.of(context).pop();
                },
                child: const Text('保存'),
              ),
            ],
          );
        },
      );
    },
  );
}
```

Note: `showDialog` needs to be async. The dialog closes on save/cancel with `Navigator.of(context).pop()`.

Also add import for `package:flutter_svg/flutter_svg.dart` if not already present.

- [ ] **Step 5: Verify**

Run: `cd /Users/pankang/mycode/MyAssistant/ai_assistant && dart analyze lib/features/todo/widgets/routine_modal.dart`

- [ ] **Step 6: Commit**

```bash
cd ai_assistant
git add assets/icons/edit.svg lib/features/todo/widgets/routine_modal.dart
git commit -m "feat: add edit icon and swipe-to-delete to routine list"
```

---

### Task 4: Build & Verify

**Files:**
- None (verification only)

- [ ] **Step 1: Full analyze**

Run: `cd /Users/pankang/mycode/MyAssistant/ai_assistant && dart analyze`

- [ ] **Step 2: Build macOS**

Run: `cd /Users/pankang/mycode/MyAssistant/ai_assistant && flutter build macos --release`

- [ ] **Step 3: Launch and verify**

Run: `open build/macos/Build/Products/Release/ai_assistant.app`

Manual verification:
1. 打开例行管理（点击底部添加待办旁的例行入口或从 tab 进入）
2. 已有例行列表项右侧应有笔图标（灰色）
3. 向左滑动显示删除按钮
4. 点击笔图标 → 编辑弹窗弹出，预填充当前数据
5. 修改时间或标题 → 保存 → 检查未来待办是否正确级联更新
6. 滑动删除 → 确认删除，未来待办一并删除