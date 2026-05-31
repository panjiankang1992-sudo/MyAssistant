class CloudPathBuilder {
  final String rootDirectory;

  CloudPathBuilder(String rootDirectory)
    : rootDirectory = normalizeRootDirectory(rootDirectory);

  String get username => rootDirectory;

  String get appRoot => _join(rootDirectory, 'MyAssistant');
  String get syncDirectory => '$appRoot/sync';
  String get syncIndexPath => '$syncDirectory/sync_index.json';
  String get routineDirectory => '$appRoot/todos/routine';

  static String normalizeRootDirectory(String value) {
    var path = value.trim().replaceAll('\\', '/');
    while (path.startsWith('/')) {
      path = path.substring(1);
    }
    while (path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    if (path == '.' || path == '/') return '';
    return path;
  }

  String buildFilePath(String dataType, String dateStr, String dataId) {
    if (dataType == 'routine') {
      return '$routineDirectory/routine_${_safeId(dataId)}.json';
    }
    if (dataType == 'todo') {
      return _datedPath(
        module: 'todos',
        prefix: 'todo',
        dateStr: dateStr,
        dataId: dataId,
      );
    }
    return buildDataFilePath(dataType, dataType, dataId, dateStr: dateStr);
  }

  String buildIndexPath(String module, String subType) {
    final normalizedModule = _normalizeModule(module);
    final fileName = _indexFileName(normalizedModule, subType);
    return '$appRoot/index/$normalizedModule/$fileName';
  }

  String buildDataFilePath(
    String module,
    String subType,
    String dataId, {
    String? dateStr,
  }) {
    final normalizedModule = _normalizeModule(module);
    final normalizedType = _normalizeType(normalizedModule, subType);
    final safeId = _safeId(dataId);
    switch (normalizedModule) {
      case 'todos':
        return buildFilePath(normalizedType, dateStr ?? '', safeId);
      case 'bills':
        if (normalizedType == 'category') {
          return '$appRoot/bills/category/category_$safeId.json';
        }
        return _datedPath(
          module: 'bills',
          prefix: 'bill',
          dateStr: dateStr,
          dataId: safeId,
        );
      case 'notes':
        if (normalizedType == 'diary') {
          return _datedPath(
            module: 'notes',
            prefix: 'diary',
            dateStr: dateStr,
            dataId: safeId,
          );
        }
        if (normalizedType == 'archive') {
          final category = _safeId(subType == 'archive' ? 'default' : subType);
          return '$appRoot/notes/archive/$category/archive_$safeId.json';
        }
        return '$appRoot/notes/notes/note_$safeId.json';
      case 'copilot':
        if (normalizedType == 'memory') return '$appRoot/copilot/memory.json';
        if (normalizedType == 'archive_chat') {
          return '$appRoot/copilot/archive_chat/archive_chat_$safeId.json';
        }
        return '$appRoot/copilot/chat/chat_$safeId.json';
      case 'profile':
        return _profileFilePath(normalizedType, safeId);
      case 'attachments':
        return _attachmentPath(dateStr: dateStr, dataId: safeId);
      default:
        return '$appRoot/$normalizedModule/$normalizedType/$safeId.json';
    }
  }

  String buildTagsIndexPath() {
    return '$appRoot/profile/tags_setting.json';
  }

  String buildMetadataIndexPath() {
    return '$appRoot/profile/data_setting.json';
  }

  List<String> get requiredDirectories {
    final now = DateTime.now();
    final y = now.year.toString();
    final ym = _yearMonth(now);
    final ymd = _yearMonthDay(now);
    return [
      ..._rootDirectorySegments,
      appRoot,
      syncDirectory,
      '$appRoot/index',
      '$appRoot/index/todos',
      '$appRoot/index/bills',
      '$appRoot/index/notes',
      '$appRoot/index/copilot',
      '$appRoot/index/profile',
      '$appRoot/index/attachments',
      '$appRoot/todos',
      '$appRoot/todos/$y',
      '$appRoot/todos/$y/$ym',
      '$appRoot/todos/$y/$ym/$ymd',
      routineDirectory,
      '$appRoot/bills',
      '$appRoot/bills/$y',
      '$appRoot/bills/$y/$ym',
      '$appRoot/bills/$y/$ym/$ymd',
      '$appRoot/bills/category',
      '$appRoot/notes',
      '$appRoot/notes/$y',
      '$appRoot/notes/$y/$ym',
      '$appRoot/notes/$y/$ym/$ymd',
      '$appRoot/notes/notes',
      '$appRoot/notes/archive',
      '$appRoot/copilot',
      '$appRoot/copilot/chat',
      '$appRoot/copilot/archive_chat',
      '$appRoot/profile',
      '$appRoot/attachments',
      '$appRoot/attachments/$y',
      '$appRoot/attachments/$y/$ym',
    ];
  }

  List<String> get _rootDirectorySegments {
    if (rootDirectory.isEmpty) return const [];
    final result = <String>[];
    var current = '';
    for (final part in rootDirectory.split('/')) {
      if (part.trim().isEmpty) continue;
      current = current.isEmpty ? part : '$current/$part';
      result.add(current);
    }
    return result;
  }

  String _datedPath({
    required String module,
    required String prefix,
    required String? dateStr,
    required String dataId,
  }) {
    final date = DateTime.tryParse(dateStr ?? '') ?? DateTime.now();
    final y = date.year.toString();
    final ym = _yearMonth(date);
    final ymd = _yearMonthDay(date);
    return '$appRoot/$module/$y/$ym/$ymd/${prefix}_${_safeId(dataId)}.json';
  }

  String _profileFilePath(String type, String dataId) {
    switch (type) {
      case 'user_profile':
        return '$appRoot/profile/user_profile.json';
      case 'theme':
        return '$appRoot/profile/theme_setting.json';
      case 'copilot_setting':
      case 'settings':
        return '$appRoot/profile/copilot_setting.json';
      case 'data':
      case 'metadata':
      case 'model':
        return '$appRoot/profile/data_setting.json';
      case 'tags':
      case 'tags_setting':
        return '$appRoot/profile/tags_setting.json';
      case 'feedback':
        return '$appRoot/profile/feedback.json';
      default:
        return '$appRoot/profile/${_safeId(dataId)}.json';
    }
  }

  String _attachmentPath({required String? dateStr, required String dataId}) {
    final date = DateTime.tryParse(dateStr ?? '') ?? DateTime.now();
    final y = date.year.toString();
    final ym = _yearMonth(date);
    return '$appRoot/attachments/$y/$ym/attachment_${_safeId(dataId)}.json';
  }

  String _indexFileName(String module, String subType) {
    final type = _normalizeType(module, subType);
    switch (module) {
      case 'todos':
        return type == 'routine' ? 'routine_index.json' : 'todos_index.json';
      case 'bills':
        return type == 'category' ? 'category_index.json' : 'bills_index.json';
      case 'notes':
        if (type == 'diary') return 'diary_index.json';
        if (type == 'archive') return 'archive_index.json';
        return 'notes_index.json';
      case 'copilot':
        if (type == 'archive_chat') return 'archive_chat_index.json';
        if (type == 'memory') return 'memory_index.json';
        return 'chat_index.json';
      case 'profile':
        return 'profile_index.json';
      case 'attachments':
        return 'attachments_index.json';
      default:
        return '${type}_index.json';
    }
  }

  String _normalizeModule(String module) {
    if (module == 'settings' || module == 'metadata' || module == 'tag') {
      return 'profile';
    }
    if (module == 'attachment') return 'attachments';
    return module;
  }

  String _normalizeType(String module, String type) {
    switch (type) {
      case 'todo':
        return 'todo';
      case 'routine':
      case 'routines':
        return 'routine';
      case 'entries':
      case 'bill':
      case 'bills':
        return 'bill';
      case 'categories':
      case 'category':
        return 'category';
      case 'quick_note':
      case 'note':
      case 'notes':
        return 'note';
      case 'session':
      case 'chat':
        return 'chat';
      case 'archive_chat':
        return 'archive_chat';
      case 'memory':
        return 'memory';
      case 'theme':
        return 'theme';
      case 'settings':
        return module == 'copilot' ? 'copilot_setting' : 'settings';
      case 'user_profile':
      case 'profile':
        return 'user_profile';
      case 'copilot_setting':
        return 'copilot_setting';
      case 'metadata':
      case 'model':
      case 'data':
        return 'data';
      case 'tag':
      case 'tags':
      case 'tags_setting':
        return 'tags';
      case 'feedback':
        return 'feedback';
      case 'attachment':
      case 'attachments':
        return 'attachment';
      default:
        return type;
    }
  }

  String _safeId(String value) {
    return value.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
  }

  String _yearMonth(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}';
  }

  String _yearMonthDay(DateTime date) {
    return '${_yearMonth(date)}-${date.day.toString().padLeft(2, '0')}';
  }

  String _join(String left, String right) {
    return left.isEmpty ? right : '$left/$right';
  }
}
