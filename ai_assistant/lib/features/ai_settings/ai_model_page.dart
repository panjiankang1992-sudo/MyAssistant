import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/ai_model_config.dart';
import '../../shared/widgets/app_controls.dart';
import 'ai_model_catalog_service.dart';
import 'ai_model_provider.dart';

class AiModelPage extends ConsumerWidget {
  const AiModelPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(aiModelProvider);
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
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
          SizedBox(
            height: appControlHeight,
            child: ElevatedButton.icon(
              onPressed: () => _showModelDialog(context, ref),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('添加模型'),
              style: appControlButtonStyle(),
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
          IconButton(
            tooltip: '设为当前',
            onPressed: () =>
                ref.read(aiModelProvider.notifier).select(config.id),
            icon: Icon(
              selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: selected ? AppColors.primary : AppColors.textTertiary,
            ),
          ),
          IconButton(
            tooltip: '编辑',
            onPressed: () => _showModelDialog(context, ref, config: config),
            icon: const Icon(Icons.edit_outlined, size: 18),
          ),
          IconButton(
            tooltip: '删除',
            onPressed: () =>
                ref.read(aiModelProvider.notifier).delete(config.id),
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
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

Future<void> _showModelDialog(
  BuildContext context,
  WidgetRef ref, {
  AiModelConfig? config,
}) async {
  final now = DateTime.now();
  var provider = config?.provider ?? 'deepseek';
  final nameCtrl = TextEditingController(text: config?.name ?? 'DeepSeek');
  final baseCtrl = TextEditingController(
    text: config?.baseUrl ?? AiProviderPresets.byProvider(provider).baseUrl,
  );
  final modelCtrl = TextEditingController(
    text: config?.model ?? AiProviderPresets.byProvider(provider).model,
  );
  final keyCtrl = TextEditingController(text: config?.apiKey ?? '');
  final catalog = AiModelCatalogService();
  var models = catalog.fallbackModels(provider);
  var fetchingModels = false;
  String? modelFetchError;

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        void applyPreset(String value) {
          final preset = AiProviderPresets.byProvider(value);
          setState(() {
            provider = value;
            models = catalog.fallbackModels(provider);
            modelFetchError = null;
            if (config == null || nameCtrl.text.trim().isEmpty) {
              nameCtrl.text = preset.label;
            }
            if (value != 'custom') {
              baseCtrl.text = preset.baseUrl;
              modelCtrl.text = preset.model;
            }
          });
        }

        Future<void> fetchModels() async {
          setState(() {
            fetchingModels = true;
            modelFetchError = null;
          });
          try {
            final fetched = await catalog.fetchModels(
              provider: provider,
              baseUrl: baseCtrl.text.trim(),
              apiKey: keyCtrl.text.trim(),
            );
            setState(() {
              models = fetched.isEmpty
                  ? catalog.fallbackModels(provider)
                  : fetched;
              if (models.isNotEmpty &&
                  !models.contains(modelCtrl.text.trim())) {
                modelCtrl.text = models.first;
              }
            });
          } catch (e) {
            setState(() {
              modelFetchError = e.toString().replaceFirst('Exception: ', '');
            });
          } finally {
            setState(() {
              fetchingModels = false;
            });
          }
        }

        return AlertDialog(
          title: Text(config == null ? '添加模型' : '编辑模型'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppDropdownField<String>(
                    label: '厂商',
                    value: provider,
                    options: AiProviderPresets.options
                        .map(
                          (item) => AppDropdownOption(
                            value: item.provider,
                            label: item.label,
                          ),
                        )
                        .toList(),
                    onChanged: applyPreset,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    decoration: appInputDecoration(label: '显示名称'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: baseCtrl,
                    decoration: appInputDecoration(
                      label: 'Base URL',
                      hintText: 'https://api.example.com/v1',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: models.isEmpty
                            ? TextField(
                                controller: modelCtrl,
                                decoration: appInputDecoration(label: '模型名'),
                              )
                            : AppDropdownField<String>(
                                label: '模型名',
                                value: models.contains(modelCtrl.text.trim())
                                    ? modelCtrl.text.trim()
                                    : models.first,
                                options: models
                                    .map(
                                      (model) => AppDropdownOption(
                                        value: model,
                                        label: model,
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) =>
                                    setState(() => modelCtrl.text = value),
                              ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        height: appControlHeight,
                        child: OutlinedButton.icon(
                          onPressed: fetchingModels ? null : fetchModels,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(92, appControlHeight),
                            fixedSize: const Size.fromHeight(appControlHeight),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            side: BorderSide(
                              color: AppColors.primary.withValues(alpha: 0.28),
                            ),
                          ),
                          icon: fetchingModels
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
                  if (modelFetchError != null) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        modelFetchError!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.danger,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: keyCtrl,
                    obscureText: true,
                    decoration: appInputDecoration(label: 'API Key'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                await ref
                    .read(aiModelProvider.notifier)
                    .upsert(
                      AiModelConfig(
                        id: config?.id ?? '',
                        name: nameCtrl.text.trim(),
                        provider: provider,
                        baseUrl: baseCtrl.text.trim(),
                        model: modelCtrl.text.trim(),
                        apiKey: keyCtrl.text.trim(),
                        createdAt: config?.createdAt ?? now,
                        updatedAt: now,
                      ),
                    );
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    ),
  );
}
