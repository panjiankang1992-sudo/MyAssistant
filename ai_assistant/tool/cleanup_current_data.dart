import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  final checkOnly = args.contains('--check') || args.contains('--dry-run');
  final timestamp = DateTime.now()
      .toIso8601String()
      .replaceAll(':', '')
      .replaceAll('.', '-');
  final home = Platform.environment['HOME'];
  if (home == null || home.isEmpty) {
    stderr.writeln('HOME is not set.');
    exitCode = 1;
    return;
  }

  final containers = [
    _AppContainer(
      id: 'com.yuyutian.assistant',
      basePath: '$home/Library/Containers/com.yuyutian.assistant/Data',
    ),
    _AppContainer(
      id: 'com.example.aiAssistant',
      basePath: '$home/Library/Containers/com.example.aiAssistant/Data',
    ),
  ];

  final results = <Map<String, Object?>>[];
  for (final container in containers) {
    results.add({
      'container': container.id,
      'bookkeeping': await _clearBookkeepingEntries(
        container,
        timestamp,
        checkOnly: checkOnly,
      ),
      'todos': await _dedupeTodos(container, timestamp, checkOnly: checkOnly),
    });
  }

  stdout.writeln(const JsonEncoder.withIndent('  ').convert(results));
}

Future<Map<String, Object?>> _clearBookkeepingEntries(
  _AppContainer container,
  String timestamp, {
  required bool checkOnly,
}) async {
  final file = File(
    '${container.basePath}/Library/Application Support/${container.id}/bookkeeping/entries.json',
  );
  if (!await file.exists()) {
    return {'found': false, 'cleared': 0};
  }

  final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  final entries = data['entries'] as List<dynamic>? ?? const [];
  if (checkOnly) {
    return {
      'found': true,
      'currentEntries': entries.length,
      'wouldClear': entries.length,
    };
  }

  final backup = File('${file.path}.bak-cleanup-$timestamp');
  await file.copy(backup.path);
  await file.writeAsString(
    const JsonEncoder.withIndent('  ').convert({'entries': const []}),
  );
  return {'found': true, 'cleared': entries.length, 'backup': backup.path};
}

Future<Map<String, Object?>> _dedupeTodos(
  _AppContainer container,
  String timestamp, {
  required bool checkOnly,
}) async {
  final file = File('${container.basePath}/Documents/ai_assistant_db.sqlite');
  if (!await file.exists()) {
    return {'found': false, 'deletedDuplicates': 0};
  }

  final todos = await _readTodos(file);
  final duplicates = _duplicatesToDelete(todos);
  File? backup;
  if (!checkOnly) {
    backup = File('${file.path}.bak-cleanup-$timestamp');
    await file.copy(backup.path);
  }

  if (!checkOnly && duplicates.isNotEmpty) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final ids = duplicates.map((todo) => _sqlString(todo.id)).join(',');
    await _runSqlite(
      file.path,
      'UPDATE todos '
      'SET deleted = 1, updated_at = $now, version = version + 1 '
      'WHERE id IN ($ids);',
    );
  }

  final after = await _readTodos(file);
  return {
    'found': true,
    'totalBefore': todos.length,
    'activeBefore': todos.where((todo) => !todo.deleted).length,
    checkOnly ? 'wouldDeleteDuplicates' : 'deletedDuplicates':
        duplicates.length,
    'activeAfter': checkOnly
        ? todos.where((todo) => !todo.deleted).length - duplicates.length
        : after.where((todo) => !todo.deleted).length,
    if (backup != null) 'backup': backup.path,
    'duplicateIds': duplicates.map((todo) => todo.id).toList(),
  };
}

Future<List<_TodoRow>> _readTodos(File dbFile) async {
  final output = await _runSqlite(dbFile.path, '''
    SELECT
      id,
      title,
      description,
      source,
      routine_id AS routineId,
      time,
      date,
      completed,
      updated_at AS updatedAt,
      version,
      deleted
    FROM todos;
    ''', json: true);
  final rows = jsonDecode(output) as List<dynamic>;
  return rows.whereType<Map<String, dynamic>>().map(_TodoRow.fromJson).toList();
}

