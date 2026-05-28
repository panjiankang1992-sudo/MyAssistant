import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../data/datasources/local_datasource.dart';
import '../../data/repositories/todo_repository.dart';
import '../../domain/models/todo.dart';

class CalendarTodoService {
  static const _channel = MethodChannel('my_assistant/calendar');

  final LocalDatasource datasource;
  final TodoRepository todoRepository;

  const CalendarTodoService({
    required this.datasource,
    required this.todoRepository,
  });

  Future<CalendarImportResult> importUpcoming({
    int days = 30,
    DateTime? now,
  }) async {
    final base = now ?? DateTime.now();
    final start = DateTime(base.year, base.month, base.day);
    final end = start.add(Duration(days: days));
    final events = await _fetchEvents(start: start, end: end);
    if (events.isEmpty) {
      return const CalendarImportResult(
        created: 0,
        skipped: 0,
        unsupported: false,
      );
    }

    final existing = await datasource.getAllTodos();
    var created = 0;
    var skipped = 0;
    for (final event in events) {
      if (event.title.trim().isEmpty) {
        skipped++;
        continue;
      }
      if (_alreadyExists(existing, event)) {
        skipped++;
        continue;
      }
      final todo = Todo(
        id: const Uuid().v4(),
        title: event.title.trim(),
        description: _descriptionOf(event),
        source: 'calendar',
        routineId: event.id,
        type: 'calendar',
        action: 'none',
        time: event.allDay ? '09:00' : _timeOf(event.start),
        date: DateTime(event.start.year, event.start.month, event.start.day),
        createdAt: base,
        updatedAt: base,
        priority: 0,
      );
      await todoRepository.addTodo(todo);
      existing.add(todo);
      created++;
    }
    return CalendarImportResult(
      created: created,
      skipped: skipped,
      unsupported: false,
    );
  }

  Future<bool> openCalendarApp() async {
    try {
      final opened = await _channel.invokeMethod<bool>('openCalendar');
      return opened ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<List<CalendarEvent>> _fetchEvents({
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>('fetchEvents', {
        'startMillis': start.millisecondsSinceEpoch,
        'endMillis': end.millisecondsSinceEpoch,
      });
      return (raw ?? const [])
          .whereType<Map>()
          .map((item) => CalendarEvent.fromMap(item.cast<String, Object?>()))
          .where(
            (event) => event.end.isAfter(start) && event.start.isBefore(end),
          )
          .toList();
    } on MissingPluginException {
      return const [];
    } on PlatformException {
      return const [];
    }
  }

  bool _alreadyExists(List<Todo> todos, CalendarEvent event) {
    return todos.any((todo) {
      if (todo.deleted || todo.source != 'calendar') return false;
      final sameEvent = todo.routineId == event.id;
      final sameDay =
          todo.date.year == event.start.year &&
          todo.date.month == event.start.month &&
          todo.date.day == event.start.day;
      final sameTitle = todo.title.trim() == event.title.trim();
      return sameDay && (sameEvent || sameTitle);
    });
  }

  String _descriptionOf(CalendarEvent event) {
    final parts = [
      if (event.location.trim().isNotEmpty) '地点：${event.location.trim()}',
      if (event.notes.trim().isNotEmpty) event.notes.trim(),
      '来源：${event.platformLabel} 日历',
    ];
    return parts.join('\n');
  }

  String _timeOf(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class CalendarImportResult {
  final int created;
  final int skipped;
  final bool unsupported;

  const CalendarImportResult({
    required this.created,
    required this.skipped,
    required this.unsupported,
  });
}

class CalendarEvent {
  final String id;
  final String title;
  final String notes;
  final String location;
  final DateTime start;
  final DateTime end;
  final bool allDay;
  final String platform;

  const CalendarEvent({
    required this.id,
    required this.title,
    required this.notes,
    required this.location,
    required this.start,
    required this.end,
    required this.allDay,
    required this.platform,
  });

  String get platformLabel {
    return switch (platform) {
      'macos' => 'Mac',
      'android' => '安卓',
      'ohos' => '鸿蒙',
      _ => '系统',
    };
  }

  factory CalendarEvent.fromMap(Map<String, Object?> map) {
    final startMillis = (map['startMillis'] as num?)?.toInt() ?? 0;
    final endMillis = (map['endMillis'] as num?)?.toInt() ?? startMillis;
    return CalendarEvent(
      id: map['id'] as String? ?? const Uuid().v4(),
      title: map['title'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      location: map['location'] as String? ?? '',
      start: DateTime.fromMillisecondsSinceEpoch(startMillis),
      end: DateTime.fromMillisecondsSinceEpoch(endMillis),
      allDay: map['allDay'] as bool? ?? false,
      platform: map['platform'] as String? ?? 'unknown',
    );
  }
}
