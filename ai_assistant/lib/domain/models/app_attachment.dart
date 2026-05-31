class AppAttachment {
  static const maxSizeBytes = 50 * 1024 * 1024;
  static const maxSizeLabel = '50MB';

  final String id;
  final String ownerType;
  final String ownerId;
  final String attachmentType;
  final String fileName;
  final String? mimeType;
  final int sizeBytes;
  final String contentBase64;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  const AppAttachment({
    required this.id,
    required this.ownerType,
    required this.ownerId,
    required this.attachmentType,
    required this.fileName,
    this.mimeType,
    required this.sizeBytes,
    required this.contentBase64,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
  });

  bool get exceedsMaxSize => sizeBytes > maxSizeBytes;

  Map<String, dynamic> toJson() => {
    'id': id,
    'ownerType': ownerType,
    'ownerId': ownerId,
    'attachmentType': attachmentType,
    'fileName': fileName,
    'mimeType': mimeType,
    'sizeBytes': sizeBytes,
    'contentBase64': contentBase64,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'isDeleted': isDeleted,
  };

  factory AppAttachment.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return AppAttachment(
      id: json['id'] as String? ?? '',
      ownerType: json['ownerType'] as String? ?? 'unknown',
      ownerId: json['ownerId'] as String? ?? '',
      attachmentType: json['attachmentType'] as String? ?? 'file',
      fileName: json['fileName'] as String? ?? 'attachment',
      mimeType: json['mimeType'] as String?,
      sizeBytes: json['sizeBytes'] as int? ?? 0,
      contentBase64: json['contentBase64'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? now,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? now,
      isDeleted:
          json['isDeleted'] as bool? ?? json['deleted'] as bool? ?? false,
    );
  }
}
