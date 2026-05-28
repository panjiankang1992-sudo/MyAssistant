import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_controls.dart';
import 'feedback_service.dart';

class HelpFeedbackPage extends StatefulWidget {
  const HelpFeedbackPage({super.key});

  @override
  State<HelpFeedbackPage> createState() => _HelpFeedbackPageState();
}

class _HelpFeedbackPageState extends State<HelpFeedbackPage> {
  final _service = FeedbackService();
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  FeedbackModule _module = FeedbackModule.todo;
  FeedbackType _type = FeedbackType.bug;
  FeedbackSeverity _severity = FeedbackSeverity.normal;
  bool _includeDiagnostics = true;
  bool _submitting = false;
  String _status = '';
  int _pendingCount = 0;
  final List<String> _screenshotPaths = [];

  @override
  void initState() {
    super.initState();
    _refreshPendingCount();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _contactCtrl.dispose();
    super.dispose();
  }

  Future<void> _refreshPendingCount() async {
    final count = await _service.pendingCount();
    if (mounted) setState(() => _pendingCount = count);
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();
    if (title.isEmpty || content.length < 8) {
      setState(() => _status = '请填写标题，并把问题描述得更完整一点。');
      return;
    }
    setState(() {
      _submitting = true;
      _status = '';
    });
    final report = FeedbackReport(
      id: const Uuid().v4(),
      module: _module,
      type: _type,
      severity: _severity,
      title: title,
      content: content,
      contact: _contactCtrl.text.trim(),
      includeDiagnostics: _includeDiagnostics,
      screenshotPaths: List.unmodifiable(_screenshotPaths),
      createdAt: DateTime.now(),
      diagnostics: buildFeedbackDiagnostics(),
    );
    final sent = await _sendReportEmail(report);
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _status = sent
          ? '已打开邮件客户端，请确认后发送。'
          : '无法打开邮件客户端，请手动发送到 ${FeedbackService.supportEmail}';
    });
  }

  Future<bool> _sendReportEmail(FeedbackReport report) async {
    final uri = Uri(
      scheme: 'mailto',
      path: FeedbackService.supportEmail,
      queryParameters: {
        'subject': report.emailSubject,
        'body': report.emailBody,
      },
    );
    return launchUrl(uri);
  }

  Future<void> _sendEmail() async {
    final report = FeedbackReport(
      id: const Uuid().v4(),
      module: _module,
      type: _type,
      severity: _severity,
      title: _titleCtrl.text.trim().isEmpty
          ? 'MyAssistant 使用反馈'
          : _titleCtrl.text.trim(),
      content: _contentCtrl.text.trim().isEmpty
          ? '请在这里描述你遇到的问题、复现步骤和期望结果。'
          : _contentCtrl.text.trim(),
      contact: _contactCtrl.text.trim(),
      includeDiagnostics: _includeDiagnostics,
      screenshotPaths: List.unmodifiable(_screenshotPaths),
      createdAt: DateTime.now(),
      diagnostics: buildFeedbackDiagnostics(),
    );
    if (!await _sendReportEmail(report)) {
      setState(
        () => _status = '无法打开邮件客户端，请手动发送到 ${FeedbackService.supportEmail}',
      );
    }
  }

  Future<void> _pickScreenshots() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    final paths = result?.files
        .map((file) => file.path)
        .whereType<String>()
        .where((path) => path.trim().isNotEmpty)
        .toList();
    if (paths == null || paths.isEmpty) return;
    setState(() {
      for (final path in paths) {
        if (!_screenshotPaths.contains(path)) _screenshotPaths.add(path);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(title: const Text('帮助与反馈')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 36),
        children: [
          _ContactCard(onEmailTap: _sendEmail, pendingCount: _pendingCount),
          const SizedBox(height: 22),
          const _SectionHeader(title: '使用文档', subtitle: '按模块查看常用能力和操作入口。'),
          const SizedBox(height: 10),
          for (final doc in _helpDocs) _HelpDocCard(doc: doc),
          const SizedBox(height: 24),
          const _SectionHeader(
            title: '提交反馈',
            subtitle: '按固定格式打开邮件客户端，可附带截图说明。',
          ),
          const SizedBox(height: 12),
          _FeedbackForm(
            titleCtrl: _titleCtrl,
            contentCtrl: _contentCtrl,
            contactCtrl: _contactCtrl,
            module: _module,
            type: _type,
            severity: _severity,
            includeDiagnostics: _includeDiagnostics,
            screenshotPaths: _screenshotPaths,
            onModuleChanged: (value) => setState(() => _module = value),
            onTypeChanged: (value) => setState(() => _type = value),
            onSeverityChanged: (value) => setState(() => _severity = value),
            onDiagnosticsChanged: (value) =>
                setState(() => _includeDiagnostics = value),
            onPickScreenshots: _pickScreenshots,
            onRemoveScreenshot: (path) =>
                setState(() => _screenshotPaths.remove(path)),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: _submitting ? null : _submit,
                    icon: _submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.mail_outline_rounded, size: 18),
                    label: Text(_submitting ? '打开中' : '发送邮件'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: _sendEmail,
                  icon: const Icon(Icons.mail_outline_rounded, size: 18),
                  label: const Text('邮件'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.text,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_status.isNotEmpty) ...[
            const SizedBox(height: 12),
            _StatusBox(text: _status),
          ],
        ],
      ),
    );
  }
}

