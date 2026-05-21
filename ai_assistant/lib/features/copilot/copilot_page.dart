import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/copilot_provider.dart';
import 'widgets/chat_bubble.dart';
import 'widgets/copilot_hero.dart';
import 'widgets/copilot_input.dart';
import 'widgets/prompt_cards.dart';
import '../../core/theme/app_theme.dart';

class CopilotPage extends ConsumerWidget {
  final VoidCallback? onAvatarTap;

  const CopilotPage({super.key, this.onAvatarTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = ref.watch(copilotNotifierProvider);

    void sendMessage(String text) {
      ref.read(copilotNotifierProvider.notifier).sendMessage(text);
    }

    return Column(
      children: [
        Expanded(
          child: messages.isEmpty
              ? SingleChildScrollView(
                  child: Column(
                    children: [
                      const CopilotHero(),
                      PromptCards(onTap: sendMessage),
                    ],
                  ),
                )
              : _ChatList(messages: messages),
        ),
        CopilotInput(onSend: sendMessage),
      ],
    );
  }
}

class _ChatList extends StatefulWidget {
  final List<ChatMessage> messages;

  const _ChatList({required this.messages});

  @override
  State<_ChatList> createState() => _ChatListState();
}

class _ChatListState extends State<_ChatList> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _ChatList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messages.length > oldWidget.messages.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_controller.hasClients) {
          _controller.animateTo(
            _controller.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _controller,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: widget.messages.length,
      itemBuilder: (context, index) {
        final message = widget.messages[index];
        final isLastAssistant = index == widget.messages.length - 1 &&
            message.role == ChatRole.assistant;
        if (isLastAssistant) {
          return Column(
            children: [
              ChatBubble(message: message),
              const _TypingIndicator(),
            ],
          );
        }
        return ChatBubble(message: message);
      },
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (index) {
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final progress = (_controller.value * 3 - index) % 3;
              final scale = progress < 1 ? progress : 2 - progress;
              return Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: AppColors.textTertiary.withOpacity(0.3 + 0.7 * (scale.clamp(0, 1))),
                  shape: BoxShape.circle,
                ),
              );
            },
          );
        }),
      ),
    );
  }
}