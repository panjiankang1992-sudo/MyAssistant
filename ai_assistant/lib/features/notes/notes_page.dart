import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers/core_providers.dart';
import '../../core/platform/app_file_picker.dart';
import '../../core/platform/app_launcher_service.dart';
import '../../core/platform/app_performance.dart';
import '../../core/storage/app_paths.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/app_attachment.dart';
import '../../domain/models/quick_note.dart';
import '../../domain/models/tag.dart';
import '../../shared/widgets/edge_swipe_pop.dart';
import '../../shared/widgets/app_controls.dart';
import '../../shared/widgets/profile_avatar_button.dart';
import '../tags/tag_selector.dart';
import 'notes_provider.dart';

enum _NoteBlockType { image, attachment, snapshot }

class _NoteBlock {
  final _NoteBlockType type;
  final String title;
  final String value;
  final String? description;
  final int? sizeBytes;

  const _NoteBlock({
    required this.type,
    required this.title,
    required this.value,
    this.description,
    this.sizeBytes,
  });
}

class _ParsedNoteContent {
  final String text;
  final List<_NoteBlock> blocks;

  const _ParsedNoteContent(this.text, this.blocks);
}

_ParsedNoteContent _parseNoteContent(String raw) {
  final lines = raw.split('\n');
  final textLines = <String>[];
  final blocks = <_NoteBlock>[];

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].trimRight();
    if (line.startsWith('[图片] ')) {
      final path = i + 1 < lines.length ? lines[++i].trim() : '';
      blocks.add(
        _NoteBlock(
          type: _NoteBlockType.image,
          title: line.replaceFirst('[图片] ', '').trim(),
          value: path,
        ),
      );
      continue;
    }
    if (line.startsWith('[附件] ')) {
      final path = i + 1 < lines.length ? lines[++i].trim() : '';
      blocks.add(
        _NoteBlock(
          type: _NoteBlockType.attachment,
          title: line.replaceFirst('[附件] ', '').trim(),
          value: path,
        ),
      );
      continue;
    }
    if (line.startsWith('【网页快照】')) {
      final title = line.replaceFirst('【网页快照】', '').trim();
      final url = i + 1 < lines.length ? lines[++i].trim() : '';
      final desc = i + 1 < lines.length && !_isBlockStart(lines[i + 1])
          ? lines[++i].trim()
          : '';
      blocks.add(
        _NoteBlock(
          type: _NoteBlockType.snapshot,
          title: title.isEmpty ? url : title,
          value: url,
          description: desc,
        ),
      );
      continue;
    }
    textLines.add(line);
  }

  return _ParsedNoteContent(textLines.join('\n').trim(), blocks);
}

bool _isBlockStart(String line) {
  return line.startsWith('[图片] ') ||
      line.startsWith('[附件] ') ||
      line.startsWith('【网页快照】');
}

String _serializeNoteContent(String text, List<_NoteBlock> blocks) {
  final parts = <String>[];
  if (text.trim().isNotEmpty) parts.add(text.trim());
  for (final block in blocks) {
    switch (block.type) {
      case _NoteBlockType.image:
        parts.add('[图片] ${block.title}\n${block.value}');
        break;
      case _NoteBlockType.attachment:
        parts.add('[附件] ${block.title}\n${block.value}');
        break;
      case _NoteBlockType.snapshot:
        final desc = block.description?.trim() ?? '';
        parts.add(
          '【网页快照】${block.title}\n${block.value}${desc.isEmpty ? '' : '\n$desc'}',
        );
        break;
    }
  }
  return parts.join('\n');
}

List<_NoteBlock> _nonAttachmentBlocks(List<_NoteBlock> blocks) {
  return blocks
      .where((block) => block.type == _NoteBlockType.snapshot)
      .toList();
}

List<NoteAttachmentDraft> _attachmentDraftsFromBlocks(List<_NoteBlock> blocks) {
  return blocks
      .where(
        (block) =>
            block.type == _NoteBlockType.image ||
            block.type == _NoteBlockType.attachment,
      )
      .map(
        (block) => NoteAttachmentDraft(
          path: block.value,
          fileName: block.title,
          attachmentType: block.type == _NoteBlockType.image ? 'image' : 'file',
          mimeType: _mimeTypeForFileName(block.title),
        ),
      )
      .toList();
}

String _attachmentTypeForFileName(String fileName) {
  final lower = fileName.toLowerCase();
  if (RegExp(r'\.(png|jpe?g|gif|webp|heic|bmp)$').hasMatch(lower)) {
    return 'image';
  }
  if (RegExp(r'\.(m4a|mp3|wav|aac|flac|ogg)$').hasMatch(lower)) {
    return 'audio';
  }
  return 'file';
}

String? _mimeTypeForFileName(String fileName) {
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  if (lower.endsWith('.gif')) return 'image/gif';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.heic')) return 'image/heic';
  if (lower.endsWith('.mp3')) return 'audio/mpeg';
  if (lower.endsWith('.m4a')) return 'audio/mp4';
  if (lower.endsWith('.wav')) return 'audio/wav';
  if (lower.endsWith('.aac')) return 'audio/aac';
  if (lower.endsWith('.pdf')) return 'application/pdf';
  if (lower.endsWith('.txt')) return 'text/plain';
  if (lower.endsWith('.json')) return 'application/json';
  return null;
}

String _plainNoteText(String raw) => _parseNoteContent(raw).text;

String _inferNoteTitle(String content, List<_NoteBlock> blocks) {
  final text = _plainNoteText(content)
      .split('\n')
      .map((line) => line.trim())
      .firstWhere((line) => line.isNotEmpty, orElse: () => '');
  final source = text.isNotEmpty
      ? text
      : blocks.isNotEmpty
      ? blocks.first.title
      : '';
  final compact = source.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (compact.length <= 18) return compact;
  return compact.substring(0, 18);
}

Future<void> _openUrl(String url) async {
  final uri = Uri.tryParse(url.startsWith('http') ? url : 'https://$url');
  if (uri == null) return;
  var opened = false;
  try {
    opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } on PlatformException {
    opened = false;
  } on MissingPluginException {
    opened = false;
  }
  if (opened) return;
  await AppLauncherService.openApp(
    AppLaunchTarget(
      platform: 'ohos',
      id: 'url:${uri.toString()}',
      label: uri.host.isEmpty ? uri.toString() : uri.host,
      payload: {
        'action': 'ohos.want.action.viewData',
        'uri': uri.toString(),
        'type': 'text/html',
      },
    ),
  );
}

Future<void> _openFile(String path) async {
  await AppFilePicker.openFile(path, mimeType: _mimeTypeForFileName(path));
}

Future<void> _openAttachmentRecord(AppAttachment attachment) async {
  final bytes = base64Decode(attachment.contentBase64);
  final dir = Directory(
    '${(await getAppSupportDirectory()).path}/attachment_cache',
  );
  if (!await dir.exists()) await dir.create(recursive: true);
  final fileName = attachment.fileName.replaceAll(
    RegExp(r'[^a-zA-Z0-9._\-\u4e00-\u9fa5]'),
    '_',
  );
  final file = File('${dir.path}/${attachment.id}_$fileName');
  await file.writeAsBytes(bytes, flush: true);
  await AppFilePicker.openFile(file.path, mimeType: attachment.mimeType);
}

