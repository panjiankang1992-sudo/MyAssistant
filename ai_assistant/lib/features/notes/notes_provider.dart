import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/app_attachment.dart';
import '../../domain/models/quick_note.dart';
import '../../domain/models/tag.dart';
import '../../core/providers/core_providers.dart';
import '../ai_settings/ai_model_provider.dart';
import '../skills/note_analysis_skill.dart';
import '../sync/data_sync_service.dart';
import 'notes_store.dart';

final notesStoreProvider = Provider<NotesStore>(
  (ref) =>
      NotesStore(ref.watch(databaseProvider), ref.watch(datasourceProvider)),
);

final notesNotifierProvider = NotifierProvider<NotesNotifier, List<QuickNote>>(
  NotesNotifier.new,
);

class NoteAttachmentDraft {
  final String path;
  final String fileName;
  final String attachmentType;
  final String? mimeType;

  const NoteAttachmentDraft({
    required this.path,
    required this.fileName,
    required this.attachmentType,
    this.mimeType,
  });
}

class NotesNotifier extends Notifier<List<QuickNote>> {
  @override
  List<QuickNote> build() {
    Future.microtask(load);
    return const [];
  }

  Future<void> load() async {
    final loaded = await ref.read(notesStoreProvider).load();
    var changed = false;
    final notes = [
      for (final note in loaded)
        if (note.summary.trim().isEmpty && note.content.trim().isNotEmpty)
          () {
            changed = true;
            return note.copyWith(
              summary: _summaryOf(note.content),
              category: !note.isAnalysis && note.noteType == QuickNoteType.diary
                  ? '日记'
                  : note.category,
            );
          }()
        else
          note,
    ];
    state = notes;
    if (changed) {
      await ref.read(notesStoreProvider).save(notes);
    }
  }

  Future<void> _persist(List<QuickNote> notes) async {
    state = notes..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await ref.read(notesStoreProvider).save(state);
  }

  Future<void> upsert({
    QuickNote? initial,
    required String title,
    required String content,
    required DateTime date,
    required List<Tag> tags,
    List<NoteAttachmentDraft> attachments = const [],
    QuickNoteType? noteType,
  }) async {
    final now = DateTime.now();
    final noteId = initial?.id ?? const Uuid().v4();
    final inferredType =
        initial?.noteType ??
        noteType ??
        (looksLikeDiaryTitle(title)
            ? QuickNoteType.diary
            : QuickNoteType.document);
    final attachmentIds = [...?initial?.attachmentIds];
    for (final draft in attachments) {
      final file = File(draft.path);
      if (!await file.exists()) continue;
      final sizeBytes = await file.length();
      if (sizeBytes > AppAttachment.maxSizeBytes) {
        throw ArgumentError(
          '附件不能超过 ${AppAttachment.maxSizeLabel}：${draft.fileName}',
        );
      }
      final bytes = await file.readAsBytes();
      final attachment = AppAttachment(
        id: const Uuid().v4(),
        ownerType: initial?.archived == true
            ? 'archive'
            : inferredType == QuickNoteType.diary
            ? 'diary'
            : 'note',
        ownerId: noteId,
        attachmentType: draft.attachmentType,
        fileName: draft.fileName,
        mimeType: draft.mimeType,
        sizeBytes: bytes.length,
        contentBase64: base64Encode(bytes),
        createdAt: now,
        updatedAt: now,
      );
      await ref.read(datasourceProvider).upsertAttachment(attachment);
      attachmentIds.add(attachment.id);
    }
    final note =
        (initial ??
                QuickNote(
                  id: noteId,
                  title: title,
                  content: content,
                  summary: _summaryOf(content),
                  date: DateTime(date.year, date.month, date.day),
                  createdAt: now,
                  updatedAt: now,
                  noteType: inferredType,
                ))
            .copyWith(
              title: title,
              content: content,
              summary: initial?.isAnalysis == true
                  ? (initial!.summary.isEmpty
                        ? _summaryOf(content)
                        : initial.summary)
                  : _summaryOf(content),
              tags: tags,
              date: DateTime(date.year, date.month, date.day),
              updatedAt: now,
              analyzed: initial?.isAnalysis == true ? true : false,
              noteType: inferredType,
              category: initial?.isAnalysis == true
                  ? initial!.category
                  : inferredType == QuickNoteType.diary
                  ? '日记'
                  : _inferCategory(title, content, tags),
              attachmentIds: attachmentIds,
            );
    final next = [
      for (final item in state)
        if (item.id == note.id) note else item,
    ];
    if (!next.any((e) => e.id == note.id)) next.add(note);
    await _persist(next);
    await ref
        .read(dataSyncServiceProvider)
        .markDirty(
          DataSyncType.note,
          note.id,
          operation: 'upsert',
          payload: {
            'title': note.title,
            'updatedAt': note.updatedAt.toIso8601String(),
          },
        );
  }

