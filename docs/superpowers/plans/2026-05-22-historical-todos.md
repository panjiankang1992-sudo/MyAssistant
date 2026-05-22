# 历史待办查看功能 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a week calendar strip to the todo page that lets users switch dates to view historical (read-only) todos.

**Architecture:** Add a `selectedDateProvider` (StateProvider) watched by `TodoNotifier`. When the selected date changes, the notifier auto-reloads todos for that date. A new `WeekCalendarStrip` widget renders a swipeable week bar. Historical dates show todos in read-only mode (no FAB, no toggle, no delete).

**Tech Stack:** Flutter 3.41, Riverpod 3.x (NotifierProvider + StateProvider), existing Drift/SQLite data layer (no changes needed).

---

### Task 1: Create selectedDateProvider

**Files:**
- Create: `ai_assistant/lib/features/todo/providers/selected_date_provider.dart`

- [ ] **Step 1: Create the provider file**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

final selectedDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});
```

- [ ] **Step 2: Commit**

```bash
git add ai_assistant/lib/features/todo/providers/selected_date_provider.dart
git commit -m "feat: add selectedDateProvider for date switching"
```

---

### Task 2: Refactor TodoNotifier to support arbitrary dates

**Files:**
- Modify: `ai_assistant/lib/features/todo/providers/todo_provider.dart`

The current `TodoNotifier` only loads today's todos. We refactor it to watch `selectedDateProvider` and load todos for whatever date is selected. The routine generation logic only runs when the selected date is today.

- [ ] **Step 1: Replace the entire file content**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/providers/core_providers.dart';
import '../../../domain/models/todo.dart';
import 'selected_date_provider.dart';

class TodoNotifier extends Notifier<List<Todo>> {
  @override
  List<Todo> build() {
    final selectedDate = ref.watch(selectedDateProvider);
    _loadTodosForDate(selectedDate);
    return [];
  }

  Future<void> _loadTodosForDate(DateTime date) async {
    final repo = ref.read(todoRepoProvider);
    final todos = await repo.getTodosByDate(date);
    state = todos;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (date == today) {
      await _generateRoutineTodos();
    }
  }

  Future<void> _generateRoutineTodos() async {
    final routineRepo = ref.read(routineRepoProvider);
    final todoRepo = ref.read(todoRepoProvider);
    final routines = await routineRepo.getRoutines();
    if (routines.isEmpty) return;

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final existingTodos = state;

    for (final routine in routines) {
      if (!routine.shouldGenerateOn(todayDate)) continue;

      final alreadyExists = existingTodos.any(
        (t) => t.title == routine.title && t.source == 'routine' && t.date == todayDate,
      );
      if (alreadyExists) continue;

      final todo = Todo(
        id: const Uuid().v4(),
        title: routine.title,
        description: routine.description,
        source: 'routine',
        type: routine.type,
        time: routine.time,
        date: todayDate,
        createdAt: today,
        updatedAt: today,
      );
      await todoRepo.addTodo(todo);
    }

    state = await todoRepo.getTodayTodos();
  }

  Future<void> loadTodayTodos() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    ref.read(selectedDateProvider.notifier).state = today;
  }

  Future<void> addTodo(Todo todo) async {
    final repo = ref.read(todoRepoProvider);
    await repo.addTodo(todo);
    final selectedDate = ref.read(selectedDateProvider);
    await _loadTodosForDate(selectedDate);
  }

  Future<void> toggleComplete(String id) async {
    final repo = ref.read(todoRepoProvider);
    await repo.toggleTodo(id);
    final selectedDate = ref.read(selectedDateProvider);
    await _loadTodosForDate(selectedDate);
  }

  Future<void> deleteTodo(String id) async {
    final repo = ref.read(todoRepoProvider);
    await repo.deleteTodo(id);
    final selectedDate = ref.read(selectedDateProvider);
    await _loadTodosForDate(selectedDate);
  }
}

final todoNotifierProvider = NotifierProvider<TodoNotifier, List<Todo>>(TodoNotifier.new);
```

