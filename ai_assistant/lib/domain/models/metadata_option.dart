class MetadataOption {
  final String id;
  final String kind;
  final String value;
  final String label;
  final String iconKey;
  final String colorKey;
  final int sortOrder;
  final bool isPreset;
  final DateTime updatedAt;

  const MetadataOption({
    required this.id,
    required this.kind,
    required this.value,
    required this.label,
    required this.iconKey,
    required this.colorKey,
    this.sortOrder = 0,
    this.isPreset = true,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    'value': value,
    'label': label,
    'iconKey': iconKey,
    'colorKey': colorKey,
    'sortOrder': sortOrder,
    'isPreset': isPreset,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory MetadataOption.fromJson(Map<String, dynamic> json) {
    return MetadataOption(
      id: json['id'] as String,
      kind: json['kind'] as String,
      value: json['value'] as String,
      label: json['label'] as String,
      iconKey: json['iconKey'] as String,
      colorKey: json['colorKey'] as String,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      isPreset: json['isPreset'] as bool? ?? true,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
  }
}
