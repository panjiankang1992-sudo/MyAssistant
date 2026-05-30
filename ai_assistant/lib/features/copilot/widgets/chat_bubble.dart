import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../profile/profile_provider.dart';
import '../copilot_avatar.dart';
import '../copilot_settings.dart';
import '../providers/copilot_provider.dart';

class ChatBubble extends ConsumerWidget {
  final ChatMessage message;

  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUser = message.role == ChatRole.user;
    final settings = ref.watch(copilotSettingsProvider);
    final profile = ref.watch(profileProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final maxWidth = isUser
        ? (screenWidth > 1100 ? 620.0 : screenWidth * 0.72)
        : (screenWidth > 1100 ? 860.0 : screenWidth * 0.86);
    final time = DateFormat('HH:mm').format(message.timestamp);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: isUser
              ? _UserMessage(message: message, time: time, profile: profile)
              : _AgentMessage(message: message, time: time, settings: settings),
        ),
      ),
    );
  }
}

class _AgentMessage extends StatelessWidget {
  final ChatMessage message;
  final String time;
  final CopilotSettings settings;

  const _AgentMessage({
    required this.message,
    required this.time,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    final isError = message.type == ChatMessageType.error;
    final isTool =
        message.type == ChatMessageType.toolCall ||
        message.type == ChatMessageType.result;
    final toneColor = isError
        ? AppColors.danger
        : isTool
        ? AppColors.success
        : AppColors.primary;
    final title = isError
        ? '处理异常'
        : isTool
        ? '执行结果'
        : settings.displayName;
    final scheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AssistantAvatar(
          color: toneColor,
          isError: isError,
          avatar: settings.displayAvatar,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 15),
            decoration: BoxDecoration(
              color: scheme.appSurface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(22),
                bottomLeft: Radius.circular(22),
                bottomRight: Radius.circular(22),
              ),
              border: Border.all(
                color: scheme.appBorder.withValues(alpha: 0.7),
              ),
              boxShadow: scheme.isDarkTheme
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.045),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: toneColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isError
                                ? Icons.error_outline_rounded
                                : isTool
                                ? Icons.task_alt_rounded
                                : Icons.auto_awesome_rounded,
                            size: 13,
                            color: toneColor,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            title,
                            style: TextStyle(
                              fontFamily: 'PingFang SC',
                              fontFamilyFallback: const [
                                '.SF Pro Text',
                                'system-ui',
                                'sans-serif',
                              ],
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: toneColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      time,
                      style: TextStyle(
                        fontFamily: 'PingFang SC',
                        fontFamilyFallback: const [
                          '.SF Pro Text',
                          'system-ui',
                          'sans-serif',
                        ],
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textTertiary.withValues(alpha: 0.9),
                      ),
                    ),
                    const Spacer(),
                    _CopyMessageButton(content: message.content),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(isTool || isError ? 12 : 0),
                  decoration: BoxDecoration(
                    color: isError
                        ? AppColors.danger.withValues(alpha: 0.06)
                        : isTool
                        ? AppColors.success.withValues(alpha: 0.06)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    border: isError
                        ? Border.all(
                            color: AppColors.danger.withValues(alpha: 0.14),
                          )
                        : isTool
                        ? Border.all(
                            color: AppColors.success.withValues(alpha: 0.12),
                          )
                        : null,
                  ),
                  child: MarkdownBody(
                    data: message.content,
                    shrinkWrap: true,
                    selectable: true,
                    styleSheet: _markdownStyle(context, isError: isError),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AssistantAvatar extends StatelessWidget {
  final Color color;
  final bool isError;
  final String avatar;

  const _AssistantAvatar({
    required this.color,
    required this.isError,
    required this.avatar,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: CopilotAvatarView(
        value: avatar,
        size: 38,
        isError: isError,
        margin: const EdgeInsets.only(top: 4),
      ),
    );
  }
}

MarkdownStyleSheet _markdownStyle(
  BuildContext context, {
  required bool isError,
}) {
  const fontFamily = 'PingFang SC';
  const fallback = ['.SF Pro Text', 'system-ui', 'sans-serif'];
  final scheme = Theme.of(context).colorScheme;
  final textColor = isError ? AppColors.danger : scheme.appText;
  final secondaryColor = isError ? AppColors.danger : scheme.appMutedText;

  return MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
    p: TextStyle(
      fontFamily: fontFamily,
      fontFamilyFallback: fallback,
      fontSize: 15,
      height: 1.62,
      fontWeight: FontWeight.w500,
      color: textColor,
    ),
    strong: TextStyle(
      fontFamily: fontFamily,
      fontFamilyFallback: fallback,
      fontSize: 15,
      height: 1.62,
      fontWeight: FontWeight.w900,
      color: textColor,
    ),
    em: TextStyle(
      fontFamily: fontFamily,
      fontFamilyFallback: fallback,
      fontSize: 15,
      height: 1.62,
      fontStyle: FontStyle.italic,
      color: textColor,
    ),
    listBullet: TextStyle(
      fontFamily: fontFamily,
      fontFamilyFallback: fallback,
      fontSize: 15,
      height: 1.62,
      color: textColor,
    ),
    h1: TextStyle(
      fontFamily: fontFamily,
      fontFamilyFallback: fallback,
      fontSize: 19,
      height: 1.35,
      fontWeight: FontWeight.w700,
      color: textColor,
    ),
    h2: TextStyle(
      fontFamily: fontFamily,
      fontFamilyFallback: fallback,
      fontSize: 17,
      height: 1.35,
      fontWeight: FontWeight.w700,
      color: textColor,
    ),
    h3: TextStyle(
      fontFamily: fontFamily,
      fontFamilyFallback: fallback,
      fontSize: 16,
      height: 1.4,
      fontWeight: FontWeight.w700,
      color: textColor,
    ),
    code: TextStyle(
      fontFamily: 'Menlo',
      fontFamilyFallback: const ['SF Mono', 'monospace'],
      fontSize: 12.5,
      height: 1.55,
      color: textColor,
      backgroundColor: Colors.transparent,
    ),
    codeblockPadding: const EdgeInsets.all(14),
    codeblockDecoration: BoxDecoration(
      color: scheme.appInput,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: scheme.appBorder.withValues(alpha: 0.8)),
    ),
    blockquote: TextStyle(
      fontFamily: fontFamily,
      fontFamilyFallback: fallback,
      fontSize: 14,
      height: 1.5,
      color: secondaryColor,
    ),
    blockquotePadding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
    blockquoteDecoration: BoxDecoration(
      color: AppColors.primary.withValues(alpha: 0.055),
      borderRadius: BorderRadius.circular(14),
      border: Border(
        left: BorderSide(
          color: AppColors.primary.withValues(alpha: 0.35),
          width: 3,
        ),
      ),
    ),
    tableHead: TextStyle(
      fontFamily: fontFamily,
      fontFamilyFallback: fallback,
      fontSize: 14,
      fontWeight: FontWeight.w700,
      color: textColor,
    ),
    tableBody: TextStyle(
      fontFamily: fontFamily,
      fontFamilyFallback: fallback,
      fontSize: 14,
      height: 1.45,
      color: textColor,
    ),
    tableBorder: TableBorder.all(
      color: scheme.appBorder.withValues(alpha: 0.8),
    ),
    tableCellsPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    blockSpacing: 12,
    listIndent: 22,
    horizontalRuleDecoration: BoxDecoration(
      border: Border(top: BorderSide(color: scheme.appBorder)),
    ),
  );
}

class _UserMessage extends StatelessWidget {
  final ChatMessage message;
  final String time;
  final UserProfile profile;

