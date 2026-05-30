import '../../../data/datasources/local_datasource.dart';
import '../../../domain/models/quick_note.dart';
import '../../../domain/models/todo.dart';
import '../bookkeeping/bookkeeping_page.dart';
import '../notes/notes_store.dart';
import '../profile/profile_provider.dart';

class AppDataSkillService {
  final LocalDatasource datasource;
  final UserProfile profile;
  final BookkeepingStore bookkeepingStore;
  final NotesStore notesStore;

  AppDataSkillService({
    required this.datasource,
    required this.profile,
    BookkeepingStore? bookkeepingStore,
    NotesStore? notesStore,
  }) : bookkeepingStore =
           bookkeepingStore ??
           BookkeepingStore(datasource.database, datasource),
       notesStore = notesStore ?? NotesStore(datasource.database);

  Future<AppDataSkillResult> buildFor(String input) async {
    final todos = await datasource.getAllTodos();
    final routines = await datasource.getAllRoutines();
    final tags = await datasource.getAllTags();
    final metadata = await datasource.getMetadataOptions();
    final entries = await bookkeepingStore.loadEntries();
    final notes = await notesStore.load();
    final snapshot = AppDataSnapshot(
      todos: todos.where((item) => !item.deleted).toList()..sort(_sortTodo),
      routineCount: routines.length,
      tagNames: tags
          .map((t) => t.name)
          .where((name) => name.isNotEmpty)
          .toList(),
      sourceLabels: metadata
          .where((m) => m.kind == 'source')
          .map((m) => m.label)
          .where((label) => label.isNotEmpty)
          .toList(),
      actionLabels: metadata
          .where((m) => m.kind == 'action')
          .map((m) => m.label)
          .where((label) => label.isNotEmpty)
          .toList(),
      ledgerEntries: entries,
      notes: notes.where((item) => !item.deleted).toList(),
    );

    return AppDataSkillResult(
      snapshot: snapshot,
      directAnswer: _directAnswer(input, snapshot),
      promptContext: _promptContext(snapshot),
      fallbackAnswer: _overview(snapshot),
    );
  }

  static int _sortTodo(Todo a, Todo b) {
    final byDate = a.date.compareTo(b.date);
    if (byDate != 0) return byDate;
    return a.time.compareTo(b.time);
  }

  String? _directAnswer(String input, AppDataSnapshot snapshot) {
    if (_wantsSkillList(input)) return null;
    if (_mentionsAny(input, const ['账单', '记账', '收支', '消费', '收入'])) {
      return _ledgerSummary(snapshot.ledgerEntries, _targetDate(input));
    }
    if (_mentionsAny(input, const ['随手记', '日记', '文档', '归纳'])) {
      return _noteSummary(snapshot.notes);
    }
    if (_mentionsAny(input, const ['代办', '待办', '日程', '例行'])) {
      return _todoSummary(
        snapshot.todos,
        _targetDate(input),
        _targetTitle(input),
      );
    }
    if (_mentionsAny(input, const ['统计', '分析', '应用内', '所有数据', '我的数据'])) {
      return _overview(snapshot);
    }
    return null;
  }

  String _promptContext(AppDataSnapshot snapshot) {
    return [
      'app_data skill 已授权并已读取本应用本地数据库和本地配置。',
      '下面是真实应用数据摘要，不是用户手工提供的文本：',
      _overview(snapshot),
      '',
      '输出约束：',
      '- 查询类回答优先使用 Markdown 表格。',
      '- 代办状态必须使用红黄绿灯：🔴 逾期，🟡 待处理，🟢 已完成。',
      '- 不要暴露 source/action/routine 等内部枚举值，改用中文标签。',
      '- 金额统一保留两位小数，负数用“支出”，正数用“收入/结余”。',
    ].join('\n');
  }

