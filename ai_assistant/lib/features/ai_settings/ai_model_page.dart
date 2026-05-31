import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/ai_model_config.dart';
import '../../shared/widgets/app_controls.dart';
import '../../shared/widgets/edge_swipe_pop.dart';
import 'ai_model_catalog_service.dart';
import 'ai_model_provider.dart';

class AiModelPage extends ConsumerWidget {
  const AiModelPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(aiModelProvider);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('AI 模型'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            '配置 Copilot 使用的大模型。DeepSeek、MiniMax 以及大多数 OpenAI 兼容服务都可以通过 Base URL + API Key 接入。',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          if (state.configs.isEmpty)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: const Text(
                '暂无模型配置。添加后可在 Copilot 左侧快速切换。',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ...state.configs.map(
            (config) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ModelConfigCard(config: config),
            ),
          ),
          const SizedBox(height: 12),
          AppPointerTap(
            onTap: () => showAiModelDialog(context, ref),
            child: Container(
              height: appControlHeight,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, size: 20, color: Colors.white),
                  SizedBox(width: 6),
                  Text(
                    '添加模型',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          const _CapabilityCard(),
        ],
      ),
    );
  }
}

class _ModelConfigCard extends ConsumerWidget {
  final AiModelConfig config;

  const _ModelConfigCard({required this.config});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(aiModelProvider).selected?.id == config.id;
    final preset = AiProviderPresets.byProvider(config.provider);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.22)
              : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.memory_rounded,
              size: 18,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  config.name.isEmpty ? preset.label : config.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${preset.label} · ${config.model}',
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
          AppIconTapButton(
            tooltip: '设为当前',
            onPressed: () =>
                ref.read(aiModelProvider.notifier).select(config.id),
            icon: selected ? Icons.check_circle_rounded : Icons.circle_outlined,
            foregroundColor: selected
                ? AppColors.primary
                : AppColors.textTertiary,
          ),
          AppIconTapButton(
            tooltip: '编辑',
            onPressed: () => showAiModelDialog(context, ref, config: config),
            icon: Icons.edit_outlined,
            iconSize: 18,
          ),
          AppIconTapButton(
            tooltip: '删除',
            onPressed: () =>
                ref.read(aiModelProvider.notifier).delete(config.id),
            icon: Icons.delete_outline_rounded,
            iconSize: 18,
          ),
        ],
      ),
    );
  }
}

class _CapabilityCard extends StatelessWidget {
  const _CapabilityCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.inputBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Agent 能力',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 8),
          Text(
            '已内置 local_todos 与 planning 两个轻量 skill。MCP 连接管理已预留，后续可接入 Streamable HTTP MCP 服务。',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

Future<void> showAiModelDialog(
  BuildContext context,
  WidgetRef _, {
  AiModelConfig? config,
}) {
  return Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) =>
          EdgeSwipePop(child: _AiModelEditorPage(config: config)),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
    ),
  );
}

class _AiModelEditorPage extends ConsumerStatefulWidget {
  final AiModelConfig? config;

  const _AiModelEditorPage({this.config});

  @override
  ConsumerState<_AiModelEditorPage> createState() => _AiModelEditorPageState();
}

class _AiModelEditorPageState extends ConsumerState<_AiModelEditorPage> {
  late String _provider;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _baseCtrl;
  late final TextEditingController _modelCtrl;
  late final TextEditingController _keyCtrl;
  final _catalog = AiModelCatalogService();
  late List<String> _models;
  bool _fetchingModels = false;
  bool _saving = false;
  bool _obscureKey = true;
  String? _modelFetchError;
  String? _formError;

  @override
  void initState() {
    super.initState();
    final config = widget.config;
    _provider = config?.provider ?? 'deepseek';
    final preset = AiProviderPresets.byProvider(_provider);
    _nameCtrl = TextEditingController(text: config?.name ?? preset.label);
    _baseCtrl = TextEditingController(text: config?.baseUrl ?? preset.baseUrl);
    _modelCtrl = TextEditingController(text: config?.model ?? preset.model);
    _keyCtrl = TextEditingController(text: config?.apiKey ?? '');
    _models = _catalog.fallbackModels(_provider);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _baseCtrl.dispose();
    _modelCtrl.dispose();
    _keyCtrl.dispose();
    super.dispose();
  }

  bool get _busy => _saving || _fetchingModels;

  void _applyPreset(String value) {
    final preset = AiProviderPresets.byProvider(value);
    setState(() {
      _provider = value;
      _models = _catalog.fallbackModels(_provider);
      _modelFetchError = null;
      _formError = null;
      if (widget.config == null || _nameCtrl.text.trim().isEmpty) {
        _nameCtrl.text = preset.label;
      }
      if (value != 'custom') {
        _baseCtrl.text = preset.baseUrl;
        _modelCtrl.text = preset.model;
      }
    });
  }