class NotesPage extends ConsumerStatefulWidget {
  final VoidCallback onAvatarTap;

  const NotesPage({super.key, required this.onAvatarTap});

  @override
  ConsumerState<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends ConsumerState<NotesPage> {
  DateTime? _filterDate;
  _NotesViewMode _mode = _NotesViewMode.diary;
  _NotesLayoutMode _layoutMode = _NotesLayoutMode.list;
  bool _analyzing = false;

  List<QuickNote> _visibleNotes(List<QuickNote> notes) {
    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 29));
    final result = notes.where((n) {
      if (n.deleted || n.archived || n.isAnalysis) return false;
      if (_mode == _NotesViewMode.diary) {
        if (n.noteType != QuickNoteType.diary) return false;
        if (_filterDate != null) return _isSameDay(n.date, _filterDate!);
        return !n.date.isBefore(start);
      }
      if (_mode == _NotesViewMode.document) {
        if (_filterDate != null) return _isSameDay(n.date, _filterDate!);
        return n.noteType == QuickNoteType.document;
      }
      return false;
    }).toList();
    result.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return result;
  }

  QuickNoteType? get _activeNoteType {
    if (_mode == _NotesViewMode.diary) return QuickNoteType.diary;
    if (_mode == _NotesViewMode.document) return QuickNoteType.document;
    return null;
  }

  Map<DateTime, int> _counts(List<QuickNote> notes) {
    final type = _activeNoteType;
    if (type == null) return const {};
    final result = <DateTime, int>{};
    for (final note in notes.where(
      (n) => !n.deleted && !n.archived && !n.isAnalysis && n.noteType == type,
    )) {
      final day = DateTime(note.date.year, note.date.month, note.date.day);
      result[day] = (result[day] ?? 0) + 1;
    }
    return result;
  }

  Future<void> _pickDate(List<QuickNote> notes) async {
    final counts = _counts(notes);
    final picked = await showAppDatePicker(
      context: context,
      initialDate: _filterDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      markerBuilder: (date) {
        final day = DateTime(date.year, date.month, date.day);
        final count = counts[day];
        if (count == null || count <= 0) return null;
        return AppDateMarker(label: '$count', color: AppColors.primary);
      },
    );
    if (!mounted || picked == null) return;
    setState(() => _filterDate = picked);
  }

  void _openEditor([QuickNote? note, String? initialText]) {
    Navigator.of(context).push(
      _notesSideRoute(
        _NoteEditorPage(
          initial: note,
          initialText: initialText,
          initialDate: DateTime.now(),
          readOnly: note?.archived == true,
          onSave: (title, content, date, tags, attachments) {
            return ref
                .read(notesNotifierProvider.notifier)
                .upsert(
                  initial: note,
                  title: title,
                  content: content,
                  date: date,
                  tags: tags,
                  attachments: attachments,
                );
          },
        ),
      ),
    );
  }

  Future<void> _analyzeNotes() async {
    if (_analyzing) return;
    setState(() => _analyzing = true);
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
        content: Text('正在归纳未分析的文档和有效日记...'),
        duration: Duration(seconds: 1),
      ),
    );
    try {
      final count = await ref
          .read(notesNotifierProvider.notifier)
          .analyzePendingNotes();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(count == 0 ? '没有新的文档或有效日记需要归纳' : '已归纳 $count 条文档/日记'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('归纳失败：$e'), backgroundColor: AppColors.danger),
      );
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  Future<void> _shareNote(QuickNote note) async {
    final content = '# ${note.title}\n\n${note.content}'.trim();
    await Clipboard.setData(ClipboardData(text: content));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已复制随手记内容，可粘贴到其他应用分享')));
  }

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(notesNotifierProvider);
    final visible = _visibleNotes(notes);
    final analysisDocs = notes
        .where((n) => !n.deleted && !n.archived && n.isAnalysis)
        .toList();
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.appPage,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _NotesHeader(
                  mode: _mode,
                  filterDate: _filterDate,
                  layoutMode: _layoutMode,
                  onModeChanged: (mode) => setState(() => _mode = mode),
                  onPickDate: () => _pickDate(notes),
                  onLayoutChanged: (value) =>
                      setState(() => _layoutMode = value),
                  onAvatarTap: widget.onAvatarTap,
                ),
                if (_filterDate != null && _mode != _NotesViewMode.analysis)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: TextButton.icon(
                        onPressed: () => setState(() => _filterDate = null),
                        icon: const Icon(Icons.close_rounded, size: 16),
                        label: const Text('清除日期筛选'),
                      ),
                    ),
                  ),
                Expanded(
                  child: _mode != _NotesViewMode.analysis
                      ? (visible.isEmpty
                            ? const _NotesEmpty()
                            : _NotesCollection(
                                notes: visible,
                                layoutMode: _layoutMode,
                                onOpen: (note) => _openEditor(note),
                                onArchive: (note) => ref
                                    .read(notesNotifierProvider.notifier)
                                    .archive(note),
                                onTogglePin: (note) => ref
                                    .read(notesNotifierProvider.notifier)
                                    .togglePinned(note),
                                onShare: _shareNote,
                                onDelete: (note) async {
                                  final ok = await _confirmDelete(
                                    context,
                                    note,
                                  );
                                  if (ok == true) {
                                    ref
                                        .read(notesNotifierProvider.notifier)
                                        .delete(note);
                                  }
                                },
                              ))
                      : _AnalysisLibrary(
                          notes: analysisDocs,
                          onOpen: (note) => _openEditor(note),
                        ),
                ),
              ],
            ),
            if (_mode != _NotesViewMode.analysis)
              Positioned(
                left: 0,
                right: 0,
                bottom: 14,
                child: Center(
                  child: AppAddFab(
                    tooltip: '新增随手记',
                    onPressed: () => _openEditor(),
                    gradientColors: const [
                      Color(0xFF6C63FF),
                      Color(0xFF0A84FF),
                    ],
                  ),
                ),
              )
            else
              Positioned(
                left: 0,
                right: 0,
                bottom: 14,
                child: Center(
                  child: _AnalyzeFab(
                    loading: _analyzing,
                    onPressed: _analyzeNotes,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

enum _NotesViewMode { diary, document, analysis }

enum _NotesLayoutMode { list, grid }

class _NotesHeader extends StatelessWidget {
  final _NotesViewMode mode;
  final DateTime? filterDate;
  final _NotesLayoutMode layoutMode;
  final ValueChanged<_NotesViewMode> onModeChanged;
  final VoidCallback onPickDate;
  final ValueChanged<_NotesLayoutMode> onLayoutChanged;
  final VoidCallback onAvatarTap;

  const _NotesHeader({
    required this.mode,
    required this.filterDate,
    required this.layoutMode,
    required this.onModeChanged,
    required this.onPickDate,
    required this.onLayoutChanged,
    required this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              Positioned(
                top: 0,
                right: 0,
                child: ProfileAvatarButton(onTap: onAvatarTap),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 54),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '随手记',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: scheme.appText,
                            ),
                          ),
                        ),
                        if (mode != _NotesViewMode.analysis) ...[
                          const SizedBox(width: 10),
                          _NotesDateFilterButton(
                            filterDate: filterDate,
                            onTap: onPickDate,
                          ),
                          const SizedBox(width: 8),
                          _LayoutToggleButton(
                            value: layoutMode,
                            onChanged: onLayoutChanged,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    _NotesModeSegmented(value: mode, onChanged: onModeChanged),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NotesDateFilterButton extends StatelessWidget {
  final DateTime? filterDate;
  final VoidCallback onTap;

  const _NotesDateFilterButton({required this.filterDate, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = filterDate != null;
    final tooltip = active ? DateFormat('MM月dd日').format(filterDate!) : '筛选日期';
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: active
                ? scheme.primary.withValues(alpha: 0.1)
                : scheme.appInput,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: active
                  ? scheme.primary.withValues(alpha: 0.25)
                  : scheme.appBorder,
            ),
          ),
          child: const Icon(
            Icons.calendar_month_rounded,
            size: 20,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

Future<bool?> _confirmDelete(BuildContext context, QuickNote note) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('删除随手记'),
      content: Text('确定删除「${note.title}」吗？'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('删除', style: TextStyle(color: AppColors.danger)),
        ),
      ],
    ),
  );
}

class _LayoutToggleButton extends StatelessWidget {
  final _NotesLayoutMode value;
  final ValueChanged<_NotesLayoutMode> onChanged;

  const _LayoutToggleButton({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: value == _NotesLayoutMode.list ? '切换宫格' : '切换列表',
      onPressed: () => onChanged(
        value == _NotesLayoutMode.list
            ? _NotesLayoutMode.grid
            : _NotesLayoutMode.list,
      ),
      icon: Icon(
        value == _NotesLayoutMode.list
            ? Icons.grid_view_rounded
            : Icons.view_agenda_outlined,
        color: scheme.primary,
      ),
      style: IconButton.styleFrom(
        fixedSize: const Size(40, 40),
        minimumSize: const Size(40, 40),
        maximumSize: const Size(40, 40),
        backgroundColor: scheme.appInput,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.appBorder),
        ),
      ),
    );
  }
}

class _NotesCollection extends StatelessWidget {
  final List<QuickNote> notes;
  final _NotesLayoutMode layoutMode;
  final ValueChanged<QuickNote> onOpen;
  final ValueChanged<QuickNote> onArchive;
  final ValueChanged<QuickNote> onTogglePin;
  final ValueChanged<QuickNote> onShare;
  final ValueChanged<QuickNote> onDelete;

  const _NotesCollection({
    required this.notes,
    required this.layoutMode,
    required this.onOpen,
    required this.onArchive,
    required this.onTogglePin,
    required this.onShare,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (layoutMode == _NotesLayoutMode.grid) {
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 112),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 260,
          mainAxisExtent: 188,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
        ),
        itemCount: notes.length,
        itemBuilder: (context, index) => _NoteCard(
          note: notes[index],
          compact: true,
          onTap: () => onOpen(notes[index]),
          onArchive: () => onArchive(notes[index]),
          onTogglePin: () => onTogglePin(notes[index]),
          onShare: () => onShare(notes[index]),
          onDelete: () => onDelete(notes[index]),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 112),
      itemCount: notes.length,
      itemBuilder: (context, index) => _NoteCard(
        note: notes[index],
        onTap: () => onOpen(notes[index]),
        onArchive: () => onArchive(notes[index]),
        onTogglePin: () => onTogglePin(notes[index]),
        onShare: () => onShare(notes[index]),
        onDelete: () => onDelete(notes[index]),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  final QuickNote note;
  final VoidCallback onTap;
  final VoidCallback onTogglePin;
  final VoidCallback onShare;
  final VoidCallback onArchive;
  final VoidCallback onDelete;
  final bool compact;

  const _NoteCard({
    required this.note,
    required this.onTap,
    required this.onTogglePin,
    required this.onShare,
    required this.onArchive,
    required this.onDelete,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: compact ? 188 : null,
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
          decoration: BoxDecoration(
            color: scheme.appSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.appBorder.withValues(alpha: 0.7)),
            boxShadow: scheme.isDarkTheme ? null : AppAnimations.cardShadow(),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (note.pinned) ...[
                    const Icon(
                      Icons.push_pin_rounded,
                      size: 15,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Text(
                      note.title,
                      maxLines: compact ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: scheme.appText,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (compact)
                Expanded(
                  child: _NoteTextExcerpt(content: note.content, maxLines: 4),
                )
              else
                _NoteTextExcerpt(content: note.content, maxLines: 2),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    DateFormat('MM-dd HH:mm').format(note.updatedAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.appSubtleText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const NeverScrollableScrollPhysics(),
                      child: Row(
                        children: note.tags
                            .take(compact ? 2 : 4)
                            .map(
                              (t) => Padding(
                                padding: const EdgeInsets.only(right: 5),
                                child: _MiniTag(tag: t),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                  _NoteMoreButton(
                    note: note,
                    onTogglePin: onTogglePin,
                    onShare: onShare,
                    onArchive: onArchive,
                    onDelete: onDelete,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoteTextExcerpt extends StatelessWidget {
  final String content;
  final int maxLines;

  const _NoteTextExcerpt({required this.content, required this.maxLines});

  @override
  Widget build(BuildContext context) {
    return Text(
      _plainNoteText(content).replaceAll(RegExp(r'\s+'), ' ').trim(),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 13,
        height: 1.4,
        color: AppColors.textSecondary,
      ),
    );
  }
}

class _NoteMoreButton extends StatefulWidget {
  final QuickNote note;
  final VoidCallback onTogglePin;
  final VoidCallback onShare;
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  const _NoteMoreButton({
    required this.note,
    required this.onTogglePin,
    required this.onShare,
    required this.onArchive,
    required this.onDelete,
  });

  @override
  State<_NoteMoreButton> createState() => _NoteMoreButtonState();
}

class _NoteMoreButtonState extends State<_NoteMoreButton> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _entry;

  @override
  void dispose() {
    _hideMenu();
    super.dispose();
  }

  void _toggleMenu() {
    if (_entry == null) {
      _showMenu();
    } else {
      _hideMenu();
    }
  }

  void _hideMenu() {
    _entry?.remove();
    _entry = null;
  }

  void _select(_NoteMenuAction action) {
    _hideMenu();
    switch (action) {
      case _NoteMenuAction.pin:
        widget.onTogglePin();
        break;
      case _NoteMenuAction.share:
        widget.onShare();
        break;
      case _NoteMenuAction.archive:
        widget.onArchive();
        break;
      case _NoteMenuAction.delete:
        widget.onDelete();
        break;
    }
  }

  void _showMenu() {
    final overlay = Overlay.of(context);
    _entry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _hideMenu,
            ),
          ),
          CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            targetAnchor: Alignment.bottomRight,
            followerAnchor: Alignment.topRight,
            offset: const Offset(0, 8),
            child: Material(
              color: Colors.transparent,
              child: _NoteActionMenu(note: widget.note, onSelected: _select),
            ),
          ),
        ],
      ),
    );
    overlay.insert(_entry!);
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: InkWell(
        onTap: _toggleMenu,
        borderRadius: BorderRadius.circular(15),
        child: const SizedBox(
          width: 34,
          height: 30,
          child: Icon(
            Icons.more_horiz_rounded,
            size: 22,
            color: AppColors.textTertiary,
          ),
        ),
      ),
    );
  }
}

enum _NoteMenuAction { pin, share, archive, delete }

class _NoteActionMenu extends StatelessWidget {
  final QuickNote note;
  final ValueChanged<_NoteMenuAction> onSelected;

  const _NoteActionMenu({required this.note, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.76)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MenuButton(
            action: _NoteMenuAction.pin,
            icon: note.pinned
                ? Icons.push_pin_outlined
                : Icons.push_pin_rounded,
            label: note.pinned ? '取消置顶' : '置顶',
            onSelected: onSelected,
          ),
          _MenuButton(
            action: _NoteMenuAction.share,
            icon: Icons.ios_share_rounded,
            label: '分享',
            onSelected: onSelected,
          ),
          _MenuButton(
            action: _NoteMenuAction.archive,
            icon: Icons.inventory_2_outlined,
            label: '归档',
            onSelected: onSelected,
          ),
          _MenuButton(
            action: _NoteMenuAction.delete,
            icon: Icons.delete_outline_rounded,
            label: '删除',
            danger: true,
            onSelected: onSelected,
          ),
        ],
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final _NoteMenuAction action;
  final IconData icon;
  final String label;
  final bool danger;
  final ValueChanged<_NoteMenuAction> onSelected;

  const _MenuButton({
    required this.action,
    required this.icon,
    required this.label,
    required this.onSelected,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onSelected(action),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: _MenuItemRow(icon: icon, label: label, danger: danger),
      ),
    );
  }
}

class _MenuItemRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool danger;

  const _MenuItemRow({
    required this.icon,
    required this.label,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.danger : AppColors.text;
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: (danger ? AppColors.danger : AppColors.primary).withValues(
              alpha: 0.08,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 9),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _MiniTag extends StatelessWidget {
  final Tag tag;
  const _MiniTag({required this.tag});
  @override
  Widget build(BuildContext context) {
    final fg = TagPalette.textColor(tag.colorKey);
    final bg = TagPalette.bgColor(tag.colorKey);
    final scheme = Theme.of(context).colorScheme;
    final fill = scheme.isDarkTheme
        ? Color.alphaBlend(fg.withValues(alpha: 0.16), scheme.appSurface)
        : bg.withValues(alpha: 0.55);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        tag.name,
        style: TextStyle(
          fontSize: 11,
          height: 1.1,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

class _NotesModeSegmented extends StatelessWidget {
  final _NotesViewMode value;
  final ValueChanged<_NotesViewMode> onChanged;

  const _NotesModeSegmented({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: scheme.appInput,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.appBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _modeItem(context, '日记', _NotesViewMode.diary),
          _modeItem(context, '文档', _NotesViewMode.document),
          _modeItem(context, '归纳', _NotesViewMode.analysis),
        ],
      ),
    );
  }

  Widget _modeItem(BuildContext context, String label, _NotesViewMode mode) {
    final selected = value == mode;
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => onChanged(mode),
      borderRadius: BorderRadius.circular(15),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 62,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? scheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(15),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: selected ? scheme.onPrimary : scheme.appMutedText,
          ),
        ),
      ),
    );
  }
}

class _AnalysisLibrary extends StatelessWidget {
  final List<QuickNote> notes;
  final ValueChanged<QuickNote> onOpen;

  const _AnalysisLibrary({required this.notes, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 0, 24, 100),
          child: Text(
            '还没有归纳文档，点击下方 AI 按钮开始分析未归纳的文档和有效日记',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textTertiary, fontSize: 15),
          ),
        ),
      );
    }
    final groups = <String, Map<String, List<QuickNote>>>{};
    for (final note in notes) {
      groups
          .putIfAbsent(note.category, () => {})
          .putIfAbsent(note.subcategory, () => [])
          .add(note);
    }
    final categories = groups.keys.toList()..sort();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 116),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        final subGroups = groups[category]!;
        final count = subGroups.values.fold<int>(
          0,
          (sum, list) => sum + list.length,
        );
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.72)),
            boxShadow: AppAnimations.cardShadow(),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: true,
              tilePadding: const EdgeInsets.fromLTRB(16, 6, 12, 4),
              childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              leading: _AnalysisCategoryIcon(label: category),
              title: Text(
                category,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.text,
                ),
              ),
              subtitle: Text(
                '$count 篇归纳文档',
                style: const TextStyle(
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              children: subGroups.entries.map((entry) {
                final docs = entry.value
                  ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
                return _AnalysisSubcategory(
                  title: entry.key,
                  notes: docs,
                  onOpen: onOpen,
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}

class _AnalysisCategoryIcon extends StatelessWidget {
  final String label;
  const _AnalysisCategoryIcon({required this.label});

  @override
  Widget build(BuildContext context) {
    final icons = {
      '工作': Icons.work_outline_rounded,
      '技术': Icons.code_rounded,
      '生活': Icons.home_outlined,
      '学习': Icons.school_outlined,
      '财务': Icons.savings_outlined,
      '健康': Icons.favorite_border_rounded,
      '灵感': Icons.lightbulb_outline_rounded,
      '日常': Icons.wb_sunny_outlined,
    };
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Icon(
        icons[label] ?? Icons.folder_open_rounded,
        color: AppColors.primary,
      ),
    );
  }
}

class _AnalysisSubcategory extends StatelessWidget {
  final String title;
  final List<QuickNote> notes;
  final ValueChanged<QuickNote> onOpen;

  const _AnalysisSubcategory({
    required this.title,
    required this.notes,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: BoxDecoration(
        color: AppColors.scaffoldBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.topic_outlined,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AppColors.text,
                ),
              ),
              const Spacer(),
              Text(
                '${notes.length}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...notes.map(
            (note) => _AnalysisDocTile(note: note, onTap: () => onOpen(note)),
          ),
        ],
      ),
    );
  }
}

