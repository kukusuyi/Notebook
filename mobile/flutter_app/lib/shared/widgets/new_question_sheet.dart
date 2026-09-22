import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/question_create/question_draft_controller.dart';
import '../utils/draft_navigation.dart';

Future<void> showNewQuestionSheet(BuildContext context, WidgetRef ref) async {
  final draft = ref.read(questionDraftControllerProvider);
  final choice = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      builder: (context) => SafeArea(
          child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('新增错题', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    ListTile(
                        leading: const Icon(Icons.add_photo_alternate_outlined),
                        title: const Text('图片录入'),
                        subtitle: const Text('拍照或选择图片，识别或手动整理'),
                        onTap: () => Navigator.pop(context, 'upload')),
                    ListTile(
                        leading: const Icon(Icons.edit_note_outlined),
                        title: const Text('手动录入'),
                        subtitle: const Text('填写题目，直接保存'),
                        onTap: () => Navigator.pop(context, 'manual')),
                    if (hasActiveDraft(draft))
                      ListTile(
                          leading: const Icon(Icons.history),
                          title: const Text('继续上次草稿'),
                          onTap: () => Navigator.pop(context, 'resume')),
                  ]))));
  if (choice == null || !context.mounted) return;
  if (hasActiveDraft(draft)) {
    if (choice == 'resume') {
      context.push(routeForDraft(draft!));
      return;
    }
    final replace = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('已有未完成草稿'),
                content: const Text('继续整理草稿，或放弃后开始新的错题。'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('继续草稿')),
                  TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('放弃并新建'))
                ]));
    if (!context.mounted || replace == null) return;
    if (!replace) {
      context.push(routeForDraft(draft!));
      return;
    }
    ref.read(questionDraftControllerProvider.notifier).clear();
    await ref.read(questionDraftControllerProvider.notifier).flush();
    if (!context.mounted) return;
  }
  if (choice == 'manual')
    ref.read(questionDraftControllerProvider.notifier).ensureManualDraft();
  context.push(choice == 'upload' ? '/questions/upload' : '/questions/create');
}
