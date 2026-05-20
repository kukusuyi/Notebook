import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/question_models.dart';

class QuestionJsonEditor extends StatelessWidget {
  const QuestionJsonEditor({
    super.key,
    required this.controller,
    required this.onChanged,
    this.errorText,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'JSON 结构需包含 `question_core`、`standard_solution`、`wrong_solution`。',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: controller,
          minLines: 14,
          maxLines: 20,
          decoration: InputDecoration(
            labelText: 'Question JSON',
            alignLabelWithHint: true,
            errorText: errorText,
          ),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
              ),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

QuestionJson? tryParseQuestionJson(String raw) {
  final normalized = raw.trim();
  if (normalized.isEmpty) {
    return const QuestionJson();
  }

  final decoded = jsonDecode(normalized);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('JSON 必须是对象');
  }

  return QuestionJson.fromJson(decoded);
}

String formatQuestionJson(QuestionJson value) {
  const encoder = JsonEncoder.withIndent('  ');
  return encoder.convert(value.toJson());
}