class _AnalysisDocTile extends StatelessWidget {
  final QuickNote note;
  final VoidCallback onTap;

  const _AnalysisDocTile({required this.note, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(
                Icons.description_outlined,
                size: 19,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    note.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _plainNoteText(note.content),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              DateFormat('MM-dd').format(note.updatedAt),
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textTertiary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalyzeFab extends StatelessWidget {
  final bool loading;
  final VoidCallback onPressed;

  const _AnalyzeFab({required this.loading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.22),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: FloatingActionButton(
        onPressed: loading ? null : onPressed,
        elevation: 0,
        backgroundColor: const Color(0xFFEEF4FF),
        child: loading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.6),
              )
            : const Icon(
                Icons.auto_fix_high_rounded,
                size: 30,
                color: AppColors.primary,
              ),
      ),
    );
  }
}

class _NotesEmpty extends StatelessWidget {
  const _NotesEmpty();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        '还没有随手记',
        style: TextStyle(color: AppColors.textTertiary, fontSize: 15),
      ),
    );
  }
}

class _NoteEditorPage extends StatefulWidget {
  final QuickNote? initial;
  final String? initialText;
  final DateTime initialDate;
  final bool readOnly;
  final Future<void> Function(
    String title,
    String content,
    DateTime date,
    List<Tag> tags,
    List<NoteAttachmentDraft> attachments,
  )
  onSave;
  const _NoteEditorPage({
    this.initial,
    this.initialText,
    required this.initialDate,
    this.readOnly = false,
    required this.onSave,
  });
  @override
  State<_NoteEditorPage> createState() => _NoteEditorPageState();
}

