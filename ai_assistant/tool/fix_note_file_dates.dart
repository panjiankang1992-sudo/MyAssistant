import 'dart:convert';
import 'dart:io';

void main(List<String> args) async {
  final notesFile = File(args.isNotEmpty ? args[0] : '');
  if (!await notesFile.exists()) {
    stderr.writeln('Notes file does not exist: ${notesFile.path}');
    exit(1);
  }

  final text = await notesFile.readAsString();
  final items = (jsonDecode(text) as List)
      .whereType<Map>()
      .map((item) => item.cast<String, dynamic>())
      .toList();
  final backup = File(
    '${notesFile.path}.bak-${DateTime.now().millisecondsSinceEpoch}',
  );
  await backup.writeAsString(text);

  var changed = 0;
  for (final item in items) {
    final filename = _filenameCandidate(item);
    final before =
        '${item['date']}|${item['createdAt']}|${item['updatedAt']}|${item['noteType']}|${item['category']}';
    final date = filename == null ? null : _dateFromFilename(filename);
    if (date != null) {
      final iso = DateTime(date.year, date.month, date.day).toIso8601String();
      item
        ..['date'] = iso
        ..['createdAt'] = iso
        ..['updatedAt'] = iso
        ..['noteType'] = 'diary'
        ..['category'] = '日记';
    } else if (item['isAnalysis'] != true && item['noteType'] == null) {
      item['noteType'] = 'document';
    }
    final after =
        '${item['date']}|${item['createdAt']}|${item['updatedAt']}|${item['noteType']}|${item['category']}';
    if (before != after) changed++;
  }

  items.sort((a, b) => '${b['updatedAt']}'.compareTo('${a['updatedAt']}'));
  await notesFile.writeAsString(
    const JsonEncoder.withIndent('  ').convert(items),
  );
  stdout.writeln('Updated $changed notes by filename date.');
  stdout.writeln('Backup: ${backup.path}');
}

String? _filenameCandidate(Map<String, dynamic> item) {
  final candidates = <String>[];
  for (final key in ['title', 'sourcePath', 'filePath', 'path', 'name']) {
    final value = item[key];
    if (value is String && value.trim().isNotEmpty) candidates.add(value);
  }

  final id = item['id'] as String? ?? '';
  if (id.startsWith('mydoc-')) {
    final relative = _decodeMydocId(id);
    if (relative != null) candidates.add(relative);
  }

  for (final candidate in candidates) {
    final filename = candidate
        .split(RegExp(r'[/\\]'))
        .last
        .replaceFirst(
          RegExp(r'\.(md|txt|markdown)$', caseSensitive: false),
          '',
        );
    if (_dateFromFilename(filename) != null) return filename;
  }
  return null;
}

String? _decodeMydocId(String id) {
  final encoded = id.substring('mydoc-'.length);
  try {
    final padded = encoded.padRight(
      encoded.length + (4 - encoded.length % 4) % 4,
      '=',
    );
    return utf8.decode(base64Url.decode(padded));
  } catch (_) {
    return null;
  }
}

DateTime? _dateFromFilename(String filename) {
  final patterns = [
    RegExp(r'(^|[^\d])(\d{4})[-_\.年](\d{1,2})[-_\.月](\d{1,2})(日)?([^\d]|$)'),
    RegExp(r'(^|[^\d])(\d{4})(\d{2})(\d{2})([^\d]|$)'),
  ];
  for (final pattern in patterns) {
    final match = pattern.firstMatch(filename);
    if (match == null) continue;
    final year = int.tryParse(match.group(2) ?? '');
    final month = int.tryParse(match.group(3) ?? '');
    final day = int.tryParse(match.group(4) ?? '');
    if (year == null || month == null || day == null) continue;
    if (month < 1 || month > 12 || day < 1 || day > 31) continue;
    return DateTime(year, month, day);
  }
  return null;
}
