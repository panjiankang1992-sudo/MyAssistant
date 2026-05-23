import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models/tag.dart';
import '../../../shared/widgets/tag_chip.dart';
import 'tag_manage_dialog.dart';

class TagSelector extends ConsumerStatefulWidget {
  final List<Tag> selectedTags;
  final ValueChanged<List<Tag>> onChanged;
  final int maxTags;

  const TagSelector({
    super.key,
    required this.selectedTags,
    required this.onChanged,
    this.maxTags = 6,
  });

  @override
  ConsumerState<TagSelector> createState() => _TagSelectorState();
}

class _TagSelectorState extends ConsumerState<TagSelector> {
  bool _expanded = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Tag> get _allTags {
    final asyncTags = ref.watch(allTagsProvider);
    return asyncTags.whenOrNull(data: (tags) => tags) ?? const [];
  }

  List<Tag> get _availableTags {
    final selectedIds = widget.selectedTags.map((t) => t.id).toSet();
    final available =
        _allTags.where((t) => !selectedIds.contains(t.id)).toList();
    if (_searchQuery.isEmpty) return available;
    return available
        .where((t) => t.name.contains(_searchQuery))
        .toList();
  }

  bool get _canCreateTempTag {
    if (_searchQuery.isEmpty || _searchQuery.length > 6) return false;
    final alreadyExists = _allTags.any((t) => t.name == _searchQuery) ||
        widget.selectedTags.any((t) => t.name == _searchQuery);
    return !alreadyExists;
  }

  void _removeTag(Tag tag) {
    final updated = widget.selectedTags.where((t) => t.id != tag.id).toList();
    widget.onChanged(updated);
  }

  void _addTag(Tag tag) {
    if (widget.selectedTags.length >= widget.maxTags) return;
    if (widget.selectedTags.any((t) => t.id == tag.id)) return;
    final updated = [...widget.selectedTags, tag];
    widget.onChanged(updated);
  }

  void _createTempTag() {
    if (!_canCreateTempTag) return;
    final now = DateTime.now();
    final tempTag = Tag(
      id: 'temp-$_searchQuery',
      name: _searchQuery,
      colorKey: 'blue',
      createdAt: now,
      updatedAt: now,
    );
    _addTag(tempTag);
    _searchController.clear();
    setState(() => _searchQuery = '');
  }

  void _openManageDialog() async {
    await showDialog<void>(
      context: context,
      builder: (_) => const TagManageDialog(),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final selectedTags = widget.selectedTags;
    final quickAvailable = _availableTags.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selected tags row
        if (selectedTags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: selectedTags.map((tag) {
                final bgColor = TagPalette.bgColor(tag.colorKey);
                final textColor = TagPalette.textColor(tag.colorKey);
                return GestureDetector(
                  onTap: () => _removeTag(tag),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: textColor.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          tag.name,
                          style: TextStyle(
                            fontFamily: 'PingFang SC',
                            fontFamilyFallback: const [
                              '.SF Pro Text',
                              'system-ui',
                              'sans-serif',
                            ],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.close,
                          size: 14,
                          color: textColor.withValues(alpha: 0.7),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

        // Available tags row + buttons
        Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: quickAvailable.map((tag) {
                  return GestureDetector(
                    onTap: () => _addTag(tag),
                    child: TagChip.fromTag(
                      label: tag.name,
                      colorKey: tag.colorKey,
                    ),
                  );
                }).toList(),
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Text(
                  '更多...',
                  style: TextStyle(
                    fontFamily: 'PingFang SC',
                    fontFamilyFallback: [
                      '.SF Pro Text',
                      'system-ui',
                      'sans-serif',
                    ],
                    fontSize: 12,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _openManageDialog,
              child: const Text(
                '管理',
                style: TextStyle(
                  fontFamily: 'PingFang SC',
                  fontFamilyFallback: [
                    '.SF Pro Text',
                    'system-ui',
                    'sans-serif',
                  ],
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          ],
        ),

        // Expanded section
        if (_expanded) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _searchQuery = v),
            onSubmitted: (_) {
              if (_canCreateTempTag) _createTempTag();
            },
            style: const TextStyle(
              fontFamily: 'PingFang SC',
              fontSize: 14,
            ),
            decoration: const InputDecoration(
              hintText: '搜索或输入新标签（回车创建）',
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              filled: true,
              fillColor: AppColors.inputBg,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _availableTags.map((tag) {
              return GestureDetector(
                onTap: () => _addTag(tag),
                child: TagChip.fromTag(
                  label: tag.name,
                  colorKey: tag.colorKey,
                ),
              );
            }).toList(),
          ),
          if (_canCreateTempTag) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _createTempTag,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  '创建「$_searchQuery」',
                  style: const TextStyle(
                    fontFamily: 'PingFang SC',
                    fontFamilyFallback: [
                      '.SF Pro Text',
                      'system-ui',
                      'sans-serif',
                    ],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }
}
