import 'dart:convert';

import 'package:drift/drift.dart' show Value;

import '../../core/database/database.dart' hide QuickNote;
import '../../data/datasources/local_datasource.dart';
import '../../domain/models/quick_note.dart';

class NotesStore {
  final AppDatabase _db;

  NotesStore(this._db);

  Future<List<QuickNote>> load() async {
    final rows = await _db.select(_db.quickNotes).get();
    return rows
        .map(
          (row) => QuickNote.fromJson({
            'id': row.id,
            'title': row.title,
            'content': row.content,
            'summary': row.summary,
            'tags': jsonDecode(row.tags),
            'date': row.date.toIso8601String(),
            'createdAt': row.createdAt.toIso8601String(),
            'updatedAt': row.updatedAt.toIso8601String(),
            'archived': row.archived,
            'deleted': row.isDeleted,
            'pinned': row.pinned,
            'analyzed': row.analyzed,
            'isAnalysis': row.isAnalysis,
            'noteType': row.noteType,
            'category': row.category,
            'subcategory': row.subcategory,
            'sourceNoteIds': jsonDecode(row.sourceNoteIds),
            'attachmentIds': jsonDecode(row.attachmentIds),
          }),
        )
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<void> save(List<QuickNote> notes) async {
    final incomingIds = notes.map((note) => note.id).toSet();
    final existing = await _db.select(_db.quickNotes).get();
    for (final note in notes) {
      await _db
          .into(_db.quickNotes)
          .insertOnConflictUpdate(
            QuickNotesCompanion(
              id: Value(note.id),
              title: Value(note.title),
              content: Value(note.content),
              summary: Value(note.summary),
              tags: Value(LocalDatasource.encodeTags(note.tags)),
              date: Value(note.date),
              createdAt: Value(note.createdAt),
              updatedAt: Value(note.updatedAt),
              archived: Value(note.archived),
              pinned: Value(note.pinned),
              analyzed: Value(note.analyzed),
              isAnalysis: Value(note.isAnalysis),
              noteType: Value(note.noteType.value),
              category: Value(note.category),
              subcategory: Value(note.subcategory),
              sourceNoteIds: Value(jsonEncode(note.sourceNoteIds)),
              attachmentIds: Value(jsonEncode(note.attachmentIds)),
              version: Value(
                (existing
                            .where((row) => row.id == note.id)
                            .firstOrNull
                            ?.version ??
                        0) +
                    1,
              ),
              isDeleted: Value(note.deleted),
            ),
          );
    }
    for (final row in existing) {
      if (!incomingIds.contains(row.id) && !row.isDeleted) {
        await (_db.update(
          _db.quickNotes,
        )..where((t) => t.id.equals(row.id))).write(
          QuickNotesCompanion(
            updatedAt: Value(DateTime.now()),
            version: Value(row.version + 1),
            isDeleted: const Value(true),
          ),
        );
      }
    }
  }
}
