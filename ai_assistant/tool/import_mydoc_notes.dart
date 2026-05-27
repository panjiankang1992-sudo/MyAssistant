import 'dart:convert';
import 'dart:io';

void main(List<String> args) async {
  final sourceDir = Directory(args.isNotEmpty ? args[0] : '');
  final notesFile = File(args.length > 1 ? args[1] : '');
  if (!await sourceDir.exists()) {
    stderr.writeln('Source directory does not exist: ${sourceDir.path}');
    exit(1);
  }
  if (!await notesFile.parent.exists()) {
    await notesFile.parent.create(recursive: true);
  }

  final existing = await _readNotes(notesFile);
  final byId = {
    for (final note in existing)
      if (note['id'] is String) note['id'] as String: note,
  };
  final files = await sourceDir
      .list(recursive: true, followLinks: false)
      .where((entity) {
        if (entity is! File) return false;
        final path = entity.path;
        if (path.contains('/.obsidian/') || path.contains('/.git/')) {
          return false;
        }
        return path.endsWith('.md') || path.endsWith('.txt');
      })
      .cast<File>()
      .toList();

  var imported = 0;
  for (final file in files) {
    final relative = file.path.substring(sourceDir.path.length + 1);
    final id =
        'mydoc-${base64Url.encode(utf8.encode(relative)).replaceAll('=', '')}';
    if (byId.containsKey(id)) continue;
    final text = await file.readAsString();
    final parsed = _parseMarkdown(text, relative);
    final stat = await file.stat();
    final date = parsed.date ?? stat.modified;
    final now = DateTime.now();
    byId[id] = {
      'id': id,
      'title': parsed.title,
      'content': parsed.content,
      'summary': _summary(parsed.content),
      'tags': parsed.tags.map((name) => _tag(name, now)).toList(),
      'date': DateTime(date.year, date.month, date.day).toIso8601String(),
      'createdAt': date.toIso8601String(),
      'updatedAt': now.toIso8601String(),
      'archived': false,
      'deleted': false,
      'analyzed': false,
      'isAnalysis': false,
      'category': _category(relative, parsed.content),
      'subcategory': 'MyDoc',
      'sourceNoteIds': <String>[],
    };
    imported++;
  }

  final output = byId.values.toList()
    ..sort((a, b) => '${b['updatedAt']}'.compareTo('${a['updatedAt']}'));
  await notesFile.writeAsString(
    const JsonEncoder.withIndent('  ').convert(output),
  );
  stdout.writeln('Imported $imported new notes from ${files.length} files.');
  stdout.writeln('Notes file: ${notesFile.path}');
}

Future<List<Map<String, dynamic>>> _readNotes(File file) async {
  if (!await file.exists()) return [];
  final text = await file.readAsString();
  if (text.trim().isEmpty) return [];
  final decoded = jsonDecode(text);
  return (decoded as List)
      .whereType<Map>()
      .map((e) => e.cast<String, dynamic>())
      .toList();
}

_ParsedDoc _parseMarkdown(String raw, String relative) {
  var content = raw.replaceAll('\r\n', '\n').trim();
  final tags = <String>{'MyDoc'};
  DateTime? date;
  if (content.startsWith('---')) {
    final end = content.indexOf('\n---', 3);
    if (end > 0) {
      final frontmatter = content.substring(3, end).trim();
      content = content.substring(end + 4).trim();
      for (final line in frontmatter.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.startsWith('tags:')) {
          final tagText = trimmed
              .substring(5)
              .replaceAll('[', '')
              .replaceAll(']', '');
          tags.addAll(
            tagText.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty),
          );
        }
        if (trimmed.startsWith('created:')) {
          date = DateTime.tryParse(trimmed.substring(8).trim());
        }
      }
    }
  }
  final titleLine = content
      .split('\n')
      .map((line) => line.trim())
      .firstWhere((line) => line.startsWith('# '), orElse: () => '');
  final fallback = relative
      .split('/')
      .last
      .replaceAll(RegExp(r'\.(md|txt)$'), '');
  final title = titleLine.isEmpty
      ? fallback
      : titleLine.replaceFirst('# ', '').trim();
  final folderParts = relative.split('/');
  if (folderParts.length > 1) tags.add(folderParts.first);
  if (folderParts.length > 2) tags.add(folderParts[1]);
  return _ParsedDoc(
    title: title,
    content: content,
    tags: tags.take(6).toList(),
    date: date,
  );
}

Map<String, dynamic> _tag(String name, DateTime now) {
  final id =
      'import-${base64Url.encode(utf8.encode(name)).replaceAll('=', '')}';
  return {
    'id': id,
    'name': name,
    'colorKey': 'blue',
    'sortOrder': 0,
    'isPreset': false,
    'createdAt': now.toIso8601String(),
    'updatedAt': now.toIso8601String(),
  };
}

String _summary(String content) {
  final text = content
      .replaceAll(RegExp(r'---[\s\S]*?---'), '')
      .replaceAll(RegExp(r'[#>*`\[\]]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (text.length <= 160) return text;
  return '${text.substring(0, 160)}...';
}

String _category(String relative, String content) {
  final text = '$relative $content';
  if (RegExp(
    'Flutter|AI|LLM|代码|部署|GitHub|MySQL|MCP|API',
    caseSensitive: false,
  ).hasMatch(text)) {
    return '技术';
  }
  if (RegExp('项目|需求|方案|工作|会议').hasMatch(text)) return '工作';
  if (RegExp('旅游|孩子|家|生活|南京|购物|医院').hasMatch(text)) return '生活';
  return '日常';
}

class _ParsedDoc {
  final String title;
  final String content;
  final List<String> tags;
  final DateTime? date;

  const _ParsedDoc({
    required this.title,
    required this.content,
    required this.tags,
    required this.date,
  });
}
