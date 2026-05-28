import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class TodoAction {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const TodoAction(this.value, this.label, this.icon, this.color);
}

class TodoActions {
  static const options = [
    TodoAction('none', '无动作', Icons.block_rounded, AppColors.textTertiary),
    TodoAction(
      'bookkeeping',
      '记账',
      Icons.receipt_long_rounded,
      AppColors.warning,
    ),
    TodoAction(
      'open_app',
      '打开应用',
      Icons.open_in_new_rounded,
      AppColors.primary,
    ),
    TodoAction('call', '拨打电话', Icons.call_rounded, AppColors.success),
    TodoAction(
      'message',
      '发消息',
      Icons.chat_bubble_outline_rounded,
      AppColors.purple,
    ),
  ];

  static TodoAction byValue(String value) {
    return options.firstWhere(
      (item) => item.value == value,
      orElse: () => options.first,
    );
  }
}

class TodoSource {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const TodoSource(this.value, this.label, this.icon, this.color);
}

class TodoSources {
  static const options = [
    TodoSource('ai', 'AI', Icons.auto_awesome_rounded, AppColors.primary),
    TodoSource('routine', '例行', Icons.repeat_rounded, AppColors.warning),
    TodoSource(
      'calendar',
      '日历',
      Icons.calendar_month_rounded,
      AppColors.calendarText,
    ),
    TodoSource(
      'message',
      '消息',
      Icons.chat_bubble_outline_rounded,
      AppColors.success,
    ),
  ];

  static TodoSource byValue(String value) {
    final normalized = switch (value) {
      'recommend' || 'manual' || 'cloud' => 'ai',
      _ => value,
    };
    return options.firstWhere(
      (item) => item.value == normalized,
      orElse: () => options.first,
    );
  }
}

class TimeInputField extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const TimeInputField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  State<TimeInputField> createState() => _TimeInputFieldState();
}

