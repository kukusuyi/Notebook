import 'package:flutter/material.dart';

class TagGroupsEditor extends StatelessWidget {
  const TagGroupsEditor({
    super.key,
    required this.knowledgePointsController,
    required this.problemTypeController,
    required this.methodController,
    required this.mistakeReasonController,
    required this.onChanged,
  });

  final TextEditingController knowledgePointsController;
  final TextEditingController problemTypeController;
  final TextEditingController methodController;
  final TextEditingController mistakeReasonController;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextFormField(
          controller: knowledgePointsController,
          decoration: const InputDecoration(
            labelText: '知识点（逗号分隔）',
          ),
          onChanged: (_) => onChanged(),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: problemTypeController,
          decoration: const InputDecoration(
            labelText: '题型（逗号分隔）',
          ),
          onChanged: (_) => onChanged(),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: methodController,
          decoration: const InputDecoration(
            labelText: '解题方法（逗号分隔）',
          ),
          onChanged: (_) => onChanged(),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: mistakeReasonController,
          decoration: const InputDecoration(
            labelText: '错误原因（逗号分隔）',
          ),
          onChanged: (_) => onChanged(),
        ),
      ],
    );
  }
}
