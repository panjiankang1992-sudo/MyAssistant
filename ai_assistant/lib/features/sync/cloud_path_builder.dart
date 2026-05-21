class CloudPathBuilder {
  final String username;
  CloudPathBuilder(this.username);

  String buildFilePath(String dataType, String dateStr, String dataId) {
    if (dataType == 'routine') {
      return 'MyAssistant/$username/todos/routines/$dataId.json';
    }
    final date = DateTime.tryParse(dateStr) ?? DateTime.now();
    final y = date.year.toString();
    final ym = '${date.year}${date.month.toString().padLeft(2, '0')}';
    final ymd = '$ym${date.day.toString().padLeft(2, '0')}';
    return 'MyAssistant/$username/todos/$y/$ym/$ymd/$dataId.json';
  }

  String buildIndexPath(String module, String subType) {
    return 'MyAssistant/$username/index/$module/${subType}_index.json';
  }

  List<String> get requiredDirectories {
    final now = DateTime.now();
    final y = now.year.toString();
    final ym = '${now.year}${now.month.toString().padLeft(2, '0')}';
    final ymd = '$ym${now.day.toString().padLeft(2, '0')}';
    return [
      'MyAssistant/$username',
      'MyAssistant/$username/index',
      'MyAssistant/$username/index/todos',
      'MyAssistant/$username/todos',
      'MyAssistant/$username/todos/$y',
      'MyAssistant/$username/todos/$y/$ym',
      'MyAssistant/$username/todos/$y/$ym/$ymd',
      'MyAssistant/$username/todos/routines',
      'MyAssistant/$username/bills',
      'MyAssistant/$username/notes',
      'MyAssistant/$username/copilot',
      'MyAssistant/$username/profile',
    ];
  }
}
