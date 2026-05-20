import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/question_create/question_draft_controller.dart';
import '../shared/utils/draft_navigation.dart';

class AppShell extends ConsumerWidget {
  const AppShell({
    super.key,
    required this.currentLocation,
    required this.child,
  });

  final String currentLocation;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(questionDraftControllerProvider);

    return Scaffold(
      body: SafeArea(child: child),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex(),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: '首页',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book_rounded),
            label: '错题',
          ),
          NavigationDestination(
            icon: Icon(Icons.edit_note_outlined),
            selectedIcon: Icon(Icons.edit_note_rounded),
            label: '录入',
          ),
          NavigationDestination(
            icon: Icon(Icons.sell_outlined),
            selectedIcon: Icon(Icons.sell_rounded),
            label: '标签',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: '设置',
          ),
        ],
        onDestinationSelected: (index) {
          final route = switch (index) {
            0 => '/dashboard',
            1 => '/questions',
            2 => hasActiveDraft(draft)
                ? routeForDraft(draft!)
                : '/questions/create',
            3 => '/tags',
            _ => '/settings',
          };
          context.go(route);
        },
      ),
    );
  }

  int _selectedIndex() {
    if (currentLocation.startsWith('/settings')) {
      return 4;
    }
    if (currentLocation.startsWith('/tags')) {
      return 3;
    }
    if (currentLocation.startsWith('/questions/create') ||
        currentLocation.startsWith('/questions/upload') ||
        currentLocation.startsWith('/questions/ocr-review') ||
        currentLocation.startsWith('/questions/ai-review')) {
      return 2;
    }
    if (currentLocation.startsWith('/questions')) {
      return 1;
    }
    return 0;
  }
}
