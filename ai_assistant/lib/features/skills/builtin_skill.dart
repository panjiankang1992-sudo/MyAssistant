import 'package:flutter/material.dart';

class BuiltinSkill {
  final String id;
  final String name;
  final String summary;
  final String description;
  final String inputSchema;
  final String outputSchema;
  final String prompt;
  final IconData icon;
  final Color color;

  const BuiltinSkill({
    required this.id,
    required this.name,
    required this.summary,
    required this.description,
    required this.inputSchema,
    required this.outputSchema,
    required this.prompt,
    required this.icon,
    required this.color,
  });

  String get copilotLine =>
      '$id: $name。$summary。输入：$inputSchema。输出：$outputSchema。';
}