  const _UserMessage({
    required this.message,
    required this.time,
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0875E1), Color(0xFF2F88FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(22),
                    topRight: Radius.circular(8),
                    bottomLeft: Radius.circular(22),
                    bottomRight: Radius.circular(6),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.16),
                      blurRadius: 18,
                      offset: const Offset(0, 9),
                    ),
                  ],
                ),
                child: SelectableText(
                  message.content,
                  style: const TextStyle(
                    fontFamily: 'PingFang SC',
                    fontFamilyFallback: [
                      '.SF Pro Text',
                      'system-ui',
                      'sans-serif',
                    ],
                    fontSize: 15,
                    height: 1.45,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    time,
                    style: const TextStyle(
                      fontFamily: 'PingFang SC',
                      fontFamilyFallback: [
                        '.SF Pro Text',
                        'system-ui',
                        'sans-serif',
                      ],
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  _CopyMessageButton(content: message.content),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        _UserAvatar(profile: profile),
      ],
    );
  }
}

class _UserAvatar extends StatelessWidget {
  final UserProfile profile;

  const _UserAvatar({required this.profile});

  @override
  Widget build(BuildContext context) {
    final fallback = _gradientAvatar(profile.avatarLetter);
    final saved = profile.avatarValue?.trim() ?? '';
    if (saved.isNotEmpty) return CopilotAvatarView(value: saved, size: 36);
    if (profile.hasServerAvatar) {
      final url = profile.serverAvatarUrl!;
      if (url.startsWith('data:')) {
        try {
          final bytes = base64Decode(url.split(',').last);
          return ClipOval(
            child: Image.memory(
              bytes,
              width: 36,
              height: 36,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback,
            ),
          );
        } catch (_) {
          return fallback;
        }
      }
      return ClipOval(
        child: Image.network(
          url,
          width: 36,
          height: 36,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => fallback,
        ),
      );
    }
    if (profile.hasCustomAvatar) {
      return CopilotAvatarView(
        value: CopilotAvatarCatalog.fileValue(profile.avatarPath!),
        size: 36,
      );
    }
    return const CopilotAvatarView(
      value: CopilotAvatarCatalog.defaultValue,
      size: 36,
    );
  }

  Widget _gradientAvatar(String text) {
    return Container(
      width: 36,
      height: 36,
      margin: const EdgeInsets.only(top: 2),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFFFF9500), Color(0xFFFF5E3A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          text.isEmpty ? '?' : text,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _CopyMessageButton extends StatelessWidget {
  final String content;

  const _CopyMessageButton({required this.content});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '复制消息',
      child: InkResponse(
        radius: 14,
        onTap: () async {
          await Clipboard.setData(ClipboardData(text: content));
          if (!context.mounted) return;
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: Text('已复制'),
                duration: Duration(milliseconds: 900),
              ),
            );
        },
        child: const Padding(
          padding: EdgeInsets.all(3),
          child: Icon(
            Icons.copy_rounded,
            size: 12,
            color: AppColors.textTertiary,
          ),
        ),
      ),
    );
  }
}
