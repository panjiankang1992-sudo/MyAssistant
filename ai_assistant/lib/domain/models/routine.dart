import 'tag.dart';

class Routine {
  final int id;
  final String? uuid;
  final String title;
  final String? description;
  final String type;
  final List<Tag> tags;
  final String action;
  final String time;
  final String repeatRule;
  final String? repeatDays;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;
  final bool deleted;

  const Routine({
    required this.id,
    this.uuid,
    required this.title,
    this.description,
    required this.type,
    this.tags = const [],
    this.action = 'none',
    required this.time,
    this.repeatRule = 'daily',
    this.repeatDays,
    required this.createdAt,
    DateTime? updatedAt,
    this.version = 1,
    this.deleted = false,
  }) : updatedAt = updatedAt ?? createdAt;

  Routine copyWith({
    int? id,
    String? uuid,
    String? title,
    String? description,
    String? type,
    List<Tag>? tags,
    String? action,
    String? time,
    String? repeatRule,
    String? repeatDays,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? version,
    bool? deleted,
  }) {
    return Routine(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      tags: tags ?? this.tags,
      action: action ?? this.action,
      time: time ?? this.time,
      repeatRule: repeatRule ?? this.repeatRule,
      repeatDays: repeatDays ?? this.repeatDays,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
      deleted: deleted ?? this.deleted,
    );
  }

  /// Whether this routine should generate a todo on the given [date].
  bool shouldGenerateOn(DateTime date) {
    switch (repeatRule) {
      case 'daily':
        return true;
      case 'weekdays':
        return date.weekday >= 1 && date.weekday <= 5;
      case 'weekly':
        if (repeatDays == null) return true;
        final days = repeatDays!.split(',').map(int.parse).toList();
        return days.contains(date.weekday);
      case 'monthly':
        if (repeatDays == null) return true;
        final days = repeatDays!.split(',').map(int.parse).toList();
        return days.contains(date.day);
      case 'custom':
        return true;
      default:
        return true;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Routine && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
