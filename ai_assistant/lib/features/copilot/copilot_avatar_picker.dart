import 'package:flutter/material.dart';

import '../../core/platform/app_file_picker.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_controls.dart';
import 'avatar_image_crop_page.dart';
import 'copilot_avatar.dart';

class CopilotAvatarPickerDialog extends StatefulWidget {
  final String value;
  final String title;

  const CopilotAvatarPickerDialog({
    super.key,
    required this.value,
    this.title = '选择头像',
  });

  @override
  State<CopilotAvatarPickerDialog> createState() =>
      _CopilotAvatarPickerDialogState();
}

class _CopilotAvatarPickerDialogState extends State<CopilotAvatarPickerDialog> {
  late String _selected;

  @override
  void initState() {
    super.initState();
    _selected = CopilotAvatarCatalog.normalize(widget.value);
  }

  Future<void> _pickCustom() async {
    final files = await AppFilePicker.pickImages(
      allowMultiple: false,
      maxSelectNumber: 1,
    );
    if (files.isEmpty || files.first.path.trim().isEmpty) return;
    if (!mounted) return;
    final croppedPath = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => AvatarImageCropPage(imagePath: files.first.path),
        fullscreenDialog: true,
      ),
    );
    if (!mounted || croppedPath == null || croppedPath.trim().isEmpty) return;
    setState(() => _selected = CopilotAvatarCatalog.fileValue(croppedPath));
  }

  @override
  Widget build(BuildContext context) {
    final isCustom = _selected.startsWith('file:');
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 680),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 34,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 14, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppColors.text,
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
                child: Row(
                  children: [
                    CopilotAvatarView(value: _selected, size: 54),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        CopilotAvatarCatalog.descriptionOf(_selected),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _pickCustom,
                      icon: const Icon(Icons.photo_library_rounded, size: 17),
                      label: const Text('裁剪上传'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.border),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final preset in CopilotAvatarCatalog.presets)
                        _AvatarChoice(
                          label: preset.label,
                          selected: _selected == preset.value,
                          onTap: () => setState(() => _selected = preset.value),
                          child: CopilotAvatarView(
                            value: preset.value,
                            size: 54,
                            selected: _selected == preset.value,
                          ),
                        ),
                      if (isCustom)
                        _AvatarChoice(
                          label: '自选',
                          selected: true,
                          onTap: _pickCustom,
                          child: CopilotAvatarView(
                            value: _selected,
                            size: 54,
                            selected: true,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
                child: Row(
                  children: [
                    Expanded(
                      child: AppDialogActionButton(
                        label: '取消',
                        onPressed: () => Navigator.of(context).pop(),
                        tone: AppActionButtonTone.neutral,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppDialogActionButton(
                        label: '确定',
                        onPressed: () => Navigator.of(context).pop(_selected),
                        filled: true,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarChoice extends StatelessWidget {
  final String label;
  final bool selected;
  final Widget child;
  final VoidCallback onTap;

  const _AvatarChoice({
    required this.label,
    required this.selected,
    required this.child,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: AppAnimations.shortDuration,
          width: 72,
          height: 72,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.08)
                : AppColors.inputBg.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [child]),
        ),
      ),
    );
  }
}
