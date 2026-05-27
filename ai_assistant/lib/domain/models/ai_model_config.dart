class AiModelConfig {
  final String id;
  final String name;
  final String provider;
  final String baseUrl;
  final String model;
  final String apiKey;
  final bool enabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AiModelConfig({
    required this.id,
    required this.name,
    required this.provider,
    required this.baseUrl,
    required this.model,
    required this.apiKey,
    this.enabled = true,
    required this.createdAt,
    required this.updatedAt,
  });

  AiModelConfig copyWith({
    String? id,
    String? name,
    String? provider,
    String? baseUrl,
    String? model,
    String? apiKey,
    bool? enabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AiModelConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      provider: provider ?? this.provider,
      baseUrl: baseUrl ?? this.baseUrl,
      model: model ?? this.model,
      apiKey: apiKey ?? this.apiKey,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'provider': provider,
    'baseUrl': baseUrl,
    'model': model,
    'apiKey': apiKey,
    'enabled': enabled,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  static AiModelConfig fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return AiModelConfig(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      provider: json['provider'] as String? ?? 'custom',
      baseUrl: json['baseUrl'] as String? ?? '',
      model: json['model'] as String? ?? '',
      apiKey: json['apiKey'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : now,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : now,
    );
  }
}

class AiProviderPreset {
  final String provider;
  final String label;
  final String baseUrl;
  final String model;

  const AiProviderPreset({
    required this.provider,
    required this.label,
    required this.baseUrl,
    required this.model,
  });
}

class AiProviderPresets {
  static const options = [
    AiProviderPreset(
      provider: 'deepseek',
      label: 'DeepSeek',
      baseUrl: 'https://api.deepseek.com',
      model: 'deepseek-v4-flash',
    ),
    AiProviderPreset(
      provider: 'minimax',
      label: 'MiniMax',
      baseUrl: 'https://api.minimax.chat/v1',
      model: 'MiniMax-M1',
    ),
    AiProviderPreset(
      provider: 'openai',
      label: 'OpenAI',
      baseUrl: 'https://api.openai.com/v1',
      model: 'gpt-4o-mini',
    ),
    AiProviderPreset(
      provider: 'qwen',
      label: '通义千问',
      baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
      model: 'qwen-turbo',
    ),
    AiProviderPreset(
      provider: 'custom',
      label: '自定义 OpenAI',
      baseUrl: '',
      model: '',
    ),
  ];

  static AiProviderPreset byProvider(String provider) {
    return options.firstWhere(
      (item) => item.provider == provider,
      orElse: () => options.last,
    );
  }
}