class _FeedbackForm extends StatelessWidget {
  final TextEditingController titleCtrl;
  final TextEditingController contentCtrl;
  final TextEditingController contactCtrl;
  final FeedbackModule module;
  final FeedbackType type;
  final FeedbackSeverity severity;
  final bool includeDiagnostics;
  final List<String> screenshotPaths;
  final ValueChanged<FeedbackModule> onModuleChanged;
  final ValueChanged<FeedbackType> onTypeChanged;
  final ValueChanged<FeedbackSeverity> onSeverityChanged;
  final ValueChanged<bool> onDiagnosticsChanged;
  final VoidCallback onPickScreenshots;
  final ValueChanged<String> onRemoveScreenshot;

  const _FeedbackForm({
    required this.titleCtrl,
    required this.contentCtrl,
    required this.contactCtrl,
    required this.module,
    required this.type,
    required this.severity,
    required this.includeDiagnostics,
    required this.screenshotPaths,
    required this.onModuleChanged,
    required this.onTypeChanged,
    required this.onSeverityChanged,
    required this.onDiagnosticsChanged,
    required this.onPickScreenshots,
    required this.onRemoveScreenshot,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppDropdownField<FeedbackModule>(
            label: '模块',
            value: module,
            options: [
              for (final item in FeedbackModule.values)
                AppDropdownOption(value: item, label: item.label),
            ],
            onChanged: onModuleChanged,
          ),
          const SizedBox(height: 14),
          AppDropdownField<FeedbackType>(
            label: '类型',
            value: type,
            options: [
              for (final item in FeedbackType.values)
                AppDropdownOption(value: item, label: item.label),
            ],
            onChanged: onTypeChanged,
          ),
          const SizedBox(height: 14),
          AppDropdownField<FeedbackSeverity>(
            label: '优先级',
            value: severity,
            options: [
              for (final item in FeedbackSeverity.values)
                AppDropdownOption(value: item, label: item.label),
            ],
            onChanged: onSeverityChanged,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: titleCtrl,
            decoration: const InputDecoration(
              labelText: '标题',
              hintText: '例如：记账统计页面筛选异常',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: contentCtrl,
            maxLines: 5,
            minLines: 4,
            decoration: const InputDecoration(
              labelText: '问题描述',
              hintText: '请写清楚复现步骤、期望结果和实际结果。',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: contactCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: '联系方式（可选）',
              hintText: '邮箱、微信或其他可联系你的方式',
            ),
          ),
          const SizedBox(height: 10),
          _ScreenshotPicker(
            paths: screenshotPaths,
            onPick: onPickScreenshots,
            onRemove: onRemoveScreenshot,
          ),
          const SizedBox(height: 10),
          SwitchListTile.adaptive(
            value: includeDiagnostics,
            onChanged: onDiagnosticsChanged,
            contentPadding: EdgeInsets.zero,
            title: const Text(
              '附带诊断信息',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            subtitle: const Text(
              '包含平台、系统版本、语言和应用版本，不包含个人内容。',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScreenshotPicker extends StatelessWidget {
  final List<String> paths;
  final VoidCallback onPick;
  final ValueChanged<String> onRemove;

  const _ScreenshotPicker({
    required this.paths,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          onPressed: onPick,
          icon: const Icon(Icons.add_photo_alternate_rounded, size: 18),
          label: Text(paths.isEmpty ? '添加截图' : '继续添加截图'),
        ),
        if (paths.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final path in paths)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(path),
                        width: 76,
                        height: 76,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 76,
                          height: 76,
                          color: AppColors.inputBg,
                          child: const Icon(Icons.broken_image_rounded),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 4,
                      top: 4,
                      child: GestureDetector(
                        onTap: () => onRemove(path),
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 15,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _HelpDocCard extends StatelessWidget {
  final _HelpDoc doc;

  const _HelpDocCard({required this.doc});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: doc.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(doc.icon, size: 19, color: doc.color),
          ),
          title: Text(
            doc.title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          subtitle: Text(
            doc.summary,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            for (final item in doc.items)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(top: 7),
                      decoration: BoxDecoration(
                        color: doc.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.42,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final VoidCallback onEmailTap;
  final int pendingCount;

  const _ContactCard({required this.onEmailTap, required this.pendingCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.border),
        boxShadow: AppAnimations.cardShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.support_agent_rounded,
                  color: AppColors.primary,
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '使用帮助与问题反馈',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      '查看指南，或把问题直接反馈给我们。',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: onEmailTap,
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.inputBg,
                borderRadius: BorderRadius.circular(21),
                border: Border.all(color: AppColors.border),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.mail_outline_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      FeedbackService.supportEmail,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.open_in_new_rounded,
                    size: 16,
                    color: AppColors.textTertiary,
                  ),
                ],
              ),
            ),
          ),
          if (pendingCount > 0) ...[
            const SizedBox(height: 10),
            Text(
              '本地待上报反馈：$pendingCount 条',
              style: const TextStyle(fontSize: 12, color: AppColors.warning),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusBox extends StatelessWidget {
  final String text;

  const _StatusBox({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.14)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          height: 1.35,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _SectionHeader({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: AppColors.text,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 5),
          Text(
            subtitle!,
            style: const TextStyle(
              fontSize: 13,
              height: 1.35,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

class _HelpDoc {
  final String title;
  final String summary;
  final IconData icon;
  final Color color;
  final List<String> items;

  const _HelpDoc({
    required this.title,
    required this.summary,
    required this.icon,
    required this.color,
    required this.items,
  });
}

const _helpDocs = [
  _HelpDoc(
    title: '待办',
    summary: '创建、例行、日期、动作和日历同步。',
    icon: Icons.check_circle_outline_rounded,
    color: AppColors.success,
    items: [
      '点击底部待办进入列表；左上日期可切换当天待办，日期格右下角展示当天待办数量。',
      '点击底部 + 新增待办；长按 + 可进入语音输入，松开后根据识别内容打开新增页。',
      '待办详情从右侧全屏打开，默认查看，点击底部编辑按钮后可修改。',
      '例行待办会自动生成未来待办；日历来源的待办会展示日历图标。',
      '待办动作中的记账需要用户点击记账图标后执行，不会自动记账。',
    ],
  ),
  _HelpDoc(
    title: '记账',
    summary: '支出收入、分类、计算器、统计和日期净额。',
    icon: Icons.account_balance_wallet_outlined,
    color: AppColors.primary,
    items: [
      '左上日期选择器会切换记账日期，并在日期右下角展示当天收支净额。',
      '新增记账支持支出和收入分类，金额输入支持简单计算和等号确认。',
      '账单列表中的每一项可点击进入详情并修改。',
      '统计从右侧全屏打开，支持年、月、周视图和分类明细。',
      '支出、收入分类都支持自定义，默认图标会自动补齐。',
    ],
  ),
  _HelpDoc(
    title: '随手记',
    summary: '文字、图片、附件、网页快照、日记/文档/归纳。',
    icon: Icons.edit_note_rounded,
    color: AppColors.purple,
    items: [
      '默认展示最近 30 天内容，可在日记、文档、归纳之间切换。',
      '支持文字输入、图片插入、附件展示、网页快照和 Markdown 内容展示。',
      '日期选择器右下角展示当天文档数量，点击日期可筛选当天内容。',
      '归纳会读取有意义的日记和文档，拆解、合并并生成可编辑归纳文档。',
      '卡片右下角更多菜单可置顶、分享、归档或删除。',
    ],
  ),
  _HelpDoc(
    title: 'Copilot',
    summary: '聊天、技能、模型、头像、记忆和数据分析。',
    icon: Icons.auto_awesome_rounded,
    color: AppColors.primary,
    items: [
      'Copilot 可读取本地数据并使用内置技能完成查询、统计、导入和归纳。',
      '个人信息中的 Copilot 设置可修改助手名称、头像、称呼、性格和聊天风格。',
      '支持长期记忆和短期记忆；长期记忆用于稳定偏好，短期记忆用于近期上下文。',
      '模型维护中可配置不同模型，聊天界面会使用当前选择的模型。',
      '内置技能会在 Copilot 设置中展示名称、作用和简介。',
    ],
  ),
  _HelpDoc(
    title: '数据同步',
    summary: 'WebDAV 双向同步、变更记录和失败重试。',
    icon: Icons.cloud_sync_outlined,
    color: AppColors.calendarText,
    items: [
      '数据变动会记录待同步变更，后台定时检查并执行同步。',
      '同步是双向的：本地变更会推送，云端变更会拉取。',
      '网络异常时不会丢数据，会等待下一次同步重试。',
      '数据管理页面会显示 WebDAV 配置、待同步数量和最后同步时间。',
      '代办、记账、随手记和标签数据都按类型参与同步。',
    ],
  ),
  _HelpDoc(
    title: '个人信息与主题',
    summary: '头像、标签、主题、账号与反馈。',
    icon: Icons.person_outline_rounded,
    color: AppColors.warning,
    items: [
      '右上角头像是个人信息入口，待办、记账、随手记、Copilot 保持一致。',
      '标签管理在个人信息页进入，可被待办、记账和随手记共用。',
      '主题设置支持跟随系统、浅色、深色、强调色、显示密度和辅助显示。',
      '帮助与反馈页面可查看使用文档，并提交问题或发送邮件。',
    ],
  ),
];
