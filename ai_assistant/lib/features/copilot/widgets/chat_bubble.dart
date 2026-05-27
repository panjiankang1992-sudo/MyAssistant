import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/copilot_provider.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;
    final screenWidth = MediaQuery.of(context).size.width;
    final maxWidth = screenWidth > 1100 ? 820.0 : screenWidth * 0.78;
    final time = DateFormat('HH:mm').format(message.timestamp);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: isUser
              ? _UserMessage(message: message, time: time)
              : _AgentMessage(message: message, time: time),
        ),
      ),
    );
  }
}

class _AgentMessage extends StatelessWidget {
  final ChatMessage message;
  final String time;

  const _AgentMessage({required this.message, required this.time});

  @override
  Widget build(BuildContext context) {
    final isError = message.type == ChatMessageType.error;
    final isTool =
        message.type == ChatMessageType.toolCall ||
        message.type == ChatMessageType.result;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            color: isError
                ? AppColors.danger.withValues(alpha: 0.08)
                : AppColors.primary.withValues(alpha: 0.09),
            shape: BoxShape.circle,
            border: Border.all(
              color: isError
                  ? AppColors.danger.withValues(alpha: 0.16)
                  : AppColors.primary.withValues(alpha: 0.14),
            ),
          ),
          child: Icon(
            isError ? Icons.error_outline_rounded : Icons.auto_awesome_rounded,
            size: 16,
            color: isError ? AppColors.danger : AppColors.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'MyAssistant',
                    style: TextStyle(
                      fontFamily: 'PingFang SC',
                      fontFamilyFallback: [
                        '.SF Pro Text',
                        'system-ui',
                        'sans-serif',
                      ],
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
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
              const SizedBox(height: 6),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isTool || isError ? 12 : 0,
                  vertical: isTool || isError ? 10 : 0,
                ),
                decoration: BoxDecoration(
                  color: isError
                      ? AppColors.danger.withValues(alpha: 0.06)
                      : isTool
                      ? AppColors.inputBg
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: isError
                      ? Border.all(
                          color: AppColors.danger.withValues(alpha: 0.14),
                        )
                      : isTool
                      ? Border.all(color: AppColors.border)
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
      ],
    );
  }
}

MarkdownStyleSheet _markdownStyle(
  BuildContext context, {
  required bool isError,
}) {
  const fontFamily = 'PingFang SC';
  const fallback = ['.SF Pro Text', 'system-ui', 'sans-serif'];
  final textColor = isError ? AppColors.danger : AppColors.text;
  final secondaryColor = isError ? AppColors.danger : AppColors.textSecondary;

  return MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
    p: TextStyle(
      fontFamily: fontFamily,
      fontFamilyFallback: fallback,
      fontSize: 15,
      height: 1.55,
      fontWeight: FontWeight.w400,
      color: textColor,
    ),
    strong: TextStyle(
      fontFamily: fontFamily,
      fontFamilyFallback: fallback,
      fontSize: 15,
      height: 1.55,
      fontWeight: FontWeight.w700,
      color: textColor,
    ),
    em: TextStyle(
      fontFamily: fontFamily,
      fontFamilyFallback: fallback,
      fontSize: 15,
      height: 1.55,
      fontStyle: FontStyle.italic,
      color: textColor,
    ),
    listBullet: TextStyle(
      fontFamily: fontFamily,
      fontFamilyFallback: fallback,
      fontSize: 15,
      height: 1.55,
      color: textColor,
    ),
    h1: TextStyle(
      fontFamily: fontFamily,
      fontFamilyFallback: fallback,
      fontSize: 20,
      height: 1.35,
      fontWeight: FontWeight.w700,
      color: textColor,
    ),
    h2: TextStyle(
      fontFamily: fontFamily,
      fontFamilyFallback: fallback,
      fontSize: 18,
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
      fontSize: 13,
      height: 1.45,
      color: textColor,
      backgroundColor: AppColors.inputBg,
    ),
    codeblockPadding: const EdgeInsets.all(12),
    codeblockDecoration: BoxDecoration(
      color: AppColors.inputBg,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.border),
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
      color: AppColors.inputBg,
      borderRadius: BorderRadius.circular(10),
      border: Border(
        left: BorderSide(
          color: AppColors.primary.withValues(alpha: 0.35),
          width: 3,
        ),
      ),
    ),
    tableHead: const TextStyle(
      fontFamily: fontFamily,
      fontFamilyFallback: fallback,
      fontSize: 14,
      fontWeight: FontWeight.w700,
      color: AppColors.text,
    ),
    tableBody: TextStyle(
      fontFamily: fontFamily,
      fontFamilyFallback: fallback,
      fontSize: 14,
      height: 1.45,
      color: textColor,
    ),
    tableBorder: TableBorder.all(color: AppColors.border),
    tableCellsPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    blockSpacing: 10,
    listIndent: 26,
    horizontalRuleDecoration: const BoxDecoration(
      border: Border(top: BorderSide(color: AppColors.border)),
    ),
  );
}

class _UserMessage extends StatelessWidget {
  final ChatMessage message;
  final String time;

  const _UserMessage({required this.message, required this.time});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(6),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.16),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: SelectableText(
            message.content,
            style: const TextStyle(
              fontFamily: 'PingFang SC',
              fontFamilyFallback: ['.SF Pro Text', 'system-ui', 'sans-serif'],
              fontSize: 15,
              height: 1.42,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 5),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              time,
              style: const TextStyle(
                fontFamily: 'PingFang SC',
                fontFamilyFallback: ['.SF Pro Text', 'system-ui', 'sans-serif'],
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