enum _NoteInputMode { text, checklist, handwriting }

class _NoteEditorPageState extends State<_NoteEditorPage> {
  late final TextEditingController _title;
  late final TextEditingController _content;
  late DateTime _date;
  late List<Tag> _tags;
  late List<_NoteBlock> _blocks;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _blocksPreviewKey = GlobalKey();
  _NoteInputMode _mode = _NoteInputMode.text;
  bool _loadingSnapshot = false;
  late bool _editing;
  final List<List<Offset>> _strokes = [];
  List<Offset> _currentStroke = [];

  @override
  void initState() {
    super.initState();
    final parsed = _parseNoteContent(widget.initial?.content ?? '');
    _title = TextEditingController(text: widget.initial?.title ?? '');
    final initialText = widget.initial == null
        ? (widget.initialText?.trim() ?? '')
        : '';
    _content = TextEditingController(
      text: initialText.isNotEmpty ? initialText : parsed.text,
    );
    _date = widget.initial?.date ?? widget.initialDate;
    _tags = List.from(widget.initial?.tags ?? const []);
    _blocks = [...parsed.blocks];
    _editing = widget.initial == null && !widget.readOnly;
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _appendContent(String text) {
    if (!_editing || widget.readOnly) return;
    final current = _content.text.trimRight();
    _content.text = current.isEmpty ? text : '$current\n$text';
  }

  Future<void> _insertImage() async {
    if (!_editing || widget.readOnly) return;
    try {
      final files = await AppFilePicker.pickImages();
      if (files.isEmpty) return;
      if (!mounted) return;
      _appendBlocks(
        files
            .map(
              (file) => _NoteBlock(
                type: _NoteBlockType.image,
                title: file.name,
                value: file.path,
                sizeBytes: file.size,
              ),
            )
            .toList(),
      );
    } catch (e) {
      _showPickerError('图片选择失败：$e');
    }
  }

  Future<void> _insertAttachment() async {
    if (!_editing || widget.readOnly) return;
    try {
      final files = await AppFilePicker.pickFiles();
      if (files.isEmpty) return;
      if (!mounted) return;
      _appendBlocks(
        files
            .map(
              (file) => _NoteBlock(
                type: _NoteBlockType.attachment,
                title: file.name,
                value: file.path,
                sizeBytes: file.size,
              ),
            )
            .toList(),
      );
    } catch (e) {
      _showPickerError('附件选择失败：$e');
    }
  }

  void _appendBlocks(List<_NoteBlock> blocks) {
    if (blocks.isEmpty) return;
    setState(() => _blocks.addAll(blocks));
    _revealBlocksPreview();
  }

  void _revealBlocksPreview() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final previewContext = _blocksPreviewKey.currentContext;
      if (previewContext != null) {
        Scrollable.ensureVisible(
          previewContext,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: 0.82,
        );
        return;
      }
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _showPickerError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _captureWebSnapshot() async {
    if (!_editing || widget.readOnly) return;
    final controller = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('网页快照'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'https://example.com'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('抓取'),
          ),
        ],
      ),
    );
    if (url == null || url.isEmpty) return;
    setState(() => _loadingSnapshot = true);
    try {
      final uri = Uri.parse(url.startsWith('http') ? url : 'https://$url');
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 6);
      final request = await client.getUrl(uri);
      final response = await request.close();
      final html = await response.transform(utf8.decoder).join();
      client.close(force: true);
      final title =
          RegExp(
                r'<title[^>]*>(.*?)</title>',
                caseSensitive: false,
                dotAll: true,
              )
              .firstMatch(html)
              ?.group(1)
              ?.replaceAll(RegExp(r'\s+'), ' ')
              .trim() ??
          uri.host;
      final desc =
          RegExp(
            r'''<meta[^>]+name=["']description["'][^>]+content=["']([^"']*)''',
            caseSensitive: false,
          ).firstMatch(html)?.group(1)?.trim() ??
          '';
      setState(() {
        _blocks.add(
          _NoteBlock(
            type: _NoteBlockType.snapshot,
            title: title,
            value: uri.toString(),
            description: desc,
          ),
        );
      });
      if (_title.text.trim().isEmpty) _title.text = title;
    } catch (_) {
      setState(() {
        _blocks.add(
          _NoteBlock(
            type: _NoteBlockType.snapshot,
            title: url,
            value: url,
            description: '抓取失败，已保存链接。',
          ),
        );
      });
    } finally {
      if (mounted) setState(() => _loadingSnapshot = false);
    }
  }

  void _commitHandwriting() {
    if (!_editing || widget.readOnly) return;
    final count = _strokes.length + (_currentStroke.isEmpty ? 0 : 1);
    if (count == 0) return;
    _appendContent('[手写输入] $count 笔画');
    setState(() {
      _strokes.clear();
      _currentStroke = [];
      _mode = _NoteInputMode.text;
    });
  }

  Future<void> _save() async {
    if (!_editing || widget.readOnly) return;
    if (_strokes.isNotEmpty || _currentStroke.isNotEmpty) _commitHandwriting();
    final attachments = _attachmentDraftsFromBlocks(_blocks);
    final content = _serializeNoteContent(
      _content.text,
      _nonAttachmentBlocks(_blocks),
    );
    final title = _title.text.trim().isEmpty
        ? _inferNoteTitle(content, _blocks)
        : _title.text.trim();
    if (title.isEmpty && content.isEmpty && attachments.isEmpty) return;
    try {
      await widget.onSave(title, content, _date, _tags, attachments);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('保存失败：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final size = MediaQuery.sizeOf(context);
    final horizontalPadding = size.width < 430 ? 24.0 : 38.0;
    return EdgeSwipePop(
      child: Material(
        color: scheme.appPage,
        child: SafeArea(
          child: Stack(
            children: [
              SingleChildScrollView(
                controller: _scrollController,
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  14,
                  horizontalPadding,
                  _editing ? 112 : 44,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _CircleTool(
                          icon: Icons.arrow_back_ios_new_rounded,
                          onTap: () => Navigator.of(context).pop(),
                        ),
                        const Spacer(),
                        if (_editing) ...[
                          const _CircleTool(
                            icon: Icons.undo_rounded,
                            faded: true,
                          ),
                          const SizedBox(width: 10),
                          const _CircleTool(
                            icon: Icons.redo_rounded,
                            faded: true,
                          ),
                          const SizedBox(width: 10),
                          _CircleTool(
                            icon: Icons.check_rounded,
                            onTap: () => _save(),
                          ),
                        ] else if (!widget.readOnly) ...[
                          _CircleTool(
                            icon: Icons.edit_rounded,
                            onTap: () => setState(() => _editing = true),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 18),
                    if (_editing)
                      _NoteTitleField(controller: _title)
                    else
                      Text(
                        _title.text.trim().isEmpty ? '未命名随手记' : _title.text,
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: scheme.appText,
                        ),
                      ),
                    if (!_editing) ...[
                      const SizedBox(height: 8),
                      _NoteTimeSummary(
                        note: widget.initial,
                        fallbackDate: _date,
                      ),
                    ],
                    const SizedBox(height: 14),
                    if (_editing)
                      TagSelector(
                        selectedTags: _tags,
                        onChanged: (tags) => setState(() => _tags = tags),
                      )
                    else if (_tags.isNotEmpty)
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _tags
                            .map((tag) => _MiniTag(tag: tag))
                            .toList(),
                      ),
                    const SizedBox(height: 16),
                    if (!_editing)
                      _ReadOnlyNoteBody(
                        content: _serializeNoteContent(_content.text, _blocks),
                        attachmentIds:
                            widget.initial?.attachmentIds ?? const [],
                      )
                    else if (_mode == _NoteInputMode.handwriting)
                      _HandwritingPad(
                        strokes: _strokes,
                        currentStroke: _currentStroke,
                        onStart: (point) => setState(() {
                          _currentStroke = [point];
                        }),
                        onUpdate: (point) => setState(() {
                          _currentStroke = [..._currentStroke, point];
                        }),
                        onEnd: () => setState(() {
                          if (_currentStroke.isNotEmpty) {
                            _strokes.add(_currentStroke);
                            _currentStroke = [];
                          }
                        }),
                      )
                    else
                      _NoteContentField(
                        controller: _content,
                        mode: _mode,
                        blocks: _blocks,
                        blocksPreviewKey: _blocksPreviewKey,
                        onRemoveBlock: (block) =>
                            setState(() => _blocks.remove(block)),
                      ),
                    if (_blocks.isNotEmpty &&
                        _mode == _NoteInputMode.handwriting) ...[
                      const SizedBox(height: 18),
                      _NoteBlocksPreview(
                        key: _blocksPreviewKey,
                        blocks: _blocks,
                        onRemove: (block) =>
                            setState(() => _blocks.remove(block)),
                      ),
                    ],
                    if (_loadingSnapshot) ...[
                      const SizedBox(height: 16),
                      const LinearProgressIndicator(),
                    ],
                  ],
                ),
              ),
              if (_editing)
                Positioned(
                  left: horizontalPadding,
                  right: horizontalPadding,
                  bottom: 16,
                  child: _NoteEditorToolbar(
                    mode: _mode,
                    onText: () => setState(() => _mode = _NoteInputMode.text),
                    onChecklist: () {
                      setState(() => _mode = _NoteInputMode.checklist);
                      if (_content.text.trim().isEmpty) _content.text = '☐ ';
                    },
                    onHandwriting: () =>
                        setState(() => _mode = _NoteInputMode.handwriting),
                    onImage: _insertImage,
                    onAttachment: _insertAttachment,
                    onSnapshot: _captureWebSnapshot,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

Color _noteEditorFill(ColorScheme scheme) {
  return Color.alphaBlend(
    scheme.primary.withValues(alpha: scheme.isDarkTheme ? 0.035 : 0.012),
    scheme.appSurface,
  );
}

List<BoxShadow>? _noteEditorSoftShadow(ColorScheme scheme) {
  if (scheme.isDarkTheme || AppPerformance.lowLatencyMode) return null;
  return [
    BoxShadow(
      color: Colors.white.withValues(alpha: 0.72),
      blurRadius: 0,
      offset: const Offset(0, -1),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.025),
      blurRadius: 18,
      offset: const Offset(0, 8),
    ),
  ];
}

class _NoteTitleField extends StatelessWidget {
  final TextEditingController controller;

  const _NoteTitleField({required this.controller});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _noteEditorFill(scheme),
        borderRadius: BorderRadius.circular(22),
        boxShadow: _noteEditorSoftShadow(scheme),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        child: TextField(
          controller: controller,
          maxLines: 1,
          textInputAction: TextInputAction.next,
          style: TextStyle(
            fontSize: 24,
            height: 1.15,
            fontWeight: FontWeight.w800,
            color: scheme.appText,
          ),
          decoration: InputDecoration(
            hintText: '标题',
            hintStyle: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: scheme.appSubtleText.withValues(alpha: 0.72),
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            filled: false,
            fillColor: Colors.transparent,
            contentPadding: EdgeInsets.zero,
            isCollapsed: true,
          ),
        ),
      ),
    );
  }
}

class _NoteContentField extends StatelessWidget {
  final TextEditingController controller;
  final _NoteInputMode mode;
  final List<_NoteBlock> blocks;
  final Key? blocksPreviewKey;
  final ValueChanged<_NoteBlock> onRemoveBlock;

  const _NoteContentField({
    required this.controller,
    required this.mode,
    required this.blocks,
    required this.onRemoveBlock,
    this.blocksPreviewKey,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasBlocks = blocks.isNotEmpty;
    final minHeight = hasBlocks
        ? (MediaQuery.sizeOf(context).height * 0.24).clamp(170.0, 240.0)
        : (MediaQuery.sizeOf(context).height * 0.54).clamp(360.0, 560.0);
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: minHeight),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: _noteEditorFill(scheme),
        borderRadius: BorderRadius.circular(26),
        boxShadow: _noteEditorSoftShadow(scheme),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            minLines: hasBlocks ? 4 : 14,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            style: TextStyle(fontSize: 17, height: 1.68, color: scheme.appText),
            decoration: InputDecoration(
              hintText: mode == _NoteInputMode.checklist
                  ? '输入清单，一行一项...'
                  : '开始记录...',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              filled: false,
              fillColor: Colors.transparent,
              contentPadding: EdgeInsets.zero,
              isCollapsed: true,
              hintStyle: TextStyle(
                fontSize: 17,
                height: 1.68,
                color: scheme.appSubtleText.withValues(alpha: 0.76),
              ),
            ),
          ),
          if (hasBlocks) ...[
            const SizedBox(height: 16),
            _NoteBlocksPreview(
              key: blocksPreviewKey,
              blocks: blocks,
              onRemove: onRemoveBlock,
            ),
          ],
        ],
      ),
    );
  }
}

