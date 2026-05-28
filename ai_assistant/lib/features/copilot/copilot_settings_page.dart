import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_controls.dart';
import '../ai_settings/ai_model_page.dart';
import '../ai_settings/ai_model_provider.dart';
import '../skills/builtin_skill_registry.dart';
import 'copilot_avatar.dart';
import 'copilot_memory.dart';
import 'copilot_settings.dart';

class CopilotSettingsPage extends ConsumerStatefulWidget {
  const CopilotSettingsPage({super.key});

  @override
  ConsumerState<CopilotSettingsPage> createState() =>
      _CopilotSettingsPageState();
}

class _CopilotSettingsPageState extends ConsumerState<CopilotSettingsPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _callNameController;
  late final TextEditingController _personaController;
  late String _avatarValue;
  late String _personaStyle;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(copilotSettingsProvider);
    _nameController = TextEditingController(text: settings.assistantName);
    _avatarValue = settings.displayAvatar;
    _callNameController = TextEditingController(text: settings.userCallName);
    _personaController = TextEditingController(text: settings.persona);
    _personaStyle = settings.displayPersonaStyle;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _callNameController.dispose();
    _personaController.dispose();
    super.dispose();
  }

  Future<String?> _pickCustomAvatarValue() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    final path = result?.files.single.path;
    if (path == null || path.trim().isEmpty) return null;
    return CopilotAvatarCatalog.fileValue(path);
  }

  Future<void> _openAvatarPicker() async {
    final value = await showDialog<String>(
      context: context,
      builder: (context) => _AvatarPickerDialog(
        value: _avatarValue,
        onPickCustom: _pickCustomAvatarValue,
      ),
    );
    if (value == null || value.trim().isEmpty) return;
    setState(() => _avatarValue = value);
  }

  Future<void> _save() async {
    await ref
        .read(copilotSettingsProvider.notifier)
        .update(
          ref
              .read(copilotSettingsProvider)
              .copyWith(
                assistantName: _nameController.text.trim(),
                assistantAvatar: _avatarValue,
                userCallName: _callNameController.text.trim(),
                personaStyle: _personaStyle,
                persona: _personaController.text.trim().isEmpty
                    ? CopilotPersonaCatalog.defaultPromptOf(_personaStyle)
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
    final memoryState = ref.watch(copilotMemoryProvider);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: const Text('Copilot 设置'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: IconButton(
              tooltip: '保存',
              onPressed: _save,
              icon: const Icon(Icons.check_rounded),
            ),
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
                    _AvatarSummary(
                      value: _avatarValue,
                      onTap: _openAvatarPicker,
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
                _PersonaPicker(
                  value: _personaStyle,
                  onChanged: (value) {
                    setState(() {
                      _personaStyle = value;
                      if (value != CopilotPersonaCatalog.customValue) {
                        _personaController.text = CopilotPersonaCatalog.byValue(
                          value,
                        ).prompt;
                      }
                    });
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _personaController,
                  minLines: 5,
                  maxLines: 8,
                  decoration: appInputDecoration(
                    label: '性格与聊天风格',
                    hintText: CopilotSettings.defaultPersona,
                  ),
                  onChanged: (_) {
                    if (_personaStyle != CopilotPersonaCatalog.customValue) {
                      setState(
                        () => _personaStyle = CopilotPersonaCatalog.customValue,
                      );
                    }
                  },
                ),
                const SizedBox(height: 14),
                _AssistantPreview(
                  name: _nameController.text.trim().isEmpty
                      ? settings.displayName
                      : _nameController.text.trim(),
                  avatar: _avatarValue,
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
            title: '记忆',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _MemoryIntro(),
                const SizedBox(height: 12),
                _MemoryList(
                  title: '长期记忆',
                  subtitle: '跨会话保留。适合你的偏好、称呼、长期目标、稳定事实。',
                  items: memoryState.longTerm,
                  emptyText: '暂无长期记忆。可以手动添加，或在聊天中说“记住……”。',
                  onAdd: () => _showMemoryDialog(
                    context,
                    ref,
                    type: CopilotMemoryType.longTerm,
                  ),
                  onEdit: (item) => _showMemoryDialog(
                    context,
                    ref,
                    type: item.type,
                    item: item,
                  ),
                  onDelete: (item) =>
                      ref.read(copilotMemoryProvider.notifier).delete(item.id),
                ),
                const SizedBox(height: 12),
                _MemoryList(
                  title: '短期记忆',
                  subtitle: '自动记录最近对话摘要，最多保留 30 条，用于当前阶段连续性。',
                  items: memoryState.shortTerm,
                  emptyText: '暂无短期记忆。和 Copilot 对话后会自动生成。',
                  trailing: TextButton(
                    onPressed: memoryState.shortTerm.isEmpty
                        ? null
                        : () => ref
                              .read(copilotMemoryProvider.notifier)
                              .clearShortTerm(),
                    child: const Text('清空'),
                  ),
                  onAdd: () => _showMemoryDialog(
                    context,
                    ref,
                    type: CopilotMemoryType.shortTerm,
                  ),
                  onEdit: (item) => _showMemoryDialog(
                    context,
                    ref,
                    type: item.type,
                    item: item,
                  ),
                  onDelete: (item) =>
                      ref.read(copilotMemoryProvider.notifier).delete(item.id),
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
          CopilotAvatarView(value: avatar, size: 38),
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

class _AvatarSummary extends StatelessWidget {
  final String value;
  final VoidCallback onTap;

  const _AvatarSummary({required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: CopilotAvatarView(value: value, size: 58),
          ),
        ),
        const SizedBox(height: 5),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            minimumSize: const Size(0, 28),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            '更换头像',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _AvatarPickerDialog extends StatefulWidget {
  final String value;
  final Future<String?> Function() onPickCustom;

  const _AvatarPickerDialog({required this.value, required this.onPickCustom});

  @override
  State<_AvatarPickerDialog> createState() => _AvatarPickerDialogState();
}

class _AvatarPickerDialogState extends State<_AvatarPickerDialog> {
  late String _selected;

  @override
  void initState() {
    super.initState();
    _selected = CopilotAvatarCatalog.normalize(widget.value);
  }

  Future<void> _pickCustom() async {
    final value = await widget.onPickCustom();
    if (value == null || value.trim().isEmpty) return;
    setState(() => _selected = value);
  }

  @override
  Widget build(BuildContext context) {
    final isCustom = _selected.startsWith('file:');
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 680),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 34,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 14, 10),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '选择 Copilot 头像',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '关闭',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Row(
                  children: [
                    CopilotAvatarView(value: _selected, size: 54),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        CopilotAvatarCatalog.descriptionOf(_selected),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _pickCustom,
                      icon: const Icon(Icons.photo_library_rounded, size: 17),
                      label: const Text('图库上传'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.border),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final preset in CopilotAvatarCatalog.presets)
                        _AvatarChoice(
                          label: preset.label,
                          selected: _selected == preset.value,
                          onTap: () => setState(() => _selected = preset.value),
                          child: CopilotAvatarView(
                            value: preset.value,
                            size: 54,
                            selected: _selected == preset.value,
                          ),
                        ),
                      if (isCustom)
                        _AvatarChoice(
                          label: '自选',
                          selected: true,
                          onTap: _pickCustom,
                          child: CopilotAvatarView(
                            value: _selected,
                            size: 54,
                            selected: true,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('取消'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(_selected),
                        child: const Text('确定'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarChoice extends StatelessWidget {
  final String label;
  final bool selected;
  final Widget child;
  final VoidCallback onTap;

  const _AvatarChoice({
    required this.label,
    required this.selected,
    required this.child,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: AppAnimations.shortDuration,
          width: 72,
          height: 72,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.08)
                : AppColors.inputBg.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.34)
                  : AppColors.border.withValues(alpha: 0.75),
            ),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [child]),
        ),
      ),
    );
  }
}

class _PersonaPicker extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _PersonaPicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final normalized = CopilotPersonaCatalog.normalizeStyle(value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '性格预设',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.textTertiary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 9,
          runSpacing: 9,
          children: [
            for (final preset in CopilotPersonaCatalog.presets)
              _PersonaChoice(
                label: preset.label,
                description: preset.description,
                selected: normalized == preset.value,
                onTap: () => onChanged(preset.value),
              ),
            _PersonaChoice(
              label: '自定义',
              description: '按你的文本框内容执行。',
              selected: normalized == CopilotPersonaCatalog.customValue,
              onTap: () => onChanged(CopilotPersonaCatalog.customValue),
            ),
          ],
        ),
      ],
    );
  }
}

class _PersonaChoice extends StatelessWidget {
  final String label;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  const _PersonaChoice({
    required this.label,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: AppAnimations.shortDuration,
        width: 126,
        constraints: const BoxConstraints(minHeight: 82),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.08)
              : AppColors.inputBg.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.36)
                : AppColors.border.withValues(alpha: 0.75),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: selected ? AppColors.primary : AppColors.text,
                    ),
                  ),
                ),
                if (selected)
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 15,
                    color: AppColors.primary,
                  ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                height: 1.28,
                fontWeight: FontWeight.w600,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
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

class _MemoryIntro extends StatelessWidget {
  const _MemoryIntro();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
      ),
      child: const Text(
        '轻量记忆方案：短期记忆保存近期对话摘要，用完会衰减；长期记忆保存稳定偏好和事实。'
        'Copilot 每次回复前只读取少量高价值记忆，避免上下文变重。',
        style: TextStyle(
          fontSize: 12.5,
          height: 1.42,
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MemoryList extends StatelessWidget {
  final String title;
  final String subtitle;
  final String emptyText;
  final List<CopilotMemoryItem> items;
  final Widget? trailing;
  final VoidCallback onAdd;
  final ValueChanged<CopilotMemoryItem> onEdit;
  final ValueChanged<CopilotMemoryItem> onDelete;

  const _MemoryList({
    required this.title,
    required this.subtitle,
    required this.emptyText,
    required this.items,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.inputBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
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
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.32,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              ?trailing,
              IconButton(
                tooltip: '添加记忆',
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Text(
              emptyText,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            )
          else
            ...items.map(
              (item) => _MemoryTile(
                item: item,
                onEdit: () => onEdit(item),
                onDelete: () => onDelete(item),
              ),
            ),
        ],
      ),
    );
  }
}

class _MemoryTile extends StatelessWidget {
  final CopilotMemoryItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MemoryTile({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(11, 10, 7, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.65)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: item.type == CopilotMemoryType.longTerm
                  ? AppColors.primary.withValues(alpha: 0.09)
                  : AppColors.warning.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              item.type == CopilotMemoryType.longTerm
                  ? Icons.psychology_alt_rounded
                  : Icons.history_rounded,
              size: 16,
              color: item.type == CopilotMemoryType.longTerm
                  ? AppColors.primary
                  : AppColors.warning,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.content,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.34,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _MiniBadge('重要 ${item.importance}/5'),
                    for (final tag in item.tags.take(4)) _MiniBadge(tag),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '编辑',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_rounded, size: 17),
          ),
          IconButton(
            tooltip: '删除',
            onPressed: onDelete,
            icon: const Icon(
              Icons.delete_outline_rounded,
              size: 17,
              color: AppColors.danger,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final String text;

  const _MiniBadge(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          color: AppColors.primary,
          fontWeight: FontWeight.w800,
        ),
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

Future<void> _showMemoryDialog(
  BuildContext context,
  WidgetRef ref, {
  required CopilotMemoryType type,
  CopilotMemoryItem? item,
}) async {
  var memoryType = item?.type ?? type;
  var importance =
      item?.importance ?? (type == CopilotMemoryType.longTerm ? 4 : 2);
  final titleController = TextEditingController(text: item?.title ?? '');
  final contentController = TextEditingController(text: item?.content ?? '');
  final tagsController = TextEditingController(
    text: item?.tags.join('、') ?? '',
  );
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setState) {
          return AlertDialog(
            title: Text(item == null ? '添加记忆' : '编辑记忆'),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppDropdownField<CopilotMemoryType>(
                      label: '记忆类型',
                      value: memoryType,
                      options: const [
                        AppDropdownOption(
                          value: CopilotMemoryType.longTerm,
                          label: '长期记忆',
                        ),
                        AppDropdownOption(
                          value: CopilotMemoryType.shortTerm,
                          label: '短期记忆',
                        ),
                      ],
                      onChanged: (value) => setState(() => memoryType = value),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleController,
                      decoration: appInputDecoration(label: '标题'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: contentController,
                      minLines: 4,
                      maxLines: 7,
                      decoration: appInputDecoration(label: '内容'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: tagsController,
                      decoration: appInputDecoration(
                        label: '标签',
                        hintText: '用逗号或顿号分隔',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text(
                          '重要度',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Slider(
                            value: importance.toDouble(),
                            min: 1,
                            max: 5,
                            divisions: 4,
                            label: '$importance',
                            onChanged: (value) =>
                                setState(() => importance = value.round()),
                          ),
                        ),
                        Text(
                          '$importance/5',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () async {
                  final content = contentController.text.trim();
                  if (content.isEmpty) return;
                  final tags = tagsController.text
                      .split(RegExp(r'[、,\s]+'))
                      .map((item) => item.trim())
                      .where((item) => item.isNotEmpty)
                      .toSet()
                      .toList();
                  await ref
                      .read(copilotMemoryProvider.notifier)
                      .upsert(
                        id: item?.id,
                        type: memoryType,
                        title: titleController.text.trim(),
                        content: content,
                        tags: tags,
                        importance: importance,
                      );
                  if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                },
                child: const Text('保存'),
              ),
            ],
          );
        },
      );
    },
  );
  titleController.dispose();
  contentController.dispose();
  tagsController.dispose();
}