Key changes from original:
- `build()` watches `selectedDateProvider` — when date changes, notifier rebuilds and reloads
- `_loadTodosForDate(date)` replaces `loadTodayTodos()` as the core loader
- `loadTodayTodos()` now resets `selectedDateProvider` to today (which triggers the watch → rebuild)
- All mutation methods (`addTodo`, `toggleComplete`, `deleteTodo`) reload for the current selected date instead of hardcoding today
- Routine generation only fires when selected date is today

- [ ] **Step 2: Commit**

```bash
git add ai_assistant/lib/features/todo/providers/todo_provider.dart
git commit -m "refactor: TodoNotifier watches selectedDateProvider for date-switched loading"
```

---

### Task 3: Create WeekCalendarStrip widget

**Files:**
- Create: `ai_assistant/lib/features/todo/widgets/week_calendar_strip.dart`

- [ ] **Step 1: Create the widget file**

```dart
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class WeekCalendarStrip extends StatefulWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  const WeekCalendarStrip({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  State<WeekCalendarStrip> createState() => _WeekCalendarStripState();
}

class _WeekCalendarStripState extends State<WeekCalendarStrip> {
  late PageController _pageController;
  late DateTime _initialWeekStart;

  static const _weekdays = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  void initState() {
    super.initState();
    _initialWeekStart = _mondayOfWeek(widget.selectedDate);
    _pageController = PageController(initialPage: 52); // middle of 104 pages
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  DateTime _mondayOfWeek(DateTime date) {
    final d = date.weekday;
    return DateTime(date.year, date.month, date.day).subtract(Duration(days: d - 1));
  }

  DateTime _weekStartForPage(int page) {
    return _initialWeekStart.add(Duration(days: (page - 52) * 7));
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return SizedBox(
      height: 64,
      child: PageView.builder(
        controller: _pageController,
        itemCount: 104,
        itemBuilder: (context, page) {
          final weekStart = _weekStartForPage(page);
          return Row(
            children: List.generate(7, (i) {
              final day = weekStart.add(Duration(days: i));
              final isToday = _isSameDay(day, today);
              final isSelected = _isSameDay(day, widget.selectedDate);

              return Expanded(
                child: GestureDetector(
                  onTap: () => widget.onDateSelected(day),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _weekdays[i],
                        style: TextStyle(
                          fontFamily: 'PingFang SC',
                          fontFamilyFallback: const ['.SF Pro Text', 'system-ui', 'sans-serif'],
                          fontSize: 10,
                          fontWeight: FontWeight.w400,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? (isToday ? AppColors.primary : AppColors.primaryLight)
                              : Colors.transparent,
                        ),
                        child: Center(
                          child: Text(
                            '${day.day}',
                            style: TextStyle(
                              fontFamily: 'PingFang SC',
                              fontFamilyFallback: const ['.SF Pro Text', 'system-ui', 'sans-serif'],
                              fontSize: 15,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                              color: isSelected
                                  ? (isToday ? Colors.white : AppColors.primary)
                                  : (isToday ? AppColors.primary : AppColors.text),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add ai_assistant/lib/features/todo/widgets/week_calendar_strip.dart
git commit -m "feat: add WeekCalendarStrip widget with swipeable week view"
```

---

### Task 4: Add readOnly support to TodoList and TodoItem

**Files:**
- Modify: `ai_assistant/lib/features/todo/widgets/todo_list.dart`
- Modify: `ai_assistant/lib/features/todo/widgets/todo_item.dart`

- [ ] **Step 1: Add `readOnly` parameter to TodoItem**

In `todo_item.dart`, add a `readOnly` field and conditionally disable toggle and long-press:

Change the class declaration from:
```dart
class TodoItem extends StatefulWidget {
  final Todo todo;
  final VoidCallback? onTap;
  final VoidCallback? onToggle;
  final VoidCallback? onLongPress;
```
to:
```dart
class TodoItem extends StatefulWidget {
  final Todo todo;
  final bool readOnly;
  final VoidCallback? onTap;
  final VoidCallback? onToggle;
  final VoidCallback? onLongPress;
```