List<_TodoRow> _duplicatesToDelete(List<_TodoRow> todos) {
  final groups = <String, List<_TodoRow>>{};
  for (final todo in todos) {
    final fingerprint = _fingerprint(todo);
    if (fingerprint == null) continue;
    groups.putIfAbsent(fingerprint, () => []).add(todo);
  }

  final duplicates = <_TodoRow>[];
  for (final group in groups.values.where((items) => items.length > 1)) {
    group.sort((a, b) => _compareWinner(b, a));
    duplicates.addAll(group.skip(1).where((todo) => !todo.deleted));
  }
  return duplicates;
}

int _compareWinner(_TodoRow a, _TodoRow b) {
  if (a.completed != b.completed) {
    return a.completed ? 1 : -1;
  }

  final versionCompare = a.version.compareTo(b.version);
  if (versionCompare != 0) return versionCompare;

  final updatedCompare = a.updatedAt.compareTo(b.updatedAt);
  if (updatedCompare != 0) return updatedCompare;
  return b.id.compareTo(a.id);
}

String? _fingerprint(_TodoRow todo) {
  final source = todo.source.trim().toLowerCase();
  if (todo.deleted || !_generatedSources.contains(source)) return null;

  final externalId = todo.routineId?.trim();
  if (externalId != null && externalId.isNotEmpty) {
    if (source == 'routine') return '$source|$externalId|${todo.date}';
    return '$source|$externalId|${todo.date}|${todo.time.trim()}';
  }

  final title = _normalizeText(todo.title);
  if (title.isEmpty) return null;
  return [
    source,
    title,
    todo.date.toString(),
    todo.time.trim(),
    _normalizeDescription(todo.description),
  ].join('|');
}

String _normalizeDescription(String? description) {
  final lines = (description ?? '')
      .split('\n')
      .map((line) => line.trim())
      .where(
        (line) =>
            line.isNotEmpty &&
            !line.startsWith('来源：') &&
            !line.startsWith('短信时间：') &&
            !line.startsWith('短信原文：') &&
            !line.startsWith('发件人：'),
      );
  return _normalizeText(lines.join('\n'));
}

String _normalizeText(String value) {
  return value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}

Future<String> _runSqlite(
  String dbPath,
  String sql, {
  bool json = false,
}) async {
  final args = [if (json) '-json', dbPath, sql];
  final result = await Process.run('sqlite3', args);
  if (result.exitCode != 0) {
    throw ProcessException(
      'sqlite3',
      args,
      result.stderr.toString(),
      result.exitCode,
    );
  }
  return result.stdout.toString();
}

String _sqlString(String value) => "'${value.replaceAll("'", "''")}'";

const _generatedSources = {'calendar', 'routine', 'message', 'sms'};

class _AppContainer {
  final String id;
  final String basePath;

  const _AppContainer({required this.id, required this.basePath});
}

class _TodoRow {
  final String id;
  final String title;
  final String? description;
  final String source;
  final String? routineId;
  final String time;
  final int date;
  final bool completed;
  final int updatedAt;
  final int version;
  final bool deleted;

  const _TodoRow({
    required this.id,
    required this.title,
    required this.description,
    required this.source,
    required this.routineId,
    required this.time,
    required this.date,
    required this.completed,
    required this.updatedAt,
    required this.version,
    required this.deleted,
  });

  factory _TodoRow.fromJson(Map<String, dynamic> json) {
    return _TodoRow(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      source: json['source'] as String? ?? '',
      routineId: json['routineId'] as String?,
      time: json['time'] as String? ?? '',
      date: json['date'] as int? ?? 0,
      completed: (json['completed'] as int? ?? 0) == 1,
      updatedAt: json['updatedAt'] as int? ?? 0,
      version: json['version'] as int? ?? 1,
      deleted: (json['deleted'] as int? ?? 0) == 1,
    );
  }
}
