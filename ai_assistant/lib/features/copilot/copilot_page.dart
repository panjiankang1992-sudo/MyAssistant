import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../ai_settings/ai_model_provider.dart';
import 'copilot_avatar.dart';
import 'copilot_settings.dart';
import 'providers/copilot_provider.dart';
import 'widgets/chat_bubble.dart';
import 'widgets/copilot_hero.dart';
import 'widgets/copilot_input.dart';
import 'widgets/prompt_cards.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/profile_avatar_button.dart';

class CopilotPage extends ConsumerWidget {
  final VoidCallback? onAvatarTap;

  const CopilotPage({super.key, this.onAvatarTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copilotState = ref.watch(copilotNotifierProvider);
    final modelState = ref.watch(aiModelProvider);
    final scheme = Theme.of(context).colorScheme;

    void sendMessage(String text) {
      ref.read(copilotNotifierProvider.notifier).sendMessage(text);
    }

    return Scaffold(
      backgroundColor: scheme.appPage,
      drawer: const _HistoryDrawer(),
      body: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                _CopilotTopBar(onAvatarTap: onAvatarTap),
                Expanded(
                  child: copilotState.messages.isEmpty
                      ? SingleChildScrollView(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Column(
                            children: [
                              const CopilotHero(),
                              PromptCards(onTap: sendMessage),
                              const SizedBox(height: 14),
                              BuiltinSkillCards(onTap: sendMessage),
                            ],
                          ),
                        )
                      : _ChatList(
                          messages: copilotState.messages,
                          isRunning: copilotState.isRunning,
                        ),
                ),
                CopilotInput(
                  onSend: sendMessage,
                  selectedModel: modelState.selected,
                  isRunning: copilotState.isRunning,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryDrawer extends ConsumerWidget {
  const _HistoryDrawer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(copilotNotifierProvider);
    final sessions = state.sessions;
    final scheme = Theme.of(context).colorScheme;

    return Drawer(
      backgroundColor: scheme.appSurface,
      width: 308,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '历史会话',
                      style: TextStyle(
                        fontFamily: 'PingFang SC',
                        fontFamilyFallback: const [
                          '.SF Pro Text',
                          'system-ui',
                          'sans-serif',
                        ],
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: scheme.appText,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '新会话',
                    onPressed: () {
                      ref.read(copilotNotifierProvider.notifier).newSession();
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: sessions.isEmpty
                    ? Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: scheme.appInput,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: scheme.appBorder),
                        ),
                        child: Text(
                          '暂无历史会话',
                          style: TextStyle(color: scheme.appMutedText),
                        ),
                      )
                    : ListView.separated(
                        itemCount: sessions.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final session = sessions[index];
                          final selected = session.id == state.currentSessionId;
                          return InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () {
                              ref
                                  .read(copilotNotifierProvider.notifier)
                                  .selectSession(session.id);
                              Navigator.of(context).pop();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 11,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? scheme.primary.withValues(alpha: 0.08)
                                    : scheme.appInput,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: selected
                                      ? AppColors.primary.withValues(
                                          alpha: 0.22,
                                        )
                                      : scheme.appBorder,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    selected
                                        ? Icons.chat_bubble_rounded
                                        : Icons.chat_bubble_outline_rounded,
                                    size: 18,
                                    color: selected
                                        ? scheme.primary
                                        : scheme.appMutedText,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          session.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                          ).copyWith(color: scheme.appText),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${session.messages.length} 条消息 · ${DateFormat('MM-dd HH:mm').format(session.updatedAt)}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: scheme.appMutedText,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: '删除',
                                    onPressed: () => ref
                                        .read(copilotNotifierProvider.notifier)
                                        .deleteSession(session.id),
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      size: 18,
                                      color: AppColors.textTertiary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CopilotTopBar extends ConsumerWidget {
  final VoidCallback? onAvatarTap;

  const _CopilotTopBar({this.onAvatarTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: BoxDecoration(
        color: scheme.appPage,
        border: Border(bottom: BorderSide(color: scheme.appBorder, width: 0.5)),
      ),
      child: Row(
        children: [
          Builder(
            builder: (context) {
              return IconButton(
                tooltip: '历史会话',
                onPressed: () => Scaffold.of(context).openDrawer(),
                icon: Icon(Icons.menu_rounded, size: 24, color: scheme.appText),
              );
            },
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.success.withValues(alpha: 0.14),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.storage_rounded,
                  size: 13,
                  color: AppColors.success,
                ),
                const SizedBox(width: 5),
                Text(
                  '应用数据已接入',
                  style: TextStyle(
                    fontFamily: 'PingFang SC',
                    fontFamilyFallback: [
                      '.SF Pro Text',
                      'system-ui',
                      'sans-serif',
                    ],
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: scheme.appMutedText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ProfileAvatarButton(onTap: onAvatarTap),
        ],
      ),
    );
  }
}

class _ChatList extends StatefulWidget {
  final List<ChatMessage> messages;
  final bool isRunning;

  const _ChatList({required this.messages, required this.isRunning});

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
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            scheme.appPage,
            scheme.primary.withValues(alpha: scheme.isDarkTheme ? 0.06 : 0.025),
          ],
        ),
      ),
      child: ListView.builder(
        controller: _controller,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
        itemCount: widget.messages.length + (widget.isRunning ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == widget.messages.length) {
            return const _TypingIndicator();
          }
          final message = widget.messages[index];
          return ChatBubble(message: message);
        },
      ),
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
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Consumer(
            builder: (context, ref, _) {
              final settings = ref.watch(copilotSettingsProvider);
              return CopilotAvatarView(value: settings.displayAvatar, size: 32);
            },
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: scheme.appSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: scheme.appBorder),
            ),
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
                        color: AppColors.primary.withValues(
                          alpha: 0.25 + 0.55 * (scale.clamp(0, 1)),
                        ),
                        shape: BoxShape.circle,
                      ),
                    );
                  },
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
