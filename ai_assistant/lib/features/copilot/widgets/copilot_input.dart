import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/models/ai_model_config.dart';
import '../../../shared/widgets/app_controls.dart';
import '../../ai_settings/ai_model_catalog_service.dart';
import '../../ai_settings/ai_model_provider.dart';

class CopilotInput extends ConsumerStatefulWidget {
  final void Function(String) onSend;
  final AiModelConfig? selectedModel;
  final bool isRunning;

  const CopilotInput({
    super.key,
    required this.onSend,
    required this.selectedModel,
    required this.isRunning,
  });

  @override
  ConsumerState<CopilotInput> createState() => _CopilotInputState();
}

class _CopilotInputState extends ConsumerState<CopilotInput> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.isRunning) return;
    widget.onSend(text);
    _controller.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _controller.text.trim().isNotEmpty;
    final modelName = widget.selectedModel?.name.isNotEmpty == true
        ? widget.selectedModel!.name
        : (widget.selectedModel?.model ?? '配置模型');
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              decoration: BoxDecoration(
                color: scheme.appSurface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _focusNode.hasFocus
                      ? scheme.primary.withValues(alpha: 0.28)
                      : scheme.appBorder,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _InputModelSelector(
                    selectedModel: widget.selectedModel,
                    label: modelName,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.centerLeft,
                      decoration: BoxDecoration(
                        color: scheme.appInput.withValues(alpha: 0.86),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: CallbackShortcuts(
                        bindings: {
                          const SingleActivator(LogicalKeyboardKey.enter):
                              _handleSend,
                        },
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          minLines: 1,
                          maxLines: 1,
                          keyboardType: TextInputType.text,
                          textInputAction: TextInputAction.send,
                          textAlignVertical: TextAlignVertical.center,
                          onChanged: (_) => setState(() {}),
                          onTap: () => setState(() {}),
                          cursorColor: scheme.primary,
                          cursorHeight: 21,
                          cursorWidth: 2,
                          decoration: InputDecoration(
                            hintText: '输入你的问题...',
                            hintStyle: TextStyle(
                              fontFamily: 'PingFang SC',
                              fontFamilyFallback: [
                                '.SF Pro Text',
                                'system-ui',
                                'sans-serif',
                              ],
                              fontSize: 15,
                              height: 1.35,
                              fontWeight: FontWeight.w400,
                              color: scheme.appSubtleText,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            hoverColor: Colors.transparent,
                            fillColor: Colors.transparent,
                            focusColor: Colors.transparent,
                            isCollapsed: true,
                            contentPadding: const EdgeInsets.only(bottom: 1),
                          ),
                          style: TextStyle(
                            fontFamily: 'PingFang SC',
                            fontFamilyFallback: const [
                              '.SF Pro Text',
                              'system-ui',
                              'sans-serif',
                            ],
                            fontSize: 15,
                            height: 1.35,
                            fontWeight: FontWeight.w400,
                            color: scheme.appText,
                          ),
                          onSubmitted: (_) => _handleSend(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: hasText && !widget.isRunning
                          ? scheme.primary
                          : scheme.appSubtleText.withValues(alpha: 0.48),
                      shape: BoxShape.circle,
                    ),
                    child: AppPointerTap(
                      onTap: hasText && !widget.isRunning ? _handleSend : null,
                      child: Icon(
                        widget.isRunning
                            ? Icons.hourglass_top_rounded
                            : Icons.arrow_upward_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InputModelSelector extends ConsumerStatefulWidget {
  final AiModelConfig? selectedModel;
  final String label;

  const _InputModelSelector({required this.selectedModel, required this.label});

  @override
  ConsumerState<_InputModelSelector> createState() =>
      _InputModelSelectorState();
}

class _InputModelSelectorState extends ConsumerState<_InputModelSelector> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _entry;

  @override
  void dispose() {
    _hideMenu();
    super.dispose();
  }

  void _hideMenu() {
    _entry?.remove();
    _entry = null;
  }

  void _toggleMenu(List<AiModelConfig> models) {
    if (models.isEmpty) return;
    if (_entry == null) {
      _showModelMenu(models);
    } else {
      _hideMenu();
    }
  }

  Future<void> _selectChoice(_ModelChoice choice) async {
    _hideMenu();
    if (choice.isModelVariant) {
      await ref
          .read(aiModelProvider.notifier)
          .upsert(
            choice.config.copyWith(
              model: choice.model,
              updatedAt: DateTime.now(),
            ),
          );
    } else {
      ref.read(aiModelProvider.notifier).select(choice.config.id);
    }
  }

  void _showModelMenu(List<AiModelConfig> models) {
    final choices = _buildChoices(models);
    final media = MediaQuery.of(context);
    final renderBox = context.findRenderObject() as RenderBox?;
    final targetTopLeft = renderBox?.localToGlobal(Offset.zero) ?? Offset.zero;
    final targetSize = renderBox?.size ?? Size.zero;
    final desiredHeight = math.min(340.0, choices.length * 54.0 + 16.0);
    final spaceAbove = targetTopLeft.dy - media.padding.top;
    final spaceBelow =
        media.size.height -
        targetTopLeft.dy -
        targetSize.height -
        media.padding.bottom;
    final openUp = spaceBelow < desiredHeight + 16 && spaceAbove > spaceBelow;
    final availableHeight = math.max(
      140.0,
      math.min(desiredHeight, (openUp ? spaceAbove : spaceBelow) - 16),
    );
    _entry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _hideMenu,
            ),
          ),
          CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            targetAnchor: openUp ? Alignment.topLeft : Alignment.bottomLeft,
            followerAnchor: openUp ? Alignment.bottomLeft : Alignment.topLeft,
            offset: Offset(0, openUp ? -8 : 8),
            child: Material(
              color: Colors.transparent,
              child: _ModelDropdownMenu(
                choices: choices,
                selectedModel: widget.selectedModel,
                onSelected: _selectChoice,
                maxHeight: availableHeight,
              ),
            ),
          ),
        ],
      ),
    );
    Overlay.of(context).insert(_entry!);
  }

  @override
  Widget build(BuildContext context) {
    final models = ref.watch(aiModelProvider).configs;
    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onTap: () => _toggleMenu(models),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 150),
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.12),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.memory_rounded,
                size: 15,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'PingFang SC',
                    fontFamilyFallback: [
                      '.SF Pro Text',
                      'system-ui',
                      'sans-serif',
                    ],
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 15,
                color: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<_ModelChoice> _buildChoices(List<AiModelConfig> models) {
    final selected = widget.selectedModel;
    final choices = <_ModelChoice>[];
    if (selected != null && selected.provider == 'deepseek') {
      final variants = AiModelCatalogService().fallbackModels('deepseek');
      for (final model in variants) {
        choices.add(
          _ModelChoice(
            config: selected,
            model: model,
            title: model.endsWith('pro') ? 'DeepSeek Pro' : 'DeepSeek Flash',
            subtitle: model,
            isModelVariant: true,
          ),
        );
      }
      for (final config in models.where((item) => item.id != selected.id)) {
        choices.add(_ModelChoice.fromConfig(config));
      }
      return choices;
    }
    return models.map(_ModelChoice.fromConfig).toList();
  }
}

