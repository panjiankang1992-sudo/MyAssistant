import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/platform/app_launcher_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_controls.dart';

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
    final target = AppLaunchTarget.fromActionValue(value);
    if (target != null) {
      return TodoAction(
        value,
        '打开 ${target.label}',
        Icons.open_in_new_rounded,
        AppColors.primary,
      );
    }
    if (AppLaunchTarget.isOpenAppAction(value)) {
      return const TodoAction(
        'open_app',
        '打开应用',
        Icons.open_in_new_rounded,
        AppColors.primary,
      );
    }
    return options.firstWhere(
      (item) => item.value == value,
      orElse: () => options.first,
    );
  }

  static bool matches(String optionValue, String selectedValue) {
    if (optionValue == 'open_app') {
      return AppLaunchTarget.isOpenAppAction(selectedValue);
    }
    return optionValue == selectedValue;
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
    TodoSource('sms', '短信', Icons.sms_rounded, AppColors.healthText),
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
                    child: AppPointerTap(
                      onTap: () => Navigator.of(context).pop(),
                      child: const SizedBox(
                        height: 48,
                        child: Center(
                          child: Text(
                            '取消',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(width: 1, height: 36, color: AppColors.border),
                  Expanded(
                    child: AppPointerTap(
                      onTap: () => Navigator.of(context).pop(_value),
                      child: const SizedBox(
                        height: 48,
                        child: Center(
                          child: Text(
                            '确定',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primary,
                            ),
                          ),
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

  Future<void> _selectOpenApp(BuildContext context) async {
    final selected = await showModalBottomSheet<AppLaunchTarget>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _AppLaunchPickerSheet(),
    );
    if (selected == null) return;
    onChanged(selected.actionValue);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selectedApp = AppLaunchTarget.fromActionValue(value);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: TodoActions.options.map((action) {
        final selected = TodoActions.matches(action.value, value);
        final label = action.value == 'open_app' && selectedApp != null
            ? selectedApp.label
            : action.label;
        return GestureDetector(
          onTap: () {
            if (action.value == 'open_app') {
              _selectOpenApp(context);
              return;
            }
            onChanged(action.value);
          },
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
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 128),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected ? action.color : scheme.appMutedText,
                    ),
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

class _AppLaunchPickerSheet extends StatefulWidget {
  const _AppLaunchPickerSheet();

  @override
  State<_AppLaunchPickerSheet> createState() => _AppLaunchPickerSheetState();
}

class _AppLaunchPickerSheetState extends State<_AppLaunchPickerSheet> {
  final _queryController = TextEditingController();
  late final Future<List<AppLaunchTarget>> _appsFuture;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _appsFuture = AppLauncherService.listApps();
    _queryController.addListener(() {
      setState(() => _query = _queryController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  List<AppLaunchTarget> _filter(List<AppLaunchTarget> apps) {
    if (_query.isEmpty) return apps;
    return apps.where((app) {
      final text = [
        app.label,
        app.subtitle,
        app.id,
        app.platform,
      ].whereType<String>().join(' ').toLowerCase();
      return text.contains(_query);
    }).toList();
  }

  Future<void> _addManualTarget() async {
    final bundleController = TextEditingController(text: _query);
    final abilityController = TextEditingController();
    final result = await showDialog<AppLaunchTarget>(
      context: context,
      builder: (context) {
        final platform = defaultTargetPlatform.name.toLowerCase();
        final isOhos = platform == 'ohos';
        return AlertDialog(
          title: const Text('手动添加应用'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: bundleController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: isOhos ? 'Bundle 名称' : '包名',
                  hintText: isOhos
                      ? '例如 com.tencent.wechat'
                      : '例如 com.tencent.mm',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: abilityController,
                decoration: InputDecoration(
                  labelText: isOhos ? 'Ability 名称' : 'Activity 名称',
                  hintText: isOhos ? '默认 EntryAbility' : '可留空',
                ),
              ),
            ],
          ),
          actions: [
            AppDialogActionButton(
              label: '取消',
              tone: AppActionButtonTone.neutral,
              onPressed: () => Navigator.of(context).pop(),
            ),
            AppDialogActionButton(
              label: '添加',
              filled: true,
              onPressed: () {
                final id = bundleController.text.trim();
                if (id.isEmpty) return;
                final ability = abilityController.text.trim();
                final payload = <String, Object?>{};
                if (platform == 'android') {
                  payload['packageName'] = id;
                  if (ability.isNotEmpty) payload['activityName'] = ability;
                } else if (isOhos) {
                  payload['bundleName'] = id;
                  payload['abilityName'] = ability.isEmpty
                      ? 'EntryAbility'
                      : ability;
                } else {
                  payload['bundleName'] = id;
                  if (ability.isNotEmpty) payload['abilityName'] = ability;
                }
                Navigator.of(context).pop(
                  AppLaunchTarget(
                    platform: platform,
                    id: id,
                    label: id.split('.').last,
                    subtitle: id,
                    payload: payload,
                  ),
                );
              },
            ),
          ],
        );
      },
    );
    bundleController.dispose();
    abilityController.dispose();
    if (!mounted || result == null) return;
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
        decoration: BoxDecoration(
          color: scheme.appSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '选择应用',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: scheme.appText,
                      ),
                    ),
                  ),
                  AppIconTapButton(
                    tooltip: '关闭',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icons.close_rounded,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: TextField(
                controller: _queryController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '搜索应用名称或包名',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: scheme.appInput,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: scheme.appBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: scheme.appBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: scheme.primary, width: 1.4),
                  ),
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<AppLaunchTarget>>(
                future: _appsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final apps = _filter(snapshot.data ?? const []);
                  if (apps.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _query.isEmpty ? '当前平台暂未返回可打开的应用' : '没有匹配的应用',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: scheme.appMutedText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
                    itemBuilder: (context, index) {
                      final app = apps[index];
                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary.withValues(
                            alpha: 0.12,
                          ),
                          child: const Icon(
                            Icons.apps_rounded,
                            color: AppColors.primary,
                          ),
                        ),
                        title: Text(
                          app.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: scheme.appText,
                          ),
                        ),
                        subtitle: Text(
                          app.subtitle?.isNotEmpty == true
                              ? app.subtitle!
                              : app.id,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: scheme.appSubtleText),
                        ),
                        onTap: () => Navigator.of(context).pop(app),
                      );
                    },
                    separatorBuilder: (_, _) => const SizedBox(height: 4),
                    itemCount: apps.length,
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _addManualTarget,
                  icon: const Icon(Icons.edit_note_rounded),
                  label: const Text('手动输入包名'),
                ),
              ),
            ),
          ],
        ),
      ),
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