  Future<void> _pasteInto(TextEditingController controller) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    if (text.isEmpty) return;
    controller.value = TextEditingValue(
      text: text.trim(),
      selection: TextSelection.collapsed(offset: text.trim().length),
    );
  }

  Future<void> _fetchModels() async {
    setState(() {
      _fetchingModels = true;
      _modelFetchError = null;
      _formError = null;
    });
    try {
      final fetched = await _catalog.fetchModels(
        provider: _provider,
        baseUrl: _baseCtrl.text.trim(),
        apiKey: _keyCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _models = fetched.isEmpty
            ? _catalog.fallbackModels(_provider)
            : fetched;
        if (_models.isNotEmpty && !_models.contains(_modelCtrl.text.trim())) {
          _modelCtrl.text = _models.first;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _modelFetchError = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _fetchingModels = false);
    }
  }

  String? _validate() {
    if (_nameCtrl.text.trim().isEmpty) return '请填写显示名称';
    if (_baseCtrl.text.trim().isEmpty) return '请填写 Base URL';
    if (_modelCtrl.text.trim().isEmpty) return '请填写模型名';
    if (_keyCtrl.text.trim().isEmpty) return '请填写 API Key';
    return null;
  }

  Future<void> _save() async {
    if (_busy) return;
    final error = _validate();
    if (error != null) {
      setState(() => _formError = error);
      return;
    }
    setState(() {
      _saving = true;
      _formError = null;
    });
    final now = DateTime.now();
    try {
      await ref
          .read(aiModelProvider.notifier)
          .upsert(
            AiModelConfig(
              id: widget.config?.id ?? '',
              name: _nameCtrl.text.trim(),
              provider: _provider,
              baseUrl: _baseCtrl.text.trim(),
              model: _modelCtrl.text.trim(),
              apiKey: _keyCtrl.text.trim(),
              createdAt: widget.config?.createdAt ?? now,
              updatedAt: now,
            ),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _formError = '保存失败：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final title = widget.config == null ? '添加模型' : '编辑模型';
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(22, 16, 22, 126 + keyboardInset),
              children: [
                Row(
                  children: [
                    IconButton.filledTonal(
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: scheme.appText,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  '配置 Copilot 调用的大模型。粘贴按钮可直接从剪贴板写入 Base URL 或 API Key。',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: scheme.appMutedText,
                  ),
                ),
                const SizedBox(height: 18),
                AppDropdownField<String>(
                  label: '厂商',
                  value: _provider,
                  options: AiProviderPresets.options
                      .map(
                        (item) => AppDropdownOption(
                          value: item.provider,
                          label: item.label,
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (!_busy) _applyPreset(value);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameCtrl,
                  enabled: !_busy,
                  textInputAction: TextInputAction.next,
                  decoration: appInputDecoration(
                    context: context,
                    label: '显示名称',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _baseCtrl,
                  enabled: !_busy,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.next,
                  decoration: appInputDecoration(
                    context: context,
                    label: 'Base URL',
                    hintText: 'https://api.example.com/v1',
                    suffixIcon: AppIconTapButton(
                      tooltip: '粘贴',
                      onPressed: _busy ? null : () => _pasteInto(_baseCtrl),
                      icon: Icons.content_paste_rounded,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _models.isEmpty
                          ? TextField(
                              controller: _modelCtrl,
                              enabled: !_busy,
                              textInputAction: TextInputAction.next,
                              decoration: appInputDecoration(
                                context: context,
                                label: '模型名',
                              ),
                            )
                          : AppDropdownField<String>(
                              label: '模型名',
                              value: _models.contains(_modelCtrl.text.trim())
                                  ? _modelCtrl.text.trim()
                                  : _models.first,
                              options: _models
                                  .map(
                                    (model) => AppDropdownOption(
                                      value: model,
                                      label: model,
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (!_busy) {
                                  setState(() => _modelCtrl.text = value);
                                }
                              },
                            ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: appControlHeight,
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : _fetchModels,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(92, appControlHeight),
                          fixedSize: const Size.fromHeight(appControlHeight),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          side: BorderSide(
                            color: scheme.primary.withValues(alpha: 0.28),
                          ),
                        ),
                        icon: _fetchingModels
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.cloud_sync_rounded, size: 16),
                        label: const Text('拉取'),
                      ),
                    ),
                  ],
                ),
                if (_modelFetchError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _modelFetchError!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.danger,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: _keyCtrl,
                  enabled: !_busy,
                  obscureText: _obscureKey,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _save(),
                  decoration: appInputDecoration(
                    context: context,
                    label: 'API Key',
                    suffixIcon: SizedBox(
                      width: 92,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          AppIconTapButton(
                            tooltip: '粘贴',
                            onPressed: _busy
                                ? null
                                : () => _pasteInto(_keyCtrl),
                            icon: Icons.content_paste_rounded,
                          ),
                          AppIconTapButton(
                            tooltip: _obscureKey ? '显示' : '隐藏',
                            onPressed: _busy
                                ? null
                                : () => setState(
                                    () => _obscureKey = !_obscureKey,
                                  ),
                            icon: _obscureKey
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_formError != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: scheme.errorContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _formError!,
                      style: TextStyle(
                        fontSize: 14,
                        color: scheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: keyboardInset,
              child: _AiModelEditorActions(
                saving: _saving,
                busy: _busy,
                onCancel: () => Navigator.of(context).pop(),
                onSave: _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiModelEditorActions extends StatelessWidget {
  final bool saving;
  final bool busy;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  const _AiModelEditorActions({
    required this.saving,
    required this.busy,
    required this.onCancel,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          scheme.surface.withValues(alpha: 0.88),
          Theme.of(context).scaffoldBackgroundColor,
        ),
        border: Border(
          top: BorderSide(color: scheme.outline.withValues(alpha: 0.12)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
          child: Row(
            children: [
              Expanded(
                child: AppDialogActionButton(
                  label: '取消',
                  onPressed: busy ? null : onCancel,
                  tone: AppActionButtonTone.neutral,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: AppDialogActionButton(
                  label: saving ? '保存中' : '保存',
                  onPressed: busy ? null : onSave,
                  icon: Icons.check_rounded,
                  filled: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
