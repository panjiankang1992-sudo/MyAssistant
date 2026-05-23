import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models/tag.dart';
import '../../../shared/widgets/tag_chip.dart';

class TagManageDialog extends ConsumerStatefulWidget {
  const TagManageDialog({super.key});

  @override
  ConsumerState<TagManageDialog> createState() => _TagManageDialogState();
}

class _TagManageDialogState extends ConsumerState<TagManageDialog> {
  final _nameController = TextEditingController();
  String _selectedColorKey = TagPalette.keys.first;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  List<Tag> get _tags {
    final asyncTags = ref.watch(allTagsProvider);
    return asyncTags.whenOrNull(data: (tags) => tags) ?? const [];
  }

  Future<void> _addTag() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || name.length > 6) return;
    await ref.read(tagRepoProvider).addTag(name, _selectedColorKey);
    ref.invalidate(allTagsProvider);
    _nameController.clear();
    setState(() => _selectedColorKey = TagPalette.keys.first);
  }

  Future<void> _deleteTag(String id) async {
    await ref.read(tagRepoProvider).deleteTag(id);
    ref.invalidate(allTagsProvider);
  }

  Future<void> _swapTags(int index1, int index2) async {
    final tags = _tags;
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
    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => entry.remove(),
              behavior: HitTestBehavior.opaque,
              child: const SizedBox.expand(),
            ),
          ),
          Positioned(
            left: offset.dx,
            top: offset.dy + size.height + 4,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: TagPalette.keys.map((key) {
                    final isSelected = key == tag.colorKey;
                    return GestureDetector(
                      onTap: () {
                        entry.remove();
                        _changeColor(tag, key);
                      },
                      child: Container(
                        width: 24,
                        height: 24,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: TagPalette.bgColor(key),
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(
                                  color: TagPalette.textColor(key),
                                  width: 2,
                                )
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    overlay.insert(entry);
  }

  @override
  Widget build(BuildContext context) {
    final tags = _tags;

    return AlertDialog(
      title: const Text(
        '标签管理',
        style: TextStyle(
          fontFamily: 'PingFang SC',
          fontFamilyFallback: ['.SF Pro Text', 'system-ui', 'sans-serif'],
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: AppColors.text,
        ),
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.85,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Add tag row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    maxLength: 6,
                    style: const TextStyle(
                      fontFamily: 'PingFang SC',
                      fontSize: 14,
                    ),
                    decoration: const InputDecoration(
                      hintText: '标签名称',
                      counterText: '',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      filled: true,
                      fillColor: AppColors.inputBg,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Color palette dots
                ...TagPalette.keys.map((key) {
                  final isSelected = key == _selectedColorKey;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColorKey = key),
                    child: Container(
                      width: 20,
                      height: 20,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: TagPalette.bgColor(key),
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(
                                color: TagPalette.textColor(key),
                                width: 2,
                              )
                            : null,
                      ),
                    ),
                  );
                }),
                const SizedBox(width: 8),
                SizedBox(
                  height: 32,
                  child: TextButton(
                    onPressed: _addTag,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      '添加',
                      style: TextStyle(
                        fontFamily: 'PingFang SC',
                        fontFamilyFallback: [
                          '.SF Pro Text',
                          'system-ui',
                          'sans-serif',
                        ],
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 8),
            // Tag list
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: tags.length,
                separatorBuilder: (context, index) => const SizedBox(height: 4),
                itemBuilder: (context, index) {
                  final tag = tags[index];
                  return Row(
                    children: [
                      TagChip.fromTag(
                        label: tag.name,
                        colorKey: tag.colorKey,
                      ),
                      const SizedBox(width: 8),
                      // Color dot (tap to change)
                      GestureDetector(
                        onTap: () => _showColorPicker(tag),
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: TagPalette.bgColor(tag.colorKey),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: TagPalette.textColor(tag.colorKey)
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Up button
                      GestureDetector(
                        onTap: index > 0
                            ? () => _swapTags(index, index - 1)
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            Icons.arrow_upward,
                            size: 18,
                            color: index > 0
                                ? AppColors.textTertiary
                                : AppColors.textTertiary.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                      // Down button
                      GestureDetector(
                        onTap: index < tags.length - 1
                            ? () => _swapTags(index, index + 1)
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            Icons.arrow_downward,
                            size: 18,
                            color: index < tags.length - 1
                                ? AppColors.textTertiary
                                : AppColors.textTertiary.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                      // Delete button (hidden for preset tags)
                      if (!tag.isPreset)
                        GestureDetector(
                          onTap: () => _deleteTag(tag.id),
                          child: const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: AppColors.danger,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            '完成',
            style: TextStyle(
              fontFamily: 'PingFang SC',
              fontFamilyFallback: [
                '.SF Pro Text',
                'system-ui',
                'sans-serif',
              ],
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}
