import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../domain/models/quick_note.dart';

class NotesStore {
  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    final notesDir = Directory('${dir.path}/notes');
    if (!await notesDir.exists()) await notesDir.create(recursive: true);
    return File('${notesDir.path}/quick_notes.json');
  }

  Future<List<QuickNote>> load() async {
    final file = await _file();
    if (!await file.exists()) return _seed();
    final text = await file.readAsString();
    if (text.trim().isEmpty) return const [];
    final data = (jsonDecode(text) as List).whereType<Map>().toList();
    return data
        .map((e) => QuickNote.fromJson(e.cast<String, dynamic>()))
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<void> save(List<QuickNote> notes) async {
    final file = await _file();
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(
      encoder.convert(notes.map((e) => e.toJson()).toList()),
    );
  }

  List<QuickNote> _seed() {
    final now = DateTime.now();
    return [
      QuickNote(
        id: 'seed-note-1',
        title: '今天的灵感',
        content: '把随手想法先快速记下来，晚上再整理成待办或文档。',
        date: DateTime(now.year, now.month, now.day),
        createdAt: now.subtract(const Duration(hours: 2)),
        updatedAt: now.subtract(const Duration(hours: 2)),
        category: '灵感',
      ),
      QuickNote(
        id: 'seed-note-2',
        title: '购物清单',
        content: '牛奶、咖啡豆、洗衣液，顺便看看周末要不要补猫粮。',
        date: DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 1)),
        createdAt: now.subtract(const Duration(days: 1, hours: 3)),
        updatedAt: now.subtract(const Duration(days: 1, hours: 3)),
        category: '生活',
      ),
    ];
  }
}
