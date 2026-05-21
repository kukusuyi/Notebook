import 'dart:math' as math;
import 'dart:ui';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/question_create/question_draft_controller.dart';
import '../shared/models/question_models.dart';
import '../shared/utils/draft_navigation.dart';

final _iosMajorVersionProvider = FutureProvider<int?>((ref) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
    return null;
  }

  final info = await DeviceInfoPlugin().iosInfo;
  return int.tryParse(info.systemVersion.split('.').first);
});

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
    final platform = Theme.of(context).platform;
    final useLiquidGlassTabBar =
        platform == TargetPlatform.iOS &&
        ref.watch(_iosMajorVersionProvider).maybeWhen(
              data: (major) => (major ?? 0) >= 26,
              loading: () => true,
              orElse: () => false,
            );
    final selectedIndex = _selectedIndex();
    final destinations = _destinations;

    return Scaffold(
      extendBody: useLiquidGlassTabBar,
      body: child,
      bottomNavigationBar: useLiquidGlassTabBar
          ? _IosLiquidGlassTabBar(
              selectedIndex: selectedIndex,
              destinations: destinations,
              onDestinationSelected: (index) =>
                  _goToDestination(context, draft, index),
            )
          : NavigationBar(
              selectedIndex: selectedIndex,
              destinations: [
                for (final destination in destinations)
                  NavigationDestination(
                    icon: Icon(destination.icon),
                    selectedIcon: Icon(destination.selectedIcon),
                    label: destination.label,
                  ),
              ],
              onDestinationSelected: (index) =>
                  _goToDestination(context, draft, index),
            ),
    );
  }

  void _goToDestination(
    BuildContext context,
    QuestionDraft? draft,
    int index,
  ) {
    final route = switch (index) {
      0 => '/dashboard',
      1 => '/questions',
      2 => hasActiveDraft(draft) ? routeForDraft(draft!) : '/questions/create',
      3 => '/tags',
      _ => '/settings',
    };
    context.go(route);
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

const _destinations = <_ShellDestination>[
  _ShellDestination(
    label: '首页',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
  ),
  _ShellDestination(
    label: '错题',
    icon: Icons.menu_book_outlined,
    selectedIcon: Icons.menu_book_rounded,
  ),
  _ShellDestination(
    label: '录入',
    icon: Icons.edit_note_outlined,
    selectedIcon: Icons.edit_note_rounded,
  ),
  _ShellDestination(
    label: '标签',
    icon: Icons.sell_outlined,
    selectedIcon: Icons.sell_rounded,
  ),
  _ShellDestination(
    label: '设置',
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings_rounded,
  ),
];

class _ShellDestination {
  const _ShellDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class _IosLiquidGlassTabBar extends StatelessWidget {
  const _IosLiquidGlassTabBar({
    required this.selectedIndex,
    required this.destinations,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final List<_ShellDestination> destinations;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return SafeArea(
      top: false,
      minimum: EdgeInsets.fromLTRB(16, 0, 16, math.max(8, safeBottom * 0.28)),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withOpacity(0.06),
              blurRadius: 24,
              spreadRadius: -2,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(0.70),
                    Colors.white.withOpacity(0.42),
                  ],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withOpacity(0.68),
                  width: 0.9,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final itemWidth =
                        (constraints.maxWidth - ((destinations.length - 1) * 8)) /
                        destinations.length;

                    return Stack(
                      children: [
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 0,
                          child: IgnorePointer(
                            child: Container(
                              height: 1.2,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withOpacity(0.0),
                                    Colors.white.withOpacity(0.88),
                                    Colors.white.withOpacity(0.0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 320),
                          curve: Curves.easeOutCubic,
                          left: (itemWidth + 8) * selectedIndex,
                          top: 4,
                          width: itemWidth,
                          height: 50,
                          child: IgnorePointer(
                            child: _IosLiquidSelectionCapsule(
                              colorScheme: colorScheme,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            for (var index = 0; index < destinations.length; index++)
                              Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    left: index == 0 ? 0 : 4,
                                    right: index == destinations.length - 1 ? 0 : 4,
                                  ),
                                  child: _IosLiquidGlassTabItem(
                                    destination: destinations[index],
                                    selected: index == selectedIndex,
                                    onTap: () => onDestinationSelected(index),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IosLiquidSelectionCapsule extends StatelessWidget {
  const _IosLiquidSelectionCapsule({
    required this.colorScheme,
  });

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.72),
            colorScheme.primaryContainer.withOpacity(0.68),
            colorScheme.secondaryContainer.withOpacity(0.52),
          ],
          stops: const [0.0, 0.52, 1.0],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.78),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.10),
            blurRadius: 12,
            spreadRadius: -3,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 10,
            right: 10,
            top: 5,
            child: Container(
              height: 10,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(0.82),
                    Colors.white.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: 14,
            top: 9,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withOpacity(0.72),
                    Colors.white.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IosLiquidGlassTabItem extends StatelessWidget {
  const _IosLiquidGlassTabItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _ShellDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foregroundColor = selected
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurface.withOpacity(0.70);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              color: selected ? Colors.transparent : Colors.white.withOpacity(0.08),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  selected ? destination.selectedIcon : destination.icon,
                  size: 21,
                  color: foregroundColor,
                ),
                const SizedBox(height: 3),
                Text(
                  destination.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foregroundColor,
                    fontSize: 10.5,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    letterSpacing: 0.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