Change the constructor from:
```dart
  const TodoItem({
    super.key,
    required this.todo,
    this.onTap,
    this.onToggle,
    this.onLongPress,
  });
```
to:
```dart
  const TodoItem({
    super.key,
    required this.todo,
    this.readOnly = false,
    this.onTap,
    this.onToggle,
    this.onLongPress,
  });
```

In the `build` method, change the checkbox `GestureDetector` from:
```dart
                GestureDetector(
                  onTap: widget.onToggle,
```
to:
```dart
                GestureDetector(
                  onTap: widget.readOnly ? null : widget.onToggle,
```

And change the outer `GestureDetector` from:
```dart
    return GestureDetector(
      onTapDown: (_) => setState(() => _itemPressed = true),
      onTapUp: (_) => setState(() => _itemPressed = false),
      onTapCancel: () => setState(() => _itemPressed = false),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
```
to:
```dart
    return GestureDetector(
      onTapDown: widget.readOnly ? null : (_) => setState(() => _itemPressed = true),
      onTapUp: widget.readOnly ? null : (_) => setState(() => _itemPressed = false),
      onTapCancel: widget.readOnly ? null : () => setState(() => _itemPressed = false),
      onTap: widget.onTap,
      onLongPress: widget.readOnly ? null : widget.onLongPress,
```

- [ ] **Step 2: Add `readOnly` parameter to TodoList**

In `todo_list.dart`, add the `readOnly` field and pass it through:

Change the class fields from:
```dart
class TodoList extends StatelessWidget {
  final List<Todo> todos;
  final bool isLoading;
  final void Function(Todo) onToggle;
  final void Function(Todo) onDelete;
  final void Function(Todo) onTap;
```
to:
```dart
class TodoList extends StatelessWidget {
  final List<Todo> todos;
  final bool isLoading;
  final bool readOnly;
  final void Function(Todo) onToggle;
  final void Function(Todo) onDelete;
  final void Function(Todo) onTap;
```

Change the constructor from:
```dart
  const TodoList({
    super.key,
    required this.todos,
    this.isLoading = false,
    required this.onToggle,
    required this.onDelete,
    required this.onTap,
  });
```
to:
```dart
  const TodoList({
    super.key,
    required this.todos,
    this.isLoading = false,
    this.readOnly = false,
    required this.onToggle,
    required this.onDelete,
    required this.onTap,
  });
```

In the `build` method, pass `readOnly` to `TodoItem` and skip the delete action sheet in readOnly mode. Change the `itemBuilder` body from:
```dart
        final todo = todos[index];
        return _StaggeredItem(
          index: index,
          child: TodoItem(
            todo: todo,
            onTap: () => onTap(todo),
            onToggle: () => onToggle(todo),
            onLongPress: () => _showDeleteActionSheet(context, todo),
          ),
        );
```
to:
```dart
        final todo = todos[index];
        return _StaggeredItem(
          index: index,
          child: TodoItem(
            todo: todo,
            readOnly: readOnly,
            onTap: () => onTap(todo),
            onToggle: () => onToggle(todo),
            onLongPress: readOnly ? null : () => _showDeleteActionSheet(context, todo),
          ),
        );
```

- [ ] **Step 3: Commit**

```bash
git add ai_assistant/lib/features/todo/widgets/todo_item.dart ai_assistant/lib/features/todo/widgets/todo_list.dart
git commit -m "feat: add readOnly mode to TodoList and TodoItem"
```

---

### Task 5: Integrate WeekCalendarStrip into TodoPage

**Files:**
- Modify: `ai_assistant/lib/features/todo/todo_page.dart`

This is the main integration task. We add the calendar strip, make the title dynamic, and hide the FAB for non-today dates.

- [ ] **Step 1: Replace the entire file content**

```dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/core_providers.dart';
import 'providers/todo_provider.dart';
import 'providers/selected_date_provider.dart';
import 'widgets/add_todo_modal.dart';
import 'widgets/todo_detail_modal.dart';
import 'widgets/todo_list.dart';
import 'widgets/week_calendar_strip.dart';
import '../../core/theme/app_theme.dart';
import '../profile/profile_provider.dart';
import 'package:intl/intl.dart';

class TodoPage extends ConsumerStatefulWidget {
  final VoidCallback? onAvatarTap;

  const TodoPage({super.key, this.onAvatarTap});

  @override
  ConsumerState<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends ConsumerState<TodoPage> with TickerProviderStateMixin {
  final _poetryLines = [
    '山重水复疑无路，柳暗花明又一村。',
    '长风破浪会有时，直挂云帆济沧海。',
    '莫愁前路无知己，天下谁人不识君。',
    '会当凌绝顶，一览众山小。',
    '纸上得来终觉浅，绝知此事要躬行。',
    '不畏浮云遮望望眼，自缘身在最高层。',
  ];
  static const _avatarColors = [
    [Color(0xFF667EEA), Color(0xFF764BA2)],
    [Color(0xFF0071E3), Color(0xFF00C6FF)],
    [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
    [Color(0xFF34C759), Color(0xFF30D5C8)],
    [Color(0xFFFF9500), Color(0xFFFF5E3A)],
    [Color(0xFFAF52DE), Color(0xFF5856D6)],
  ];
  int _poetryIndex = 0;
  Timer? _poetryTimer;
  bool _poetryVisible = true;

  Offset _fabOffset = Offset.zero;

  @override
  void initState() {
    super.initState();
    _poetryTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) {
        setState(() => _poetryVisible = false);
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            setState(() {
              _poetryIndex = (_poetryIndex + 1) % _poetryLines.length;
              _poetryVisible = true;
            });
          }
        });
      },
    );
  }

  @override
  void dispose() {
    _poetryTimer?.cancel();
    super.dispose();
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  String _titleForDate(DateTime date) {
    if (_isToday(date)) return '今日待办';
    return '${date.month}月${date.day}日 待办';
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(selectedDateProvider);
    final todos = ref.watch(todoNotifierProvider);
    final isToday = _isToday(selectedDate);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Text(
                            _titleForDate(selectedDate),
                            key: ValueKey(selectedDate),
                            style: const TextStyle(
                              fontFamily: 'PingFang SC',
                              fontFamilyFallback: ['.SF Pro Text', 'system-ui', 'sans-serif'],
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                              color: AppColors.text,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        AnimatedOpacity(
                          opacity: _poetryVisible ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            _poetryLines[_poetryIndex],
                            style: const TextStyle(
                              fontFamily: 'PingFang SC',
                              fontFamilyFallback: ['.SF Pro Text', 'system-ui', 'sans-serif'],
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              fontStyle: FontStyle.italic,
                              color: AppColors.textTertiary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _AvatarButton(
                    onTap: widget.onAvatarTap,
                    letter: ref.watch(profileProvider).name.isNotEmpty
                        ? ref.watch(profileProvider).name[0]
                        : '?',
                    gradientColors: _avatarColors[ref.watch(profileProvider).avatarColorIndex.clamp(0, _avatarColors.length - 1)],
                    serverAvatarUrl: ref.watch(profileProvider).serverAvatarUrl,
                    localAvatarPath: ref.watch(profileProvider).avatarPath,
                  ),
                ],
              ),
            ),
            WeekCalendarStrip(
              selectedDate: selectedDate,
              onDateSelected: (date) {
                ref.read(selectedDateProvider.notifier).state = date;
              },
            ),
            Expanded(
              child: TodoList(
                todos: todos,
                readOnly: !isToday,
                onToggle: (todo) {
                  ref.read(todoNotifierProvider.notifier).toggleComplete(todo.id);
                },
                onDelete: (todo) {
                  ref.read(todoNotifierProvider.notifier).deleteTodo(todo.id);
                },
                onTap: (todo) {
                  showTodoDetail(context, todo);
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: isToday
          ? _DraggableFAB(
              offset: _fabOffset,
              onOffsetChanged: (o) => setState(() => _fabOffset = o),
              onPressed: () => showAddTodoModal(context),
            )
          : null,
    );
  }
}

class _DraggableFAB extends StatefulWidget {
  final Offset offset;
  final ValueChanged<Offset> onOffsetChanged;
  final VoidCallback onPressed;

  const _DraggableFAB({
    required this.offset,
    required this.onOffsetChanged,
    required this.onPressed,
  });

  @override
  State<_DraggableFAB> createState() => _DraggableFABState();
}

class _DraggableFABState extends State<_DraggableFAB> {
  Offset _offset = Offset.zero;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _offset = widget.offset;
  }

  @override
  void didUpdateWidget(covariant _DraggableFAB oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.offset != oldWidget.offset) {
      _offset = widget.offset;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: _offset,
      child: GestureDetector(
        onPanStart: (_) => setState(() => _isDragging = true),
        onPanUpdate: (details) {
          setState(() => _offset += details.delta);
          widget.onOffsetChanged(_offset);
        },
        onPanEnd: (_) {
          Future.microtask(() => setState(() => _isDragging = false));
        },
        onTap: _isDragging ? null : widget.onPressed,
        child: FloatingActionButton(
          onPressed: widget.onPressed,
          backgroundColor: AppColors.primary,
          elevation: 4,
          highlightElevation: 6,
          child: const Icon(Icons.add, size: 22, color: Colors.white),
        ),
      ),
    );
  }
}

class _AvatarButton extends StatefulWidget {
  final VoidCallback? onTap;
  final String letter;
  final List<Color> gradientColors;
  final String? serverAvatarUrl;
  final String? localAvatarPath;

  _AvatarButton({this.onTap, this.letter = '?', this.gradientColors = const [Color(0xFF667EEA), Color(0xFF764BA2)], this.serverAvatarUrl, this.localAvatarPath});

  @override
  State<_AvatarButton> createState() => _AvatarButtonState();
}

class _AvatarButtonState extends State<_AvatarButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    Widget avatarChild;
    if (widget.serverAvatarUrl != null && widget.serverAvatarUrl!.isNotEmpty) {
      final url = widget.serverAvatarUrl!;
      if (url.startsWith('data:')) {
        final base64Str = url.split(',').last;
        try {
          final bytes = base64Decode(base64Str);
          avatarChild = ClipOval(
            child: Image.memory(bytes, width: 40, height: 40, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildGradientAvatar()),
          );
        } catch (_) {
          avatarChild = _buildGradientAvatar();
        }
      } else {
        avatarChild = ClipOval(
          child: Image.network(url, width: 40, height: 40, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildGradientAvatar()),
        );
      }
    } else if (widget.localAvatarPath != null && widget.localAvatarPath!.isNotEmpty) {
      avatarChild = ClipOval(
        child: Image.file(
          File(widget.localAvatarPath!),
          width: 40, height: 40, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildGradientAvatar(),
        ),
      );
    } else {
      avatarChild = _buildGradientAvatar();
    }

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: avatarChild,
      ),
    );
  }

  Widget _buildGradientAvatar() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: widget.gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x33764BA2),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          widget.letter,
          style: TextStyle(
            fontFamily: 'PingFang SC',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
```

