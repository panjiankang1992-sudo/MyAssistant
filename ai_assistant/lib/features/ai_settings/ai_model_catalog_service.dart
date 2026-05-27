import 'dart:convert';
import 'dart:io';

class AiModelCatalogService {
  Future<List<String>> fetchModels({
    required String provider,
    required String baseUrl,
    required String apiKey,
  }) async {
    final uri = _modelsUri(provider: provider, baseUrl: baseUrl);
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, ContentType.json.mimeType);
      if (apiKey.trim().isNotEmpty) {
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer ${apiKey.trim()}',
        );
      }
      final response = await request.close();
      final body = await utf8.decodeStream(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('模型列表拉取失败(${response.statusCode}): $body');
      }
      final json = jsonDecode(body) as Map<String, dynamic>;
      final data = json['data'] as List<dynamic>? ?? const [];
      final models = data
          .whereType<Map<String, dynamic>>()
          .map((item) => item['id'] as String?)
          .whereType<String>()
          .where((id) => id.trim().isNotEmpty)
          .toList();
      models.sort();
      return models;
    } on SocketException catch (e) {
      throw Exception('无法连接模型服务：${e.message}。请检查网络/DNS，或确认 Base URL 是否正确。');
    } finally {
      client.close(force: true);
    }
  }

  Uri _modelsUri({required String provider, required String baseUrl}) {
    final normalized = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (provider == 'deepseek') {
      return Uri.parse('https://api.deepseek.com/models');
    }
    return Uri.parse('$normalized/models');
  }

  List<String> fallbackModels(String provider) {
    return switch (provider) {
      'deepseek' => const ['deepseek-v4-flash', 'deepseek-v4-pro'],
      'openai' => const ['gpt-4o-mini', 'gpt-4o'],
      'qwen' => const ['qwen-turbo', 'qwen-plus', 'qwen-max'],
      'minimax' => const ['MiniMax-M1'],
      _ => const [],
    };
  }
}