  String _overview(AppDataSnapshot snapshot) {
    final openTodos = snapshot.todos.where((item) => !item.completed).length;
    final doneTodos = snapshot.todos.length - openTodos;
    final overdue = snapshot.todos
        .where((item) => _todoLight(item).level == 3)
        .length;
    final pending = snapshot.todos
        .where((item) => _todoLight(item).level == 2)
        .length;
    final ledgerExpense = snapshot.ledgerEntries
        .where((item) => item.kind == LedgerKind.expense)
        .fold<double>(0, (sum, item) => sum + item.cnyAmount.abs());
    final ledgerIncome = snapshot.ledgerEntries
        .where((item) => item.kind == LedgerKind.income)
        .fold<double>(0, (sum, item) => sum + item.cnyAmount.abs());
    final activeNotes = snapshot.notes.where((item) => !item.archived).length;
    final analysisDocs = snapshot.notes.where((item) => item.isAnalysis).length;
    return [
      '## 应用数据概览',
      '',
      '| 模块 | 状态 | 数据 | 重点 |',
      '|---|---:|---:|---|',
      '| 代办 | ${overdue > 0
          ? "🔴"
          : pending > 0
          ? "🟡"
          : "🟢"} | ${snapshot.todos.length} 条 | 未完成 $openTodos，已完成 $doneTodos，逾期 $overdue |',
      '| 例行 | 🟡 | ${snapshot.routineCount} 条 | 会自动生成未来待办 |',
      '| 记账 | ${ledgerExpense > ledgerIncome ? "🔴" : "🟢"} | ${snapshot.ledgerEntries.length} 笔 | 收入 ¥${_money(ledgerIncome)}，支出 ¥${_money(ledgerExpense)} |',
      '| 随手记 | 🟢 | $activeNotes 篇 | 归纳文档 $analysisDocs 篇 |',
      '',
      '**常用查询 skill**',
      '- `todo_query`：按日期查询代办，红黄绿灯状态列表。',
      '- `todo_stats`：统计完成率、逾期、标签、来源和动作。',
      '- `ledger_query`：按日期查询账单和收支结余。',
      '- `ledger_stats`：按分类汇总消费、收入和净额。',
      '- `note_query`：查询日记、文档、归纳文档和最近更新。',
      '- `app_overview`：汇总代办、记账、随手记的整体状态。',
    ].join('\n');
  }

  String _todoSummary(List<Todo> todos, DateTime target, String title) {
    final items = todos.where((item) => _sameDay(item.date, target)).toList()
      ..sort((a, b) => a.time.compareTo(b.time));
    if (items.isEmpty) {
      return '## $title代办 · ${_date(target)}\n\n🟢 这天没有代办。';
    }
    final open = items.where((item) => !item.completed).length;
    final done = items.length - open;
    final overdue = items.where((item) => _todoLight(item).level == 3).length;
    final pending = items.where((item) => _todoLight(item).level == 2).length;
    final rows = items.map(_todoRow).join('\n');
    return [
      '## $title代办 · ${_date(target)}',
      '',
      '**红黄绿灯**  🔴 逾期 $overdue  ·  🟡 待处理 $pending  ·  🟢 已完成 $done',
      '',
      '| 状态 | 时间 | 事项 | 标签 | 来源 | 动作 |',
      '|---|---:|---|---|---|---|',
      rows,
      '',
      '> 共 ${items.length} 条，未完成 $open 条，完成率 ${_percent(done, items.length)}。',
    ].join('\n');
  }

  String _todoRow(Todo item) {
    final light = _todoLight(item);
    final tags = item.tags.isEmpty
        ? '无'
        : item.tags
              .map((tag) => tag.name)
              .where((name) => name.isNotEmpty)
              .join('、');
    return '| ${light.icon} ${light.label} | ${item.time} | ${_escapeCell(item.title)} | ${_escapeCell(tags)} | ${_sourceLabel(item.source)} | ${_actionLabel(item.action)} |';
  }

  _TodoLight _todoLight(Todo item) {
    if (item.completed) return const _TodoLight('🟢', '已完成', 1);
    final now = DateTime.now();
    final due = _dateTimeOf(item);
    if (due.isBefore(now)) {
      return const _TodoLight('🔴', '逾期', 3);
    }
    return const _TodoLight('🟡', '待处理', 2);
  }

  DateTime _dateTimeOf(Todo item) {
    final parts = item.time.split(':');
    if (parts.length < 2) {
      return DateTime(item.date.year, item.date.month, item.date.day);
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return DateTime(item.date.year, item.date.month, item.date.day);
    }
    return DateTime(
      item.date.year,
      item.date.month,
      item.date.day,
      hour,
      minute,
    );
  }

  String _ledgerSummary(List<LedgerEntry> entries, DateTime target) {
    final items = entries.where((item) => _sameDay(item.date, target)).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    if (items.isEmpty) {
      return '## 记账 · ${_date(target)}\n\n🟢 这天没有账单。';
    }
    final expense = items
        .where((item) => item.kind == LedgerKind.expense)
        .fold<double>(0, (sum, item) => sum + item.cnyAmount.abs());
    final income = items
        .where((item) => item.kind == LedgerKind.income)
        .fold<double>(0, (sum, item) => sum + item.cnyAmount.abs());
    final rows = items
        .map((item) {
          final kind = item.kind == LedgerKind.income ? '收入' : '支出';
          final amount = item.kind == LedgerKind.income
              ? '+¥${_money(item.cnyAmount.abs())}'
              : '-¥${_money(item.cnyAmount.abs())}';
          return '| ${_time(item.date)} | ${item.categoryEmoji} ${_escapeCell(item.categoryName)} | $kind | $amount | ${_escapeCell(item.note.isEmpty ? "无备注" : item.note)} |';
        })
        .join('\n');
    return [
      '## 记账 · ${_date(target)}',
      '',
      '**收支**  收入 ¥${_money(income)}  ·  支出 ¥${_money(expense)}  ·  净额 ¥${_money(income - expense)}',
      '',
      '| 时间 | 分类 | 类型 | 金额 | 备注 |',
      '|---:|---|---|---:|---|',
      rows,
    ].join('\n');
  }

  String _noteSummary(List<QuickNote> notes) {
    final active = notes.where((item) => !item.archived).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final diaries = active
        .where((item) => item.noteType == QuickNoteType.diary)
        .length;
    final docs = active
        .where(
          (item) => item.noteType == QuickNoteType.document && !item.isAnalysis,
        )
        .length;
    final analysis = active.where((item) => item.isAnalysis).length;
    final recentRows = active
        .take(8)
        .map((item) {
          final type = item.isAnalysis
              ? '归纳'
              : item.noteType == QuickNoteType.diary
              ? '日记'
              : '文档';
          final tags = item.tags.isEmpty
              ? '无'
              : item.tags.map((t) => t.name).join('、');
          return '| ${_date(item.updatedAt)} | $type | ${_escapeCell(item.title)} | ${_escapeCell(tags)} |';
        })
        .join('\n');
    return [
      '## 随手记概览',
      '',
      '| 类型 | 数量 |',
      '|---|---:|',
      '| 日记 | $diaries |',
      '| 文档 | $docs |',
      '| 归纳 | $analysis |',
      '',
      '**最近更新**',
      '',
      '| 日期 | 类型 | 标题 | 标签 |',
      '|---|---|---|---|',
      if (recentRows.isEmpty) '| - | - | 暂无 | - |' else recentRows,
    ].join('\n');
  }

  bool _wantsSkillList(String input) {
    final lower = input.toLowerCase();
    return input.contains('技能') || lower.contains('skill');
  }

  DateTime _targetDate(String input) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (input.contains('昨天')) return today.subtract(const Duration(days: 1));
    if (input.contains('明天') || input.contains('明日')) {
      return today.add(const Duration(days: 1));
    }
    if (input.contains('后天')) return today.add(const Duration(days: 2));
    final match = RegExp(
      r'(\d{4})[-年/\.](\d{1,2})[-月/\.](\d{1,2})',
    ).firstMatch(input);
    if (match != null) {
      final year = int.tryParse(match.group(1)!);
      final month = int.tryParse(match.group(2)!);
      final day = int.tryParse(match.group(3)!);
      if (year != null && month != null && day != null) {
        return DateTime(year, month, day);
      }
    }
    return today;
  }

  String _targetTitle(String input) {
    if (input.contains('昨天')) return '昨天';
    if (input.contains('明天') || input.contains('明日')) return '明天';
    if (input.contains('后天')) return '后天';
    return '今天';
  }

  bool _mentionsAny(String input, List<String> words) {
    return words.any(input.contains);
  }

  String _sourceLabel(String source) {
    return switch (source.trim().toLowerCase()) {
      '' => '手动',
      'routine' => '例行',
      'ai' || 'recommend' => 'AI',
      'calendar' => '日历',
      'message' => '消息',
      'manual' => '手动',
      _ => source,
    };
  }

  String _actionLabel(String action) {
    return switch (action.trim().toLowerCase()) {
      '' || 'none' => '无',
      'bookkeeping' => '记账',
      'open_app' => '打开应用',
      final value when value.startsWith('open_app:') => '打开应用',
      'call' => '拨打电话',
      'message' => '发消息',
      _ => action,
    };
  }

  String _date(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _time(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _money(double value) {
    return value.toStringAsFixed(2);
  }

  String _percent(int value, int total) {
    if (total == 0) return '0%';
    return '${(value * 100 / total).round()}%';
  }

  String _escapeCell(String text) {
    return text.replaceAll('|', '\\|').replaceAll('\n', ' ');
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class AppDataSkillResult {
  final AppDataSnapshot snapshot;
  final String promptContext;
  final String fallbackAnswer;
  final String? directAnswer;

  const AppDataSkillResult({
    required this.snapshot,
    required this.promptContext,
    required this.fallbackAnswer,
    this.directAnswer,
  });
}

class AppDataSnapshot {
  final List<Todo> todos;
  final int routineCount;
  final List<String> tagNames;
  final List<String> sourceLabels;
  final List<String> actionLabels;
  final List<LedgerEntry> ledgerEntries;
  final List<QuickNote> notes;

  const AppDataSnapshot({
    required this.todos,
    required this.routineCount,
    required this.tagNames,
    required this.sourceLabels,
    required this.actionLabels,
    required this.ledgerEntries,
    required this.notes,
  });
}

class _TodoLight {
  final String icon;
  final String label;
  final int level;

  const _TodoLight(this.icon, this.label, this.level);
}