Key changes from original `todo_page.dart`:
- Added imports for `selectedDateProvider`, `WeekCalendarStrip`, and `intl`
- `build()` now watches `selectedDateProvider` and derives `isToday`
- Title uses `_titleForDate(selectedDate)` with `AnimatedSwitcher`
- `WeekCalendarStrip` inserted between title row and `TodoList`
- `TodoList` receives `readOnly: !isToday`
- FAB is `null` when not today (conditionally rendered)
- Removed `initState` profile fetch / todo load logic (handled by provider lifecycle)
- Added `TodoRepository` import removed since we no longer call `ref.read(todoRepoProvider)` directly in initState

- [ ] **Step 2: Commit**

```bash
git add ai_assistant/lib/features/todo/todo_page.dart
git commit -m "feat: integrate WeekCalendarStrip into TodoPage with date-switched view"
```

---

### Task 6: Update callers of todoNotifierProvider

**Files:**
- Modify: `ai_assistant/lib/features/todo/widgets/add_todo_modal.dart`
- Modify: `ai_assistant/lib/features/todo/providers/routine_provider.dart`

The `add_todo_modal.dart` calls `ref.read(todoNotifierProvider.notifier).addTodo(todo)`. Since `todoNotifierProvider` is still a regular `NotifierProvider` (not family), the `.notifier` access syntax is unchanged. No changes needed in `add_todo_modal.dart`.

