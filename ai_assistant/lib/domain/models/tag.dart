import 'package:flutter/material.dart';

class Tag {
  final String id;
  final String name;
  final String colorKey;
  final int sortOrder;
  final bool isPreset;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Tag({
    required this.id,
    required this.name,
    required this.colorKey,
    this.sortOrder = 0,
    this.isPreset = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Tag copyWith({
    String? id,
    String? name,
    String? colorKey,
    int? sortOrder,
    bool? isPreset,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Tag(
      id: id ?? this.id,
      name: name ?? this.name,
      colorKey: colorKey ?? this.colorKey,
      sortOrder: sortOrder ?? this.sortOrder,
      isPreset: isPreset ?? this.isPreset,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'colorKey': colorKey,
      'sortOrder': sortOrder,
      'isPreset': isPreset,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Tag.fromJson(Map<String, dynamic> json) {
    return Tag(
      id: json['id'] as String,
      name: json['name'] as String,
      colorKey: json['colorKey'] as String,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      isPreset: (json['isPreset'] as bool?) ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toCompactJson() {
    return {
      'id': id,
      'name': name,
      'colorKey': colorKey,
    };
  }

  factory Tag.fromCompactJson(Map<String, dynamic> json) {
    return Tag(
      id: json['id'] as String,
      name: json['name'] as String,
      colorKey: json['colorKey'] as String,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Tag && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class TagPalette {
  static final Map<String, ({Color bg, Color text})> colors = {
    'blue': (bg: const Color(0xFFE8F2FD), text: const Color(0xFF4A90D9)),
    'purple': (bg: const Color(0xFFF3E8FF), text: const Color(0xFFAF52DE)),
    'pink': (bg: const Color(0xFFFCE4EC), text: const Color(0xFFE91E63)),
    'green': (bg: const Color(0xFFE8FAF3), text: const Color(0xFF1ABC9C)),
    'orange': (bg: const Color(0xFFFEF3E0), text: const Color(0xFFE67E22)),
    'indigo': (bg: const Color(0xFFF0E6FF), text: const Color(0xFF7C3AED)),
    'lime': (bg: const Color(0xFFEAF5EA), text: const Color(0xFF27AE60)),
    'sky': (bg: const Color(0xFFE3F2FD), text: const Color(0xFF2196F3)),
  };

  static const Color _defaultBg = Color(0xFFF0F0F5);
  static const Color _defaultText = Color(0xFF636366);

  static Color bgColor(String colorKey) {
    return colors[colorKey]?.bg ?? _defaultBg;
  }

  static Color textColor(String colorKey) {
    return colors[colorKey]?.text ?? _defaultText;
  }

  static List<String> get keys => colors.keys.toList();
}
