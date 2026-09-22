import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/question_create/question_draft_controller.dart';
import '../utils/draft_navigation.dart';

class DraftPageScope extends ConsumerStatefulWidget {
  const DraftPageScope({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<DraftPageScope> createState() => _DraftPageScopeState();
}

class _DraftPageScopeState extends ConsumerState<DraftPageScope> {
  bool _leaving = false;
  @override
  Widget build(BuildContext context) => PopScope(
        canPop: _leaving ||
            !hasActiveDraft(ref.watch(questionDraftControllerProvider)),
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop || _leaving) return;
          final choice = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                      title: const Text('保留这份草稿？'),
                      content: const Text('离开后可以从学习概览继续整理。'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('放弃草稿')),
                        FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('保留并离开'))
                      ]));
          if (choice == null || !mounted) return;
          final controller = ref.read(questionDraftControllerProvider.notifier);
          if (!choice) controller.clear();
          await controller.flush();
          if (!mounted) return;
          setState(() => _leaving = true);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/dashboard');
              }
            }
          });
        },
        child: widget.child,
      );
}
