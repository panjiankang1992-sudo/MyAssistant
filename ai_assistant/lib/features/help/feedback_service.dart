import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../data/api/api_client.dart';

enum FeedbackModule {
  todo('todo', '待办'),
  bookkeeping('bookkeeping', '记账'),
  notes('notes', '随手记'),
  copilot('copilot', 'Copilot'),
  sync('sync', '数据同步'),
  account('account', '账号与个人信息'),
  theme('theme', '主题设置'),
  other('other', '其他');

  final String value;
  final String label;

  const FeedbackModule(this.value, this.label);
}

enum FeedbackType {
  bug('bug', '问题反馈'),
  suggestion('suggestion', '功能建议'),
  usability('usability', '体验问题'),
  data('data', '数据异常'),
  question('question', '使用咨询');

  final String value;
  final String label;

  const FeedbackType(this.value, this.label);
}

enum FeedbackSeverity {
  normal('normal', '普通'),
  important('important', '重要'),
  urgent('urgent', '紧急');

  final String value;
  final String label;

  const FeedbackSeverity(this.value, this.label);
}

class FeedbackReport {
  final String id;
  final FeedbackModule module;
  final FeedbackType type;
  final FeedbackSeverity severity;
  final String title;
  final String content;
  final String contact;
  final bool includeDiagnostics;
  final List<String> screenshotPaths;
  final DateTime createdAt;
  final Map<String, Object?> diagnostics;

  const FeedbackReport({
    required this.id,
    required this.module,
    required this.type,
    required this.severity,
    required this.title,
    required this.content,
    required this.contact,
    required this.includeDiagnostics,
    this.screenshotPaths = const [],
    required this.createdAt,
    required this.diagnostics,
  });

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'module': module.value,
      'type': type.value,
      'severity': severity.value,
      'title': title,
      'content': content,
      'contact': contact,
      'includeDiagnostics': includeDiagnostics,
      'screenshotPaths': screenshotPaths,
      'createdAt': createdAt.toIso8601String(),
      'diagnostics': includeDiagnostics ? diagnostics : <String, Object?>{},
    };
  }

  String get emailSubject {
    return '[MyAssistant反馈][${module.label}][${severity.label}] $title';
  }

  String get emailBody {
    final buffer = StringBuffer()
      ..writeln('【反馈标题】')
      ..writeln(title)
      ..writeln()
      ..writeln('【反馈模块】${module.label}')
      ..writeln('【反馈类型】${type.label}')
      ..writeln('【优先级】${severity.label}')
      ..writeln('【联系方式】${contact.isEmpty ? '未填写' : contact}')
      ..writeln('【提交时间】${createdAt.toIso8601String()}')
      ..writeln()
      ..writeln('【问题描述】')
      ..writeln(content)
      ..writeln();
    if (screenshotPaths.isNotEmpty) {
      buffer
        ..writeln('【截图】')
        ..writeln('当前系统邮件入口可能无法自动携带附件，请在邮件客户端中附加以下截图：');
      for (final path in screenshotPaths) {
        buffer.writeln('- $path');
      }
      buffer.writeln();
    }
    if (includeDiagnostics) {
      buffer
        ..writeln('【诊断信息】')
        ..writeln(const JsonEncoder.withIndent('  ').convert(diagnostics));
    }
    return buffer.toString();
  }
}

class FeedbackSubmitResult {
  final bool submitted;
  final bool queued;
  final String message;
  final String? traceId;

  const FeedbackSubmitResult({
    required this.submitted,
    required this.queued,
    required this.message,
    this.traceId,
  });
}

class FeedbackService {
  static const supportEmail = 'yuyutian_assistant@foxmail.com';
  static const feedbackEndpoint = '/api/public/feedback/report';

  Future<FeedbackSubmitResult> submit(FeedbackReport report) async {
    try {
      final response = await ApiClient.post(feedbackEndpoint, report.toJson());
      if (response.isSuccess) {
        return FeedbackSubmitResult(
          submitted: true,
          queued: false,
          message: '反馈已提交，感谢你的帮助。',
          traceId: response.traceId,
        );
      }
      await _queue(report);
      return FeedbackSubmitResult(
        submitted: false,
        queued: true,
        message: '服务端暂未接收：${response.message}，已保存到本地待上报。',
        traceId: response.traceId,
      );
    } catch (_) {
      await _queue(report);
      return const FeedbackSubmitResult(
        submitted: false,
        queued: true,
        message: '当前无法连接反馈服务，已保存到本地待上报。',
      );
    }
  }

  Future<File> pendingFile() async {
    final dir = await getApplicationSupportDirectory();
    final feedbackDir = Directory('${dir.path}/feedback');
    if (!await feedbackDir.exists()) {
      await feedbackDir.create(recursive: true);
    }
    return File('${feedbackDir.path}/pending_reports.jsonl');
  }

  Future<int> pendingCount() async {
    try {
      final file = await pendingFile();
      if (!await file.exists()) return 0;
      final lines = await file.readAsLines();
      return lines.where((line) => line.trim().isNotEmpty).length;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _queue(FeedbackReport report) async {
    final file = await pendingFile();
    await file.writeAsString(
      '${jsonEncode(report.toJson())}\n',
      mode: FileMode.append,
      flush: true,
    );
  }
}

Map<String, Object?> buildFeedbackDiagnostics() {
  return {
    'platform': Platform.operatingSystem,
    'platformVersion': Platform.operatingSystemVersion,
    'locale': Platform.localeName,
    'appVersion': '0.1.0+1',
    'client': 'flutter',
  };
}