class _TimeInputFieldState extends State<TimeInputField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _normalize(widget.value));
    _controller.addListener(_emit);
  }

  @override
  void didUpdateWidget(covariant TimeInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final normalized = _normalize(widget.value);
    if (normalized != _controller.text && !_controller.selection.isValid) {
      _controller.text = normalized;
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_emit);
    _controller.dispose();
    super.dispose();
  }

  String _normalize(String raw) {
    final match = RegExp(
      r'^(\d{1,2})(?:[:：点](\d{1,2}))?$',
    ).firstMatch(raw.trim());
    if (match == null) return '09:00';
    final hour = (int.tryParse(match.group(1) ?? '') ?? 9).clamp(0, 23);
    final minute = (int.tryParse(match.group(2) ?? '0') ?? 0).clamp(0, 59);
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  void _emit() {
    final text = _controller.text.trim();
    final match = RegExp(r'^(\d{1,2})(?:[:：点](\d{0,2}))?$').firstMatch(text);
    if (match == null) return;
    final hour = (int.tryParse(match.group(1) ?? '') ?? 0).clamp(0, 23);
    final minuteRaw = match.group(2);
    final minute =
        (minuteRaw == null || minuteRaw.isEmpty
                ? 0
                : int.tryParse(minuteRaw) ?? 0)
            .clamp(0, 59);
    widget.onChanged(
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
    );
  }

  Future<void> _pickTime() async {
    final parts = _normalize(_controller.text).split(':');
    final picked = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭时间选择',
      barrierColor: Colors.black.withValues(alpha: 0.22),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _WheelTimePickerDialog(
          initialHour: int.tryParse(parts.first) ?? 9,
          initialMinute: int.tryParse(parts.last) ?? 0,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
    if (picked == null) return;
    _controller.text = picked;
    widget.onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: scheme.appInput,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.appBorder),
      ),
      child: Row(
        children: [
          InkResponse(
            onTap: _pickTime,
            radius: 22,
            child: Padding(
              padding: const EdgeInsets.only(left: 14, right: 10),
              child: Icon(
                Icons.schedule_rounded,
                size: 18,
                color: scheme.appSubtleText,
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              keyboardType: TextInputType.datetime,
              style: TextStyle(
                fontFamily: 'Menlo',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: scheme.appText,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: '09:00',
                hintStyle: TextStyle(color: scheme.appSubtleText),
              ),
              onEditingComplete: () {
                _controller.text = _normalize(_controller.text);
                FocusScope.of(context).unfocus();
              },
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}

class _WheelTimePickerDialog extends StatefulWidget {
  final int initialHour;
  final int initialMinute;

  const _WheelTimePickerDialog({
    required this.initialHour,
    required this.initialMinute,
  });

  @override
  State<_WheelTimePickerDialog> createState() => _WheelTimePickerDialogState();
}

class _WheelTimePickerDialogState extends State<_WheelTimePickerDialog> {
  late int _hour;
  late int _minute;
  late final FixedExtentScrollController _hourController;
  late final FixedExtentScrollController _minuteController;

  @override
  void initState() {
    super.initState();
    _hour = widget.initialHour.clamp(0, 23);
    _minute = widget.initialMinute.clamp(0, 59);
    _hourController = FixedExtentScrollController(
      initialItem: _hour,
      keepScrollOffset: false,
    );
    _minuteController = FixedExtentScrollController(
      initialItem: _minute,
      keepScrollOffset: false,
    );
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  String get _value =>
      '${_hour.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: math.min(width - 34, 420),
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(34),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 34,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '选择时间',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 250,
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.center,
                      child: Container(
                        height: 70,
                        decoration: BoxDecoration(
                          border: Border.symmetric(
                            horizontal: BorderSide(
                              color: AppColors.border.withValues(alpha: 0.8),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _wheel(
                            controller: _hourController,
                            count: 24,
                            onChanged: (value) => setState(() => _hour = value),
                            itemBuilder: (value) =>
                                value.toString().padLeft(2, '0'),
                          ),
                        ),
                        const Text(
                          ':',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Expanded(
                          child: _wheel(
                            controller: _minuteController,
                            count: 60,
                            onChanged: (value) =>
                                setState(() => _minute = value),
                            itemBuilder: (value) =>
                                value.toString().padLeft(2, '0'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        '取消',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  Container(width: 1, height: 36, color: AppColors.border),
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(_value),
                      child: const Text(
                        '确定',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _wheel({
    required FixedExtentScrollController controller,
    required int count,
    required ValueChanged<int> onChanged,
    required String Function(int value) itemBuilder,
  }) {
    return CupertinoPicker.builder(
      scrollController: controller,
      itemExtent: 68,
      magnification: 1.12,
      squeeze: 1.08,
      useMagnifier: true,
      selectionOverlay: const SizedBox.shrink(),
      onSelectedItemChanged: onChanged,
      childCount: count,
      itemBuilder: (context, index) {
        return Center(
          child: Text(
            itemBuilder(index),
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w900,
              color: AppColors.text,
            ),
          ),
        );
      },
    );
  }
}

class ActionSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const ActionSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: TodoActions.options.map((action) {
        final selected = action.value == value;
        return GestureDetector(
          onTap: () => onChanged(action.value),
          child: AnimatedContainer(
            duration: AppAnimations.shortDuration,
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? action.color.withValues(alpha: 0.12)
                  : scheme.appInput,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected
                    ? action.color.withValues(alpha: 0.38)
                    : scheme.appBorder,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  action.icon,
                  size: 15,
                  color: selected ? action.color : scheme.appSubtleText,
                ),
                const SizedBox(width: 5),
                Text(
                  action.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? action.color : scheme.appMutedText,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class SourceSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const SourceSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: TodoSources.options.map((source) {
        final selected = TodoSources.byValue(value).value == source.value;
        return GestureDetector(
          onTap: () => onChanged(source.value),
          child: AnimatedContainer(
            duration: AppAnimations.shortDuration,
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? source.color.withValues(alpha: 0.12)
                  : scheme.appInput,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected
                    ? source.color.withValues(alpha: 0.38)
                    : scheme.appBorder,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  source.icon,
                  size: 15,
                  color: selected ? source.color : scheme.appSubtleText,
                ),
                const SizedBox(width: 5),
                Text(
                  source.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? source.color : scheme.appMutedText,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