class _CircleTool extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool faded;

  const _CircleTool({required this.icon, this.onTap, this.faded = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: faded ? null : onTap,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: scheme.appInput.withValues(alpha: faded ? 0.45 : 0.95),
          shape: BoxShape.circle,
          border: Border.all(color: scheme.appBorder.withValues(alpha: 0.72)),
        ),
        child: Icon(
          icon,
          size: 23,
          color: faded ? scheme.appDisabledText : scheme.appText,
        ),
      ),
    );
  }
}

class _NoteTimeSummary extends StatelessWidget {
  final QuickNote? note;
  final DateTime fallbackDate;

  const _NoteTimeSummary({required this.note, required this.fallbackDate});

  @override
  Widget build(BuildContext context) {
    final created = note?.createdAt ?? fallbackDate;
    final updated = note?.updatedAt ?? fallbackDate;
    return Wrap(
      spacing: 14,
      runSpacing: 4,
      children: [
        _TimeText(
          label: '创建 ${DateFormat('yyyy-MM-dd HH:mm').format(created)}',
        ),
        _TimeText(
          label: '更新 ${DateFormat('yyyy-MM-dd HH:mm').format(updated)}',
        ),
      ],
    );
  }
}

class _TimeText extends StatelessWidget {
  final String label;