  Future<int> analyzePendingNotes() async {
    final existingAnalysisDocs = state
        .where((note) => !note.deleted && !note.archived && note.isAnalysis)
        .toList();
    final analyzedSourceIds = state
        .where((note) => note.isAnalysis && !note.deleted)
        .expand((note) => note.sourceNoteIds)
        .toSet();
    final results = await NoteAnalysisSkill().run(
      notes: state,
      existingAnalysisDocs: existingAnalysisDocs,
      analyzedSourceIds: analyzedSourceIds,
      config: ref.read(aiModelProvider).selected,
    );
    if (results.isEmpty) return 0;
    final next = [...state];
    var created = 0;
    for (final result in results) {
      final analysis = result.analysisDocument;
      final existingIndex = next.indexWhere((item) => item.id == analysis.id);
      if (existingIndex >= 0) {
        next[existingIndex] = analysis.copyWith(
          createdAt: next[existingIndex].createdAt,
        );
      } else {
        next.add(analysis);
        created++;
      }
      for (final sourceNote in result.sourceNotes) {
        final rawIndex = next.indexWhere((item) => item.id == sourceNote.id);
        if (rawIndex >= 0) {
          next[rawIndex] = next[rawIndex].copyWith(
            analyzed: true,
            updatedAt: DateTime.now(),
          );
        }
      }
    }

    await _persist(next);
    await ref
        .read(dataSyncServiceProvider)
        .markDirty(
          DataSyncType.note,
          'analysis-${DateTime.now().millisecondsSinceEpoch}',
          operation: 'analyze',
          payload: {'count': results.length, 'skill': 'note_archive_analysis'},
        );
    return created == 0 ? results.length : created;
  }

  Future<void> archive(QuickNote note) async {
    final now = DateTime.now();
    await _persist([
      for (final item in state)
        if (item.id == note.id)
          item.copyWith(archived: true, updatedAt: now)
        else
          item,
    ]);
    for (final attachmentId in note.attachmentIds) {
      final attachment = await ref
          .read(datasourceProvider)
          .getAttachmentById(attachmentId);
      if (attachment == null) continue;
      await ref
          .read(datasourceProvider)
          .upsertAttachment(
            AppAttachment(
              id: attachment.id,
              ownerType: 'archive',
              ownerId: note.id,
              attachmentType: attachment.attachmentType,
              fileName: attachment.fileName,
              mimeType: attachment.mimeType,
              sizeBytes: attachment.sizeBytes,
              contentBase64: attachment.contentBase64,
              createdAt: attachment.createdAt,
              updatedAt: now,
              isDeleted: attachment.isDeleted,
            ),
          );
    }
    await ref
        .read(dataSyncServiceProvider)
        .markDirty(DataSyncType.note, note.id, operation: 'archive');
  }

  Future<void> togglePinned(QuickNote note) async {
    final nextPinned = !note.pinned;
    await _persist([
      for (final item in state)
        if (item.id == note.id)
          item.copyWith(pinned: nextPinned, updatedAt: DateTime.now())
        else
          item,
    ]);
    await ref
        .read(dataSyncServiceProvider)
        .markDirty(
          DataSyncType.note,
          note.id,
          operation: nextPinned ? 'pin' : 'unpin',
        );
  }

  Future<void> delete(QuickNote note) async {
    await _persist([
      for (final item in state)
        if (item.id == note.id)
          item.copyWith(deleted: true, updatedAt: DateTime.now())
        else
          item,
    ]);
    await ref
        .read(dataSyncServiceProvider)
        .markDirty(DataSyncType.note, note.id, operation: 'delete');
  }

  String _inferCategory(String title, String content, List<Tag> tags) {
    if (tags.isNotEmpty) return tags.first.name;
    final text = '$title $content';
    if (RegExp(
      'Flutter|AI|LLM|接口|代码|部署|GitHub|bug',
      caseSensitive: false,
    ).hasMatch(text)) {
      return '技术';
    }
    if (text.contains('买') || text.contains('购物') || text.contains('清单')) {
      return '生活';
    }
    if (text.contains('会议') || text.contains('项目') || text.contains('工作')) {
      return '工作';
    }
    if (text.contains('钱') || text.contains('账') || text.contains('发票')) {
      return '账单';
    }
    if (text.contains('学') || text.contains('读') || text.contains('课程')) {
      return '学习';
    }
    return '灵感';
  }

  String _summaryOf(String content) {
    final text = content.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isEmpty) return '';
    return text.length > 120 ? '${text.substring(0, 120)}...' : text;
  }
}
