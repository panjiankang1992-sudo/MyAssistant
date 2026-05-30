import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/core_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/tag.dart';
import '../../shared/widgets/app_controls.dart';
import '../../shared/widgets/tag_chip.dart';

class TagManagePage extends ConsumerStatefulWidget {
  const TagManagePage({super.key});

  @override
  ConsumerState<TagManagePage> createState() => _TagManagePageState();
}

class _TagManagePageState extends ConsumerState<TagManagePage> {
  final _nameController = TextEditingController();
  String _selectedColorKey = TagPalette.keys.first;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _addTag() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || name.length > 6) return;
    try {
      await ref.read(tagRepoProvider).addTag(name, _selectedColorKey);
      ref.invalidate(allTagsProvider);
      _nameController.clear();
      if (mounted) setState(() => _selectedColorKey = TagPalette.keys.first);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('添加标签失败: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _deleteTag(String id) async {
    await ref.read(tagRepoProvider).deleteTag(id);
    ref.invalidate(allTagsProvider);
  }

  Future<void> _swapTags(List<Tag> tags, int index1, int index2) async {
    if (index1 < 0 ||
        index1 >= tags.length ||
        index2 < 0 ||
        index2 >= tags.length) {
      return;
    }
    final swapped = List<Tag>.from(tags);
    final temp = swapped[index1];
    swapped[index1] = swapped[index2];
    swapped[index2] = temp;
    for (var i = 0; i < swapped.length; i++) {
      swapped[i] = swapped[i].copyWith(sortOrder: i);
    }
    await ref.read(tagRepoProvider).reorderTags(swapped);
    ref.invalidate(allTagsProvider);
  }

  Future<void> _changeColor(Tag tag, String newColorKey) async {
    await ref
        .read(tagRepoProvider)
        .updateTag(tag.copyWith(colorKey: newColorKey));
    ref.invalidate(allTagsProvider);
  }

  void _showColorPicker(Tag tag) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppAnimations.elevatedShadow(),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '选择颜色',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: TagPalette.keys.map((key) {
                final selected = key == tag.colorKey;
                return GestureDetector(
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _changeColor(tag, key);
                  },
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: TagPalette.bgColor(key),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected
                            ? TagPalette.textColor(key)
                            : AppColors.border,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: selected
                        ? Icon(
                            Icons.check_rounded,
                            size: 19,
                            color: TagPalette.textColor(key),
                          )
                        : null,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncTags = ref.watch(allTagsProvider);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('标签管理'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: asyncTags.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('标签加载失败: $error')),
        data: (tags) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
          children: [
            const Text(
              '标签可用于代办、记账和随手记，修改后会同步影响各模块的选择器。',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            _CreateTagCard(
              controller: _nameController,
              selectedColorKey: _selectedColorKey,
              onColorChanged: (key) => setState(() => _selectedColorKey = key),
              onAdd: _addTag,
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Text(
                  '全部标签',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                Text(
                  '${tags.length} 个',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (tags.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(
                  child: Text(
                    '暂无标签',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              )
            else
              ...List.generate(tags.length, (index) {
                final tag = tags[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _TagManageRow(
                    tag: tag,
                    canMoveUp: index > 0,
                    canMoveDown: index < tags.length - 1,
                    onColorTap: () => _showColorPicker(tag),
                    onMoveUp: () => _swapTags(tags, index, index - 1),
                    onMoveDown: () => _swapTags(tags, index, index + 1),
                    onDelete: tag.isPreset ? null : () => _deleteTag(tag.id),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _CreateTagCard extends StatelessWidget {
  final TextEditingController controller;
  final String selectedColorKey;
  final ValueChanged<String> onColorChanged;
  final VoidCallback onAdd;

  const _CreateTagCard({
    required this.controller,
    required this.selectedColorKey,
    required this.onColorChanged,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    hintText: '新增标签，最多 6 个字',
                    counterText: '',
                    isDense: true,
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => onAdd(),
                ),
              ),
              const SizedBox(width: 10),
              AppDialogActionButton(
                label: '添加',
                onPressed: onAdd,
                filled: true,
                height: 36,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: TagPalette.keys.map((key) {
              final selected = key == selectedColorKey;
              return GestureDetector(
                onTap: () => onColorChanged(key),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: TagPalette.bgColor(key),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected
                          ? TagPalette.textColor(key)
                          : AppColors.border,
                      width: selected ? 2 : 1,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _TagManageRow extends StatelessWidget {
  final Tag tag;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onColorTap;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback? onDelete;

  const _TagManageRow({
    required this.tag,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onColorTap,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          TagChip.fromTag(label: tag.name, colorKey: tag.colorKey),
          if (tag.isPreset) ...[
            const SizedBox(width: 8),
            const Text(
              '预设',
              style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
            ),
          ],
          const Spacer(),
          GestureDetector(
            onTap: onColorTap,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: TagPalette.bgColor(tag.colorKey),
                shape: BoxShape.circle,
                border: Border.all(
                  color: TagPalette.textColor(
                    tag.colorKey,
                  ).withValues(alpha: 0.35),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _IconCircle(
            icon: Icons.keyboard_arrow_up_rounded,
            enabled: canMoveUp,
            onTap: onMoveUp,
          ),
          const SizedBox(width: 6),
          _IconCircle(
            icon: Icons.keyboard_arrow_down_rounded,
            enabled: canMoveDown,
            onTap: onMoveDown,
          ),
          if (onDelete != null) ...[
            const SizedBox(width: 6),
            _IconCircle(
              icon: Icons.delete_outline_rounded,
              color: AppColors.danger,
              onTap: onDelete!,
            ),
          ],
        ],
      ),
    );
  }
}

class _IconCircle extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;
  final Color color;

  const _IconCircle({
    required this.icon,
    required this.onTap,
    this.enabled = true,
    this.color = AppColors.textTertiary,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = enabled ? color : color.withValues(alpha: 0.28);
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: effectiveColor.withValues(alpha: 0.08),
          border: Border.all(color: effectiveColor.withValues(alpha: 0.16)),
        ),
        child: Icon(icon, size: 18, color: effectiveColor),
      ),
    );
  }
}
