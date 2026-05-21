import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class CopilotInput extends StatefulWidget {
  final void Function(String) onSend;

  const CopilotInput({super.key, required this.onSend});

  @override
  State<CopilotInput> createState() => _CopilotInputState();
}

class _CopilotInputState extends State<CopilotInput> {
  final _controller = TextEditingController();
  String _selectedModel = 'Claude Sonnet';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _controller.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _controller.text.trim().isNotEmpty;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(left: 16, right: 6, bottom: 8),
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedModel,
                    isDense: true,
                    icon: const Icon(Icons.keyboard_arrow_down, size: 14, color: AppColors.primary),
                    style: const TextStyle(
                      fontFamily: 'PingFang SC',
                      fontFamilyFallback: ['.SF Pro Text', 'system-ui', 'sans-serif'],
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Claude Opus', child: Text('Claude Opus')),
                      DropdownMenuItem(value: 'Claude Sonnet', child: Text('Claude Sonnet')),
                      DropdownMenuItem(value: 'Claude Haiku', child: Text('Claude Haiku')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedModel = value;
                        });
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _controller,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: '输入你的问题…',
                    hintStyle: TextStyle(
                      fontFamily: 'PingFang SC',
                      fontFamilyFallback: ['.SF Pro Text', 'system-ui', 'sans-serif'],
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textTertiary,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                  style: const TextStyle(
                    fontFamily: 'PingFang SC',
                    fontFamilyFallback: ['.SF Pro Text', 'system-ui', 'sans-serif'],
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: AppColors.text,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: hasText ? AppColors.primary : AppColors.textTertiary,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: hasText ? _handleSend : null,
                  icon: const Icon(Icons.arrow_upward, size: 14, color: Colors.white),
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}