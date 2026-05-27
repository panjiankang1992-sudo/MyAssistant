import 'tag.dart';

class Todo {
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
  });

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
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Todo && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
