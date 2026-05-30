import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_controls.dart';
import '../services/todo_text_parser.dart';

class SmartInput extends StatefulWidget {
  final void Function(ParsedResult) onParsed;

  const SmartInput({super.key, required this.onParsed});

  @override
  State<SmartInput> createState() => _SmartInputState();
}

enum _SmartInputStateEnum { idle, preview }

class _SmartInputState extends State<SmartInput> {
  final _controller = TextEditingController();
  _SmartInputStateEnum _state = _SmartInputStateEnum.idle;
  ParsedResult? _result;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  /// 输入内容变化时，如果在预览状态则重置回 idle，
  /// 这样用户修改文字后可以重新点发送进行解析。
  void _onTextChanged() {
    if (_state == _SmartInputStateEnum.preview) {
      setState(() {
        _state = _SmartInputStateEnum.idle;
        _result = null;
      });
    }
  }

  void _analyze() {
    final input = _controller.text.trim();
    if (input.isEmpty) return;

    final result = TodoTextParser.parse(input);

    if (result.title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('未能识别，请尝试更具体的描述'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    setState(() {
      _result = result;
      _state = _SmartInputStateEnum.preview;
    });
  }

  void _confirm() {
    if (_result != null) {
      widget.onParsed(_result!);
    }
  }

  void _reset() {
    _controller.clear();
    setState(() {
      _state = _SmartInputStateEnum.idle;
      _result = null;
    });
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'bill':
        return '帐单';
      case 'work':
        return '工作';
      case 'personal':
        return '个人';
      case 'health':
        return '健康';
      default:
        return type;
    }
  }

  String _getSourceLabel(String source) {
    switch (source) {
      case 'recommend':
        return '推荐';
      case 'routine':
        return '例行';
      case 'message':
        return '消息';
      case 'calendar':
        return '日历';
      case 'manual':
        return '手动';
      default:
        return source;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
            decoration: BoxDecoration(
              color: AppColors.inputBg,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: '输入你想做的事，我会自动识别…',
                      hintStyle: TextStyle(
                        fontFamily: 'PingFang SC',
                        fontFamilyFallback: [
                          '.SF Pro Text',
                          'system-ui',
                          'sans-serif',
                        ],
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textTertiary,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
                    style: const TextStyle(
                      fontFamily: 'PingFang SC',
                      fontFamilyFallback: [
                        '.SF Pro Text',
                        'system-ui',
                        'sans-serif',
                      ],
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: AppColors.text,
                    ),
                    onSubmitted: (_) => _analyze(),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: AppPointerTap(
                    onTap: _analyze,
                    child: const Icon(
                      Icons.send,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_state == _SmartInputStateEnum.preview && _result != null)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.inputBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '✓ AI 识别结果',
                    style: TextStyle(
                      fontFamily: 'PingFang SC',
                      fontFamilyFallback: [
                        '.SF Pro Text',
                        'system-ui',
                        'sans-serif',
                      ],
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _result!.title,
                    style: const TextStyle(
                      fontFamily: 'PingFang SC',
                      fontFamilyFallback: [
                        '.SF Pro Text',
                        'system-ui',
                        'sans-serif',
                      ],
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildPreviewRow('标签', _getTypeLabel(_result!.type)),
                  _buildPreviewRow('时间', _result!.time),
                  _buildPreviewRow(
                    '日期',
                    '${_result!.date.year}-${_result!.date.month.toString().padLeft(2, '0')}-${_result!.date.day.toString().padLeft(2, '0')}',
                  ),
                  _buildPreviewRow('来源', _getSourceLabel(_result!.source)),
                  if (_result!.description != null)
                    _buildPreviewRow('详情', _result!.description!),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: AppDialogActionButton(
                          label: '重新输入',
                          onPressed: _reset,
                          tone: AppActionButtonTone.neutral,
                          height: 44,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AppDialogActionButton(
                          label: '确认添加',
                          onPressed: _confirm,
                          filled: true,
                          height: 44,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPreviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'PingFang SC',
              fontFamilyFallback: ['.SF Pro Text', 'system-ui', 'sans-serif'],
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: AppColors.textTertiary,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'PingFang SC',
              fontFamilyFallback: ['.SF Pro Text', 'system-ui', 'sans-serif'],
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}
