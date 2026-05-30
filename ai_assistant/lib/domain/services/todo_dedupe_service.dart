import '../models/todo.dart';

class TodoDedupeService {
  static const generatedSources = {'calendar', 'routine', 'message', 'sms'};

  const TodoDedupeService._();

  static List<Todo> duplicatesToDelete(
    List<Todo> todos, {
    Map<String, int> cloudVersionById = const {},
  }) {
    final groups = <String, List<Todo>>{};
    for (final todo in todos) {
      final fingerprint = _fingerprint(todo);
      if (fingerprint == null) continue;
      groups.putIfAbsent(fingerprint, () => []).add(todo);
    }

    final duplicates = <Todo>[];
    for (final group in groups.values.where((items) => items.length > 1)) {
      group.sort((a, b) => _compareWinner(b, a, cloudVersionById));
      duplicates.addAll(group.skip(1).where((todo) => !todo.deleted));
    }
    return duplicates;
  }

  static int _compareWinner(Todo a, Todo b, Map<String, int> cloudVersionById) {
    if (a.completed != b.completed) {
      return a.completed ? 1 : -1;
    }

    final versionCompare = a.version.compareTo(b.version);
    if (versionCompare != 0) return versionCompare;

    final aCloudVersion = cloudVersionById[a.id] ?? 0;
    final bCloudVersion = cloudVersionById[b.id] ?? 0;
    final cloudCompare = aCloudVersion.compareTo(bCloudVersion);
    if (cloudCompare != 0) return cloudCompare;

    final updatedCompare = a.updatedAt.compareTo(b.updatedAt);
    if (updatedCompare != 0) return updatedCompare;
    return b.id.compareTo(a.id);
  }

  static String? _fingerprint(Todo todo) {
    final source = _normalizedSource(todo.source);
    if (todo.deleted || !generatedSources.contains(source)) return null;

    final date = _dateStr(todo.date);
    final externalId = todo.routineId?.trim();
    if (externalId != null && externalId.isNotEmpty) {
      if (source == 'routine') return '$source|$externalId|$date';
      return '$source|$externalId|$date|${todo.time.trim()}';
    }

    final title = _normalizeText(todo.title);
    if (title.isEmpty) return null;
    return [
      source,
      title,
      date,
      todo.time.trim(),
      _normalizeDescription(todo.description),
    ].join('|');
  }

  static String _normalizedSource(String source) {
    return switch (source.trim().toLowerCase()) {
      'calendar' => 'calendar',
      'routine' => 'routine',
      'message' => 'message',
      'sms' => 'sms',
      _ => source.trim().toLowerCase(),
    };
  }

  static String _normalizeDescription(String? description) {
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

  static String _normalizeText(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  }

  static String _dateStr(DateTime dt) => dt.toIso8601String().split('T').first;
}