  const _TimeText({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        height: 1.2,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    );
  }
}

class _ReadOnlyNoteBody extends ConsumerWidget {
  final String content;
  final List<String> attachmentIds;

  const _ReadOnlyNoteBody({
    required this.content,
    this.attachmentIds = const [],
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parsed = _parseNoteContent(content);
    final markdown = _normalizeNoteMarkdown(parsed.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (markdown.trim().isNotEmpty)
          MarkdownBody(
            data: markdown,
            selectable: true,
            onTapLink: (text, href, title) {
              if (href != null && href.trim().isNotEmpty) {
                _openUrl(href);
              }
            },
            styleSheet: _noteMarkdownStyle(context),
          ),
        if (parsed.blocks.isNotEmpty) ...[
          if (markdown.trim().isNotEmpty) const SizedBox(height: 18),
          _NoteBlocksPreview(blocks: parsed.blocks),
        ],
        if (attachmentIds.isNotEmpty) ...[
          if (markdown.trim().isNotEmpty || parsed.blocks.isNotEmpty)
            const SizedBox(height: 18),
          _AttachmentIdsPreview(attachmentIds: attachmentIds),
        ],
      ],
    );
  }
}

class _AttachmentIdsPreview extends ConsumerWidget {
  final List<String> attachmentIds;