The `routine_provider.dart` calls `ref.read(todoNotifierProvider.notifier).loadTodayTodos()`. This still works since `loadTodayTodos()` was preserved as a method that resets `selectedDateProvider` to today. No changes needed in `routine_provider.dart`.

- [ ] **Step 1: Verify no changes needed — commit empty if already correct**

Run: `cd ai_assistant && dart analyze lib/features/todo/widgets/add_todo_modal.dart lib/features/todo/providers/routine_provider.dart`
Expected: No errors related to `todoNotifierProvider`

If errors found, fix them. Otherwise no commit needed.

---

### Task 7: Add getTodosByDate to TodoRepository

**Files:**
- Modify: `ai_assistant/lib/data/repositories/todo_repository.dart`

The refactored `TodoNotifier` calls `repo.getTodosByDate(date)` but the current `TodoRepository` only has `getTodayTodos()`. We need to add the generic method.

- [ ] **Step 1: Add getTodosByDate method**

In `todo_repository.dart`, add this method after `getTodayTodos`:

```dart
  Future<List<Todo>> getTodosByDate(DateTime date) async {
    return _datasource.getTodosByDate(date);
  }
```

The full file becomes:

```dart
import 'dart:async';
import '../../domain/models/todo.dart';
import '../datasources/local_datasource.dart';
import '../../features/sync/sync_engine.dart';

class TodoRepository {
  final LocalDatasource _datasource;
  final Future<SyncEngine?> Function() _syncEngine;

  TodoRepository(this._datasource, {Future<SyncEngine?> Function()? syncEngine})
    : _syncEngine = syncEngine ?? (() async => null);

  Future<List<Todo>> getTodayTodos() async {
    return _datasource.getTodosByDate(DateTime.now());
  }

  Future<List<Todo>> getTodosByDate(DateTime date) async {
    return _datasource.getTodosByDate(date);
  }

  Future<void> addTodo(Todo todo) async {
    await _datasource.insertTodo(todo);
    _trySync();
  }

  Future<void> updateTodo(Todo todo) async {
    await _datasource.updateTodo(todo);
    _trySync();
  }

  Future<void> toggleTodo(String id) async {
    final todos = await _datasource.getAllTodos();
    final todo = todos.firstWhere((t) => t.id == id);
    await _datasource.toggleComplete(id, !todo.completed);
    _trySync();
  }

  Future<void> deleteTodo(String id) async {
    await _datasource.softDeleteTodo(id);
    _trySync();
  }

  void _trySync() {
    _syncEngine().then((engine) {
      if (engine != null) {
        engine.sync('todos');
      }
    });
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add ai_assistant/lib/data/repositories/todo_repository.dart
git commit -m "feat: add getTodosByDate to TodoRepository"
```

---

### Task 8: Verify build and analyze

- [ ] **Step 1: Run dart analyze**

Run: `cd ai_assistant && dart analyze`
Expected: No errors

- [ ] **Step 2: Run flutter build for macOS (dry run)**

Run: `cd ai_assistant && flutter build macos --debug 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 3: Final commit if any fixes were needed**

If any fixes were required during verification, commit them:
```bash
git add -A
git commit -m "fix: resolve analysis errors from historical todos integration"
```
