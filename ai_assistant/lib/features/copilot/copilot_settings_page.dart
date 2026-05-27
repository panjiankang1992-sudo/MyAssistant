import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_controls.dart';
import '../ai_settings/ai_model_page.dart';
import '../ai_settings/ai_model_provider.dart';
import '../skills/builtin_skill_registry.dart';
import 'copilot_settings.dart';

class CopilotSettingsPage extends ConsumerStatefulWidget {
  const CopilotSettingsPage({super.key});

  @override
  ConsumerState<CopilotSettingsPage> createState() =>
      _CopilotSettingsPageState();
}

class _CopilotSettingsPageState extends ConsumerState<CopilotSettingsPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _avatarController;
  late final TextEditingController _callNameController;
  late final TextEditingController _personaController;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(copilotSettingsProvider);
    _nameController = TextEditingController(text: settings.assistantName);
    _avatarController = TextEditingController(text: settings.assistantAvatar);
    _callNameController = TextEditingController(text: settings.userCallName);
    _personaController = TextEditingController(text: settings.persona);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _avatarController.dispose();
    _callNameController.dispose();
    _personaController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await ref
        .read(copilotSettingsProvider.notifier)
        .update(
          ref
              .read(copilotSettingsProvider)
              .copyWith(
                assistantName: _nameController.text.trim(),
                assistantAvatar: _avatarController.text.trim(),
                userCallName: _callNameController.text.trim(),
                persona: _personaController.text.trim().isEmpty
                    ? CopilotSettings.defaultPersona
                    : _personaController.text.trim(),
              ),
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Copilot 设置已保存'),
          duration: Duration(milliseconds: 900),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(copilotSettingsProvider);
    final modelState = ref.watch(aiModelProvider);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: const Text('Copilot 设置'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: '保存',
            onPressed: _save,
            icon: const Icon(Icons.check_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
        children: [
          _SectionCard(
            title: '智能助手',
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 78,
                      child: TextField(
                        controller: _avatarController,
                        textAlign: TextAlign.center,
                        maxLength: 2,
                        decoration: appInputDecoration(
                          label: '头像',
                          hintText: '✦',
                        ).copyWith(counterText: ''),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _nameController,
                        decoration: appInputDecoration(
                          label: '助手名称',
                          hintText: 'MyAssistant',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _callNameController,
                  decoration: appInputDecoration(
                    label: '对我的称呼',
                    hintText: '例如：老潘 / 你',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _personaController,
                  minLines: 5,
                  maxLines: 8,
                  decoration: appInputDecoration(
                    label: '性格与聊天风格',
                    hintText: CopilotSettings.defaultPersona,
                  ),
                ),
                const SizedBox(height: 14),
                _AssistantPreview(
                  name: _nameController.text.trim().isEmpty
                      ? settings.displayName
                      : _nameController.text.trim(),
                  avatar: _avatarController.text.trim().isEmpty
                      ? settings.displayAvatar
                      : _avatarController.text.trim(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: '模型维护',
            trailing: TextButton.icon(
              onPressed: () => showAiModelDialog(context, ref),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('添加'),
            ),
            child: modelState.configs.isEmpty
                ? const _EmptyHint(text: '暂无模型配置。添加后 Copilot 才能调用大模型。')
                : Column(
                    children: [
                      for (final config in modelState.configs)
                        _ModelTile(
                          name: config.name,
                          model: config.model,
                          provider: config.provider,
                          selected: modelState.selected?.id == config.id,
                          onSelect: () => ref
                              .read(aiModelProvider.notifier)
                              .select(config.id),
                          onEdit: () =>
                              showAiModelDialog(context, ref, config: config),
                          onDelete: () => ref
                              .read(aiModelProvider.notifier)
                              .delete(config.id),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: '内置技能',
            child: Column(
              children: [
                for (final skill in BuiltinSkillRegistry.all)
                  _InfoTile(
                    icon: skill.icon,
                    iconColor: skill.color,
                    title: skill.name,
                    subtitle: skill.summary,
                    meta: skill.description,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const _SectionCard(
            title: '工具',
            child: Column(
              children: [
                _InfoTile(
                  icon: Icons.storage_rounded,
                  iconColor: AppColors.success,
                  title: '本地数据库读取',
                  subtitle: '读取代办、例行、标签、记账和随手记摘要。',
                  meta: '只读工具，用于 Copilot 查询和统计分析。',
                ),
                _InfoTile(
                  icon: Icons.cloud_sync_rounded,
                  iconColor: AppColors.primary,
                  title: '数据同步',
                  subtitle: '按模块同步本地和云端数据。',
                  meta: '网络异常时自动等待下一轮同步。',
                ),
                _InfoTile(
                  icon: Icons.mic_rounded,
                  iconColor: AppColors.warning,
                  title: '语音输入',
                  subtitle: '长按新增按钮或输入区域进行语音识别。',
                  meta: '识别结果会自动带入新增页面或 Copilot 输入。',
                ),
                _InfoTile(
                  icon: Icons.auto_fix_high_rounded,
                  iconColor: AppColors.primary,
                  title: '大模型连接器',
                  subtitle: '通过 OpenAI 兼容接口调用 DeepSeek、MiniMax 等模型。',
                  meta: '由模型维护中的当前配置控制。',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;

  const _SectionCard({required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.72)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: AppColors.text,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _AssistantPreview extends StatelessWidget {
  final String name;
  final String avatar;

  const _AssistantPreview({required this.name, required this.avatar});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppColors.primary, Color(0xFF60A5FA)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Text(
                avatar,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$name 会以这个身份出现在聊天界面。',
              style: const TextStyle(
                fontSize: 13,
                height: 1.35,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModelTile extends StatelessWidget {
  final String name;
  final String model;
  final String provider;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ModelTile({
    required this.name,
    required this.model,
    required this.provider,
    required this.selected,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.07)
            : AppColors.inputBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.18)
              : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Icon(
            selected ? Icons.check_circle_rounded : Icons.memory_rounded,
            color: selected ? AppColors.primary : AppColors.textTertiary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? provider : name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$provider · $model',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '设为当前',
            onPressed: onSelect,
            icon: const Icon(Icons.radio_button_checked_rounded, size: 18),
          ),
          IconButton(
            tooltip: '编辑',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_rounded, size: 18),
          ),
          IconButton(
            tooltip: '删除',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String meta;

  const _InfoTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.meta,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.inputBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.72)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  meta,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.3,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;

  const _EmptyHint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.inputBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
      ),
    );
  }
}
