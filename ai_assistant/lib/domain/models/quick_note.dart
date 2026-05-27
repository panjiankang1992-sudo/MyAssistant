import 'tag.dart';

enum QuickNoteType {
  diary('diary'),
  document('document');

  final String value;
  const QuickNoteType(this.value);

  static QuickNoteType fromJson(String? value, String title) {
    if (value == diary.value) return diary;
    if (value == document.value) return document;
    return looksLikeDiaryTitle(title) ? diary : document;
  }
}

bool looksLikeDiaryTitle(String title) {
  final text = title.trim();
  return RegExp(r'^\d{4}[-_\.年]\d{1,2}[-_\.月]\d{1,2}(日)?$').hasMatch(text) ||
      RegExp(r'^\d{8}$').hasMatch(text);
}

class QuickNote {
  final String id;
  final String title;
  final String content;
  final String summary;
  final List<Tag> tags;
  final DateTime date;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool archived;
  final bool deleted;
  final bool pinned;
  final bool analyzed;
  final bool isAnalysis;
  final QuickNoteType noteType;
  final String category;
  final String subcategory;
  final List<String> sourceNoteIds;

  const QuickNote({
    required this.id,
    required this.title,
    required this.content,
    this.summary = '',
    this.tags = const [],
    required this.date,
    required this.createdAt,
    required this.updatedAt,
    this.archived = false,
    this.deleted = false,
    this.pinned = false,
    this.analyzed = false,
    this.isAnalysis = false,
    this.noteType = QuickNoteType.document,
    this.category = '未分类',
    this.subcategory = '未归类',
    this.sourceNoteIds = const [],
  });

  QuickNote copyWith({
    String? id,
    String? title,
    String? content,
    String? summary,
    List<Tag>? tags,
    DateTime? date,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? archived,
    bool? deleted,
    bool? pinned,
    bool? analyzed,
    bool? isAnalysis,
    QuickNoteType? noteType,
    String? category,
    String? subcategory,
    List<String>? sourceNoteIds,
  }) {
    return QuickNote(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      summary: summary ?? this.summary,
      tags: tags ?? this.tags,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      archived: archived ?? this.archived,
      deleted: deleted ?? this.deleted,
      pinned: pinned ?? this.pinned,
      analyzed: analyzed ?? this.analyzed,
      isAnalysis: isAnalysis ?? this.isAnalysis,
      noteType: noteType ?? this.noteType,
      category: category ?? this.category,
      subcategory: subcategory ?? this.subcategory,
      sourceNoteIds: sourceNoteIds ?? this.sourceNoteIds,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'summary': summary,
    'tags': tags
        .map(
          (t) => {
            'id': t.id,
            'name': t.name,
            'colorKey': t.colorKey,
            'sortOrder': t.sortOrder,
            'isPreset': t.isPreset,
            'createdAt': t.createdAt.toIso8601String(),
            'updatedAt': t.updatedAt.toIso8601String(),
          },
        )
        .toList(),
    'date': date.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'archived': archived,
    'deleted': deleted,
    'pinned': pinned,
    'analyzed': analyzed,
    'isAnalysis': isAnalysis,
    'noteType': noteType.value,
    'category': category,
    'subcategory': subcategory,
    'sourceNoteIds': sourceNoteIds,
  };

  factory QuickNote.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return QuickNote(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      tags: (json['tags'] as List? ?? const [])
          .whereType<Map>()
          .map((raw) {
            final map = raw.cast<String, dynamic>();
            return Tag(
              id: map['id'] as String? ?? 'temp-${map['name'] ?? ''}',
              name: map['name'] as String? ?? '',
              colorKey: map['colorKey'] as String? ?? 'blue',
              sortOrder: map['sortOrder'] as int? ?? 0,
              isPreset: map['isPreset'] as bool? ?? false,
              createdAt:
                  DateTime.tryParse(map['createdAt'] as String? ?? '') ?? now,
              updatedAt:
                  DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? now,
            );
          })
          .where((t) => t.name.isNotEmpty)
          .toList(),
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? now,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? now,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? now,
      archived: json['archived'] as bool? ?? false,
      deleted: json['deleted'] as bool? ?? false,
      pinned: json['pinned'] as bool? ?? false,
      analyzed: json['analyzed'] as bool? ?? true,
      isAnalysis: json['isAnalysis'] as bool? ?? false,
      noteType: QuickNoteType.fromJson(
        json['noteType'] as String?,
        json['title'] as String? ?? '',
      ),
      category: json['category'] as String? ?? '未分类',
      subcategory: json['subcategory'] as String? ?? '未归类',
      sourceNoteIds: (json['sourceNoteIds'] as List? ?? const [])
          .whereType<String>()
          .toList(),
    );
  }
}