class _ModelDropdownMenu extends StatelessWidget {
  final List<_ModelChoice> choices;
  final AiModelConfig? selectedModel;
  final ValueChanged<_ModelChoice> onSelected;
  final double maxHeight;

  const _ModelDropdownMenu({
    required this.choices,
    required this.selectedModel,
    required this.onSelected,
    required this.maxHeight,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 260,
      constraints: BoxConstraints(maxHeight: maxHeight),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: scheme.appElevatedSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.appBorder.withValues(alpha: 0.76)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ListView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: choices.length,
        itemBuilder: (context, index) {
          final choice = choices[index];
          final selected =
              choice.config.id == selectedModel?.id &&
              choice.model == selectedModel?.model;
          return InkWell(
            onTap: () => onSelected(choice),
            child: Container(
              height: 54,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: selected
                          ? scheme.primary.withValues(alpha: 0.14)
                          : scheme.appInput,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      selected ? Icons.check_rounded : Icons.memory_rounded,
                      size: 16,
                      color: selected ? scheme.primary : scheme.appSubtleText,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          choice.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: selected
                                ? FontWeight.w900
                                : FontWeight.w800,
                            color: selected ? scheme.primary : scheme.appText,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          choice.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.appMutedText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ModelChoice {
  final AiModelConfig config;
  final String model;
  final String title;
  final String subtitle;
  final bool isModelVariant;

  const _ModelChoice({
    required this.config,
    required this.model,
    required this.title,
    required this.subtitle,
    required this.isModelVariant,
  });

  factory _ModelChoice.fromConfig(AiModelConfig config) {
    return _ModelChoice(
      config: config,
      model: config.model,
      title: config.name.isEmpty ? config.provider : config.name,
      subtitle: config.model,
      isModelVariant: false,
    );
  }
}
