import 'package:flutter_test/flutter_test.dart';
import 'package:ai_assistant/features/copilot/copilot_settings.dart';

void main() {
  group('Copilot persona presets', () {
    test('provides four built-in styles plus custom mode', () {
      expect(CopilotPersonaCatalog.presets.map((item) => item.label), [
        '活泼',
        '稳重',
        '温柔',
        '严肃',
      ]);
      expect(CopilotPersonaCatalog.customValue, 'custom');
    });

    test('preset prompts contain style-specific guidance', () {
      final prompts = {
        for (final item in CopilotPersonaCatalog.presets)
          item.label: item.prompt,
      };

      expect(prompts['活泼'], contains('轻快'));
      expect(prompts['活泼'], contains('俏皮'));
      expect(prompts['稳重'], contains('冷静'));
      expect(prompts['稳重'], contains('风险'));
      expect(prompts['温柔'], contains('柔和'));
      expect(prompts['温柔'], contains('节奏'));
      expect(prompts['严肃'], contains('直接'));
      expect(prompts['严肃'], contains('少寒暄'));
    });

    test('custom text remains custom after storage migration', () {
      final settings = CopilotSettings.fromJson({
        'assistantName': 'MyAssistant',
        'assistantAvatar': '✦',
        'persona': '我的自定义风格：短句，直接，少废话。',
      });

      expect(settings.displayPersonaStyle, CopilotPersonaCatalog.customValue);
      expect(settings.displayPersona, contains('自定义风格'));
    });

    test('default prompt is the gentle persona', () {
      expect(CopilotSettings.defaultPersona, contains('温柔'));
      expect(
        CopilotPersonaCatalog.defaultPromptOf('gentle'),
        CopilotSettings.defaultPersona,
      );
    });
  });
}
