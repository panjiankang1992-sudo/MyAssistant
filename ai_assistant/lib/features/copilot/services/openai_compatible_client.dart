import 'dart:convert';
import 'dart:io';
import '../../../domain/models/ai_model_config.dart';

class LlmChatMessage {
  final String role;
  final String content;

  const LlmChatMessage({required this.role, required this.content});

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

class OpenAiCompatibleClient {
  Future<String> chat({
    required AiModelConfig config,
    required List<LlmChatMessage> messages,
  }) async {
    final baseUrl = _normalizedBaseUrl(config);
    final uri = Uri.parse('$baseUrl/chat/completions');
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 12);
    try {
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer ${config.apiKey}',
      );
      request.add(
        utf8.encode(
          jsonEncode({
            'model': config.model,
            'messages': messages.map((item) => item.toJson()).toList(),
            'temperature': 0.3,
            'stream': false,
          }),
        ),
      );
      final response = await request.close();
      final body = await utf8.decodeStream(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('模型请求失败(${response.statusCode}): $body');
      }
      final json = jsonDecode(body) as Map<String, dynamic>;
      final choices = json['choices'] as List<dynamic>? ?? const [];
      if (choices.isEmpty) return '';
      final message = choices.first['message'] as Map<String, dynamic>? ?? {};
      return (message['content'] as String? ?? '').trim();
    } on SocketException catch (e) {
      throw Exception('无法连接模型服务：${e.message}。请检查网络/DNS，或确认 Base URL 是否正确。');
    } finally {
      client.close(force: true);
    }
  }

  String _normalizedBaseUrl(AiModelConfig config) {
    final baseUrl = config.baseUrl.replaceAll(RegExp(r'/+$'), '');
    if (config.provider == 'deepseek' && baseUrl.endsWith('/v1')) {
      return baseUrl.substring(0, baseUrl.length - 3);
    }
    return baseUrl;
  }
}
