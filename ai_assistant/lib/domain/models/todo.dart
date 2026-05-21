class Todo {
  final String id;
  final String title;
  final String? description;
  final String source;
  final String type;
  final String time;
  final DateTime date;
  final bool completed;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;
  final bool deleted;

  const Todo({
    required this.id,
    required this.title,
    this.description,
    required this.source,
    required this.type,
    required this.time,
    required this.date,
    this.completed = false,
    required this.createdAt,
    required this.updatedAt,
    this.version = 1,
    this.deleted = false,
  });

  Todo copyWith({
    String? id,
    String? title,
    String? description,
    String? source,
    String? type,
    String? time,
    DateTime? date,
    bool? completed,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? version,
    bool? deleted,
  }) {
    return Todo(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      source: source ?? this.source,
      type: type ?? this.type,
      time: time ?? this.time,
      date: date ?? this.date,
      completed: completed ?? this.completed,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
      deleted: deleted ?? this.deleted,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Todo && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
