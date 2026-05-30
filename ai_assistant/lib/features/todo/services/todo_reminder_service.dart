import 'package:flutter/services.dart';

import '../../../domain/models/todo.dart';

class TodoReminderService {
  static const _channel = MethodChannel('my_assistant/todo_reminders');

  const TodoReminderService();

  Future<void> ensureNotificationPermission() async {
    try {
      await _channel.invokeMethod<void>('ensureNotificationPermission');
    } on MissingPluginException {
      // 鸿蒙等未接入原生桥时不阻断应用启动。
    } on PlatformException {
      // 用户拒绝或平台异常时，后续保存代办仍可继续。
    }
  }

  Future<void> schedule(Todo todo) async {
    final fireAt = reminderTimeFor(todo);
    if (fireAt == null) {
      await cancel(todo.id);
      return;
    }
    try {
      await _channel.invokeMethod<void>('schedule', {
        'id': todo.id,
        'title': todo.title,
        'body': _bodyFor(todo),
        'fireAtMillis': fireAt.millisecondsSinceEpoch,
      });
    } on MissingPluginException {
      // 鸿蒙等未接入原生桥时不阻断代办保存；数据仍会保留提醒配置。
    } on PlatformException {
      // 权限、平台日历/通知实现异常等待下次应用启动重新调度。
    }
  }

  Future<void> cancel(String todoId) async {
    try {
      await _channel.invokeMethod<void>('cancel', {'id': todoId});
    } on MissingPluginException {
      // 平台未接入时无需取消。
    } on PlatformException {
      // 取消失败不影响本地数据状态。
    }
  }

  Future<void> rescheduleAll(Iterable<Todo> todos) async {
    for (final todo in todos) {
      if (todo.deleted || todo.completed) {
        await cancel(todo.id);
      } else {
        await schedule(todo);
      }
    }
  }

  DateTime? reminderTimeFor(Todo todo) {
    if (!todo.reminderEnabled || todo.completed || todo.deleted) return null;
    final timeParts = todo.time.split(':');
    final hour = int.tryParse(timeParts.first) ?? 9;
    final minute = timeParts.length > 1 ? int.tryParse(timeParts[1]) ?? 0 : 0;
    final dueAt = DateTime(
      todo.date.year,
      todo.date.month,
      todo.date.day,
      hour.clamp(0, 23),
      minute.clamp(0, 59),
    );
    final fireAt = dueAt.subtract(
      Duration(minutes: todo.reminderMinutesBefore),
    );
    if (!fireAt.isAfter(DateTime.now())) return null;
    return fireAt;
  }

  String _bodyFor(Todo todo) {
    final pieces = <String>[
      Todo.formatReminderMinutes(todo.reminderMinutesBefore),
      '${todo.time} ${todo.title}',
    ];
    final description = todo.description?.trim();
    if (description != null && description.isNotEmpty) {
      pieces.add(description);
    }
    return pieces.join(' · ');
  }
}
