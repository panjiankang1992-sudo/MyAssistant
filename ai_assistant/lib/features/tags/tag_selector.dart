import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/core_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/tag.dart';

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
    final available = _allTags
        .where((t) => !selectedIds.contains(t.id))
        .toList();
    if (_searchQuery.isEmpty) return available;
    return available.where((t) => t.name.contains(_searchQuery)).toList();
  }

  bool get _canCreateTempTag {
    if (_searchQuery.isEmpty || _searchQuery.length > 6) return false;
    final alreadyExists =
        _allTags.any((t) => t.name == _searchQuery) ||
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

  List<Tag> _fitTagsIntoWidth(List<Tag> tags, double maxWidth) {
    if (maxWidth <= 0) return const [];
    final fitted = <Tag>[];
    var used = 0.0;
    for (final tag in tags) {
      final width = _estimateTagWidth(tag.name);
      final next = used + (fitted.isEmpty ? 0 : 6) + width;
      if (next > maxWidth) break;
      fitted.add(tag);
      used = next;
    }
    return fitted;
  }

  double _estimateTagWidth(String label) {
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          fontFamily: 'PingFang SC',
          fontFamilyFallback: ['.SF Pro Text', 'system-ui', 'sans-serif'],
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    return painter.width + 22;
  }

  Widget _tagButton(Tag tag, {required bool selected}) {
    final bgColor = TagPalette.bgColor(tag.colorKey);
    final textColor = TagPalette.textColor(tag.colorKey);
    return GestureDetector(
      onTap: selected ? () => _removeTag(tag) : () => _addTag(tag),
      child: Container(
        padding: EdgeInsets.only(
          left: 10,
          right: selected ? 7 : 10,
          top: 4,
          bottom: 4,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? textColor.withValues(alpha: 0.48) : bgColor,
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
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: textColor,
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.close_rounded,
                size: 13,
                color: textColor.withValues(alpha: 0.75),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final rowTags = [...widget.selectedTags, ..._availableTags];
            final quickTags = _fitTagsIntoWidth(
              rowTags,
              constraints.maxWidth - 58,
            );
            final overflowTags = rowTags.skip(quickTags.length).toList();
            return Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const NeverScrollableScrollPhysics(),
                    child: Row(
                      children: [
                        for (var i = 0; i < quickTags.length; i++) ...[
                          _tagButton(
                            quickTags[i],
                            selected: widget.selectedTags.any(
                              (tag) => tag.id == quickTags[i].id,
                            ),
                          ),
                          if (i != quickTags.length - 1)
                            const SizedBox(width: 6),
                        ],
                      ],
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      overflowTags.isNotEmpty
                          ? '更多+${overflowTags.length}'
                          : '更多...',
                      style: const TextStyle(
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
              ],
            );
          },
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
            style: const TextStyle(fontFamily: 'PingFang SC', fontSize: 14),
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
            children: [...widget.selectedTags, ..._availableTags].map((tag) {
              return _tagButton(
                tag,
                selected: widget.selectedTags.any((t) => t.id == tag.id),
              );
            }).toList(),
          ),
          if (_canCreateTempTag) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _createTempTag,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
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
