import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

enum ChatRole { user, assistant }

enum ChatMessageType { thinking, toolCall, result, error, text }

class ChatMessage {
  final String id;
  final ChatRole role;
  final String content;
  final ChatMessageType type;
  final DateTime timestamp;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.type,
    required this.timestamp,
  });
}

class CopilotNotifier extends Notifier<List<ChatMessage>> {
  @override
  List<ChatMessage> build() => [];

  Future<void> sendMessage(String text) async {
    final userMessage = ChatMessage(
      id: const Uuid().v4(),
      role: ChatRole.user,
      content: text,
      type: ChatMessageType.text,
      timestamp: DateTime.now(),
    );
    state = [...state, userMessage];
    await Future.delayed(const Duration(milliseconds: 1500));
    final assistantMessage = ChatMessage(
      id: const Uuid().v4(),
      role: ChatRole.assistant,
      content: '这是一个模拟回复。完整的 AI 对话功能将在后续版本中实现。',
      type: ChatMessageType.text,
      timestamp: DateTime.now(),
    );
    state = [...state, assistantMessage];
  }
}

final copilotNotifierProvider = NotifierProvider<CopilotNotifier, List<ChatMessage>>(CopilotNotifier.new);
