import 'tag.dart';

class Todo {
  static const int normalReminderMinutes = 10;
  static const int elevatedReminderMinutes = 24 * 60;

  final String id;
  final String title;
  final String? description;
  final String source;
  final String? routineId;
  final String type;
  final List<Tag> tags;
  final String action;
  final String time;
  final DateTime date;
  final bool completed;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;
  final bool deleted;
  final int priority;
  final bool reminderEnabled;
  final int reminderMinutesBefore;

  const Todo({
    required this.id,
    required this.title,
    this.description,
    required this.source,
    this.routineId,
    required this.type,
    this.tags = const [],
    this.action = 'none',
    required this.time,
    required this.date,
    this.completed = false,
    required this.createdAt,
    required this.updatedAt,
    this.version = 1,
    this.deleted = false,
    this.priority = 0,
    this.reminderEnabled = true,
    int? reminderMinutesBefore,
  }) : reminderMinutesBefore =
           reminderMinutesBefore ??
           (priority >= 1 ? elevatedReminderMinutes : normalReminderMinutes);

  static int defaultReminderMinutesForPriority(int priority) {
    return priority >= 1 ? elevatedReminderMinutes : normalReminderMinutes;
  }

  static String formatReminderMinutes(int minutes) {
    if (minutes >= 24 * 60 && minutes % (24 * 60) == 0) {
      final days = minutes ~/ (24 * 60);
      return days == 1 ? '提前一天' : '提前$days天';
    }
    if (minutes >= 60 && minutes % 60 == 0) {
      final hours = minutes ~/ 60;
      return hours == 1 ? '提前1小时' : '提前$hours小时';
    }
    return '提前$minutes分钟';
  }

  Todo copyWith({
    String? id,
    String? title,
    String? description,
    String? source,
    String? routineId,
    String? type,
    List<Tag>? tags,
    String? action,
    String? time,
    DateTime? date,
    bool? completed,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? version,
    bool? deleted,
    int? priority,
    bool? reminderEnabled,
    int? reminderMinutesBefore,
  }) {
    return Todo(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      source: source ?? this.source,
      routineId: routineId ?? this.routineId,
      type: type ?? this.type,
      tags: tags ?? this.tags,
      action: action ?? this.action,
      time: time ?? this.time,
      date: date ?? this.date,
      completed: completed ?? this.completed,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
      deleted: deleted ?? this.deleted,
      priority: priority ?? this.priority,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderMinutesBefore:
          reminderMinutesBefore ?? this.reminderMinutesBefore,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Todo && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
