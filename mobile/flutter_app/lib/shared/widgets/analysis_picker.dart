import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/question_create/question_draft_controller.dart';
import 'ai_model_selector_card.dart';

Future<bool> showAnalysisPicker(BuildContext context) async =>
    await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) => Consumer(builder: (context, ref, _) {
              final draft = ref.watch(questionDraftControllerProvider);
              final controller =
                  ref.read(questionDraftControllerProvider.notifier);
              return SafeArea(
                  child: SingleChildScrollView(
                      child: Padding(
                          padding: EdgeInsets.fromLTRB(20, 20, 20,
                              20 + MediaQuery.viewInsetsOf(context).bottom),
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('AI 辅助分析',
                                    style:
                                        Theme.of(context).textTheme.titleLarge),
                                const SizedBox(height: 12),
                                const Text('选择模型生成建议。结果由你确认后再保存。'),
                                const SizedBox(height: 16),
                                AIModelSelectorCard(
                                    providerName: draft?.providerName ?? '',
                                    modelName: draft?.modelName ?? '',
                                    onProviderChanged: (v) =>
                                        controller.updateAIModelSelection(
                                            providerName: v,
                                            modelName: draft?.modelName ?? ''),
                                    onModelChanged: (v) =>
                                        controller.updateAIModelSelection(
                                            providerName:
                                                draft?.providerName ?? '',
                                            modelName: v)),
                                const SizedBox(height: 20),
                                SizedBox(
                                    width: double.infinity,
                                    child: FilledButton(
                                        onPressed: draft != null &&
                                                draft.providerName.isNotEmpty &&
                                                draft.modelName.isNotEmpty
                                            ? () => Navigator.pop(context, true)
                                            : null,
                                        child: const Text('生成分析建议'))),
                              ]))));
            })) ??
    false;