  const _AttachmentIdsPreview({required this.attachmentIds});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<AppAttachment>>(
      future: _loadAttachments(ref, attachmentIds),
      builder: (context, snapshot) {
        final attachments = snapshot.data ?? const <AppAttachment>[];
        if (attachments.isEmpty) return const SizedBox.shrink();
        return Column(
          children: attachments
              .map(
                (attachment) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _AttachmentRecordCard(attachment: attachment),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Future<List<AppAttachment>> _loadAttachments(
    WidgetRef ref,
    List<String> ids,
  ) async {
    final datasource = ref.read(datasourceProvider);
    final result = <AppAttachment>[];
    for (final id in ids) {
      final attachment = await datasource.getAttachmentById(id);
      if (attachment != null && !attachment.isDeleted) result.add(attachment);
    }
    return result;
  }
}

String _normalizeNoteMarkdown(String text) {
  return text
      .split('\n')
      .map((line) {
        final trimmed = line.trimLeft();
        final indent = line.substring(0, line.length - trimmed.length);
        if (trimmed.startsWith('☐ ')) {
          return '$indent- [ ] ${trimmed.substring(2).trimLeft()}';
        }
        if (trimmed.startsWith('☑ ')) {
          return '$indent- [x] ${trimmed.substring(2).trimLeft()}';
        }
        return line;
      })
      .join('\n');
}

MarkdownStyleSheet _noteMarkdownStyle(BuildContext context) {
  const mono = ['SF Mono', 'Menlo', 'Monaco', 'Consolas', 'monospace'];
  return MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
    p: const TextStyle(fontSize: 17, height: 1.68, color: AppColors.text),
    blockSpacing: 12,
    h1: const TextStyle(
      fontSize: 26,
      height: 1.35,
      fontWeight: FontWeight.w900,
      color: AppColors.text,
    ),
    h2: const TextStyle(
      fontSize: 22,
      height: 1.38,
      fontWeight: FontWeight.w900,
      color: AppColors.text,
    ),
    h3: const TextStyle(
      fontSize: 19,
      height: 1.42,
      fontWeight: FontWeight.w800,
      color: AppColors.text,
    ),
    h1Padding: const EdgeInsets.only(top: 10, bottom: 8),
    h2Padding: const EdgeInsets.only(top: 14, bottom: 6),
    h3Padding: const EdgeInsets.only(top: 12, bottom: 4),
    strong: const TextStyle(fontWeight: FontWeight.w900),
    em: const TextStyle(fontStyle: FontStyle.italic),
    blockquote: const TextStyle(
      fontSize: 16,
      height: 1.6,
      color: AppColors.textSecondary,
    ),
    blockquotePadding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
    blockquoteDecoration: BoxDecoration(
      color: const Color(0xFFF7FAFF),
      borderRadius: BorderRadius.circular(12),
      border: Border(
        left: BorderSide(
          color: AppColors.primary.withValues(alpha: 0.45),
          width: 4,
        ),
      ),
    ),
    code: const TextStyle(
      fontFamilyFallback: mono,
      fontSize: 14,
      height: 1.5,
      color: Color(0xFF185A9D),
      backgroundColor: Color(0xFFEFF4FA),
    ),
    codeblockPadding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
    codeblockDecoration: BoxDecoration(
      color: const Color(0xFFF6F8FB),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFDDE4EE)),
    ),
    listBullet: const TextStyle(
      fontSize: 17,
      height: 1.55,
      color: AppColors.text,
    ),
    checkbox: const TextStyle(fontSize: 17, color: AppColors.primary),
    tableHead: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w900,
      color: AppColors.text,
    ),
    tableBody: const TextStyle(
      fontSize: 14,
      height: 1.45,
      color: AppColors.textSecondary,
    ),
    tableBorder: TableBorder.all(color: AppColors.border, width: 1),
    tableCellsPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    horizontalRuleDecoration: const BoxDecoration(
      border: Border(top: BorderSide(color: AppColors.border)),
    ),
  );
}

class _NoteBlocksPreview extends StatelessWidget {
  final List<_NoteBlock> blocks;
  final ValueChanged<_NoteBlock>? onRemove;

  const _NoteBlocksPreview({super.key, required this.blocks, this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: blocks
          .map(
            (block) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _NoteBlockCard(block: block, onRemove: onRemove),
            ),
          )
          .toList(),
    );
  }
}

class _NoteBlockCard extends StatelessWidget {
  final _NoteBlock block;
  final ValueChanged<_NoteBlock>? onRemove;

  const _NoteBlockCard({required this.block, this.onRemove});

  @override
  Widget build(BuildContext context) {
    switch (block.type) {
      case _NoteBlockType.image:
        return _ImageBlockCard(block: block, onRemove: onRemove);
      case _NoteBlockType.attachment:
        return _AttachmentBlockCard(block: block, onRemove: onRemove);
      case _NoteBlockType.snapshot:
        return _SnapshotBlockCard(block: block, onRemove: onRemove);
    }
  }
}

class _AttachmentRecordCard extends StatelessWidget {
  final AppAttachment attachment;

  const _AttachmentRecordCard({required this.attachment});

  @override
  Widget build(BuildContext context) {
    if (attachment.attachmentType == 'image') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            Container(
              constraints: const BoxConstraints(maxHeight: 360),
              width: double.infinity,
              color: AppColors.inputBg,
              child: Image.memory(
                base64Decode(attachment.contentBase64),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => _BrokenBlock(
                  icon: Icons.broken_image_outlined,
                  title: attachment.fileName,
                  subtitle: '图片无法读取',
                ),
              ),
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: () => _openAttachmentRecord(attachment),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: AppColors.inputBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                attachment.attachmentType == 'audio'
                    ? Icons.graphic_eq_rounded
                    : Icons.attach_file_rounded,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    attachment.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_formatAttachmentSize(attachment.sizeBytes)} · 点击打开附件',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatAttachmentSize(int size) {
  if (size >= 1024 * 1024) {
    return '${(size / 1024 / 1024).toStringAsFixed(1)} MB';
  }
  if (size >= 1024) {
    return '${(size / 1024).toStringAsFixed(1)} KB';
  }
  return '$size B';
}

class _ImageBlockCard extends StatelessWidget {
  final _NoteBlock block;
  final ValueChanged<_NoteBlock>? onRemove;

  const _ImageBlockCard({required this.block, this.onRemove});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () => _openFile(block.value),
        child: Stack(
          children: [
            Container(
              constraints: const BoxConstraints(maxHeight: 360),
              width: double.infinity,
              color: AppColors.inputBg,
              child: Image.file(
                File(block.value),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => _BrokenBlock(
                  icon: Icons.broken_image_outlined,
                  title: block.title,
                  subtitle: '图片无法读取',
                ),
              ),
            ),
            if (onRemove != null)
              _RemoveBlockButton(onTap: () => onRemove!(block)),
          ],
        ),
      ),
    );
  }
}

class _AttachmentBlockCard extends StatelessWidget {
  final _NoteBlock block;
  final ValueChanged<_NoteBlock>? onRemove;

  const _AttachmentBlockCard({required this.block, this.onRemove});

  @override
  Widget build(BuildContext context) {
    final type = _attachmentTypeForFileName(block.title);
    final subtitle = block.sizeBytes == null
        ? '点击打开附件'
        : '${_formatAttachmentSize(block.sizeBytes!)} · 点击打开附件';
    return Stack(
      children: [
        InkWell(
          onTap: () => _openFile(block.value),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 48, 14),
            decoration: BoxDecoration(
              color: AppColors.inputBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    type == 'audio'
                        ? Icons.graphic_eq_rounded
                        : Icons.attach_file_rounded,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        block.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (onRemove != null) _RemoveBlockButton(onTap: () => onRemove!(block)),
      ],
    );
  }
}

class _SnapshotBlockCard extends StatelessWidget {
  final _NoteBlock block;
  final ValueChanged<_NoteBlock>? onRemove;

  const _SnapshotBlockCard({required this.block, this.onRemove});

  @override
  Widget build(BuildContext context) {
    final host = Uri.tryParse(block.value)?.host ?? block.value;
    return Stack(
      children: [
        InkWell(
          onTap: () => _openUrl(block.value),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 16, 48, 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F7FF),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.16),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(
                    Icons.language_rounded,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        block.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.25,
                          fontWeight: FontWeight.w900,
                          color: AppColors.text,
                        ),
                      ),
                      if ((block.description ?? '').isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          block.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.35,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        host,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (onRemove != null) _RemoveBlockButton(onTap: () => onRemove!(block)),
      ],
    );
  }
}

class _RemoveBlockButton extends StatelessWidget {
  final VoidCallback onTap;

  const _RemoveBlockButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 8,
      right: 8,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.close_rounded,
            size: 17,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _BrokenBlock extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _BrokenBlock({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Icon(icon, size: 34, color: AppColors.textTertiary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteEditorToolbar extends StatelessWidget {
  final _NoteInputMode mode;
  final VoidCallback onText;
  final VoidCallback onChecklist;
  final VoidCallback onHandwriting;
  final VoidCallback onImage;
  final VoidCallback onAttachment;
  final VoidCallback onSnapshot;

  const _NoteEditorToolbar({
    required this.mode,
    required this.onText,
    required this.onChecklist,
    required this.onHandwriting,
    required this.onImage,
    required this.onAttachment,
    required this.onSnapshot,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reduceMotion = AppPerformance.shouldReduceMotion(context);
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 58,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: scheme.appElevatedSurface.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(29),
              border: Border.all(
                color: scheme.appBorder.withValues(alpha: 0.72),
              ),
              boxShadow: reduceMotion
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ToolIcon(
                  icon: Icons.text_fields_rounded,
                  selected: mode == _NoteInputMode.text,
                  onTap: onText,
                ),
                _ToolIcon(
                  icon: Icons.check_circle_outline_rounded,
                  selected: mode == _NoteInputMode.checklist,
                  onTap: onChecklist,
                ),
                _ToolIcon(
                  icon: Icons.draw_rounded,
                  selected: mode == _NoteInputMode.handwriting,
                  onTap: onHandwriting,
                ),
                _ToolIcon(icon: Icons.image_outlined, onTap: onImage),
                _ToolIcon(icon: Icons.attach_file_rounded, onTap: onAttachment),
                _ToolIcon(icon: Icons.article_outlined, onTap: onSnapshot),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ToolIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool selected;

  const _ToolIcon({
    required this.icon,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 34,
        height: 44,
        child: Center(
          child: Icon(
            icon,
            size: 26,
            color: selected ? scheme.primary : scheme.appText,
          ),
        ),
      ),
    );
  }
}

class _HandwritingPad extends StatelessWidget {
  final List<List<Offset>> strokes;
  final List<Offset> currentStroke;
  final ValueChanged<Offset> onStart;
  final ValueChanged<Offset> onUpdate;
  final VoidCallback onEnd;

  const _HandwritingPad({
    required this.strokes,
    required this.currentStroke,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 460,
      decoration: BoxDecoration(
        color: AppColors.inputBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: GestureDetector(
        onPanStart: (details) => onStart(details.localPosition),
        onPanUpdate: (details) => onUpdate(details.localPosition),
        onPanEnd: (_) => onEnd(),
        child: CustomPaint(
          painter: _HandwritingPainter(strokes, currentStroke),
          child: const SizedBox.expand(
            child: Center(
              child: Text(
                '在这里手写',
                style: TextStyle(color: AppColors.textTertiary),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HandwritingPainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final List<Offset> currentStroke;

  const _HandwritingPainter(this.strokes, this.currentStroke);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.text
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final stroke in [...strokes, currentStroke]) {
      if (stroke.length < 2) continue;
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (final point in stroke.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _HandwritingPainter oldDelegate) {
    return oldDelegate.strokes != strokes ||
        oldDelegate.currentStroke != currentStroke;
  }
}

PageRoute<T> _notesSideRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      );
    },
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 240),
  );
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
