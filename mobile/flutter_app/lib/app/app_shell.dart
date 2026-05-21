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
import 'tab_navigation_intent.dart';

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
    required this.tabNavigationIntent,
    required this.child,
  });

  final String currentLocation;
  final TabNavigationIntent? tabNavigationIntent;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(questionDraftControllerProvider);
    final platform = Theme.of(context).platform;
    final mediaQuery = MediaQuery.of(context);
    final useLiquidGlassTabBar =
        platform == TargetPlatform.iOS &&
        ref.watch(_iosMajorVersionProvider).maybeWhen(
              data: (major) => (major ?? 0) >= 26,
              loading: () => true,
              orElse: () => false,
            );
    final bodyBottomInset = useLiquidGlassTabBar
        ? _liquidTabBarReservedHeight(mediaQuery)
        : 0.0;
    final selectedIndex = _selectedIndex();
    final destinations = _destinations;
    final allowTabBarHorizontalSwipe = useLiquidGlassTabBar;
    final allowBodyHorizontalSwipe =
        useLiquidGlassTabBar && _supportsBodyHorizontalTabSwipe();

    return Scaffold(
      extendBody: useLiquidGlassTabBar,
      body: _ShellBodyTransition(
        currentLocation: currentLocation,
        tabNavigationIntent: tabNavigationIntent,
        allowHorizontalTabSwipe: allowBodyHorizontalSwipe,
        bottomInset: bodyBottomInset,
        onHorizontalTabSwipe: (delta) => _goToAdjacentDestination(
          context,
          draft,
          selectedIndex,
          delta,
        ),
        child: child,
      ),
      bottomNavigationBar: useLiquidGlassTabBar
          ? _IosLiquidGlassTabBar(
              selectedIndex: selectedIndex,
              destinations: destinations,
              enableHorizontalSwipe: allowTabBarHorizontalSwipe,
              onDestinationSelected: (index) =>
                  _goToDestination(context, draft, index),
              onHorizontalSwipe: (delta) => _goToAdjacentDestination(
                context,
                draft,
                selectedIndex,
                delta,
              ),
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
    context.go(
      route,
      extra: TabNavigationIntent(
        fromIndex: _selectedIndex(),
        toIndex: index,
      ),
    );
  }

  void _goToAdjacentDestination(
    BuildContext context,
    QuestionDraft? draft,
    int currentIndex,
    int delta,
  ) {
    final nextIndex = (currentIndex + delta).clamp(0, _destinations.length - 1);
    if (nextIndex == currentIndex) {
      return;
    }

    _goToDestination(context, draft, nextIndex);
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

  bool _supportsBodyHorizontalTabSwipe() {
    return currentLocation == '/dashboard' ||
        currentLocation == '/questions' ||
        currentLocation == '/tags' ||
        currentLocation == '/settings';
  }

  double _liquidTabBarReservedHeight(MediaQueryData mediaQuery) {
    return 104 + math.max(8, mediaQuery.padding.bottom * 0.28);
  }
}

class _ShellBodyTransition extends StatefulWidget {
  const _ShellBodyTransition({
    required this.currentLocation,
    required this.tabNavigationIntent,
    required this.allowHorizontalTabSwipe,
    required this.bottomInset,
    required this.onHorizontalTabSwipe,
    required this.child,
  });

  final String currentLocation;
  final TabNavigationIntent? tabNavigationIntent;
  final bool allowHorizontalTabSwipe;
  final double bottomInset;
  final ValueChanged<int> onHorizontalTabSwipe;
  final Widget child;

  @override
  State<_ShellBodyTransition> createState() => _ShellBodyTransitionState();
}

class _ShellBodyTransitionState extends State<_ShellBodyTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Widget? _outgoingChild;
  Widget? _incomingChild;
  int _direction = 1;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() {
            _outgoingChild = null;
            _incomingChild = null;
          });
        }
      });
  }

  @override
  void didUpdateWidget(covariant _ShellBodyTransition oldWidget) {
    super.didUpdateWidget(oldWidget);

    final intent = widget.tabNavigationIntent;
    final shouldAnimate =
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.iOS &&
        intent != null &&
        intent.fromIndex != intent.toIndex &&
        widget.currentLocation != oldWidget.currentLocation;

    if (!shouldAnimate) {
      _outgoingChild = null;
      _incomingChild = null;
      _controller.stop();
      return;
    }

    _direction = intent.toIndex > intent.fromIndex ? 1 : -1;
    _outgoingChild = KeyedSubtree(
      key: ValueKey<String>('outgoing:${oldWidget.currentLocation}'),
      child: oldWidget.child,
    );
    _incomingChild = KeyedSubtree(
      key: ValueKey<String>('incoming:${widget.currentLocation}'),
      child: widget.child,
    );
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final incomingChild = _incomingChild;
    final outgoingChild = _outgoingChild;
    final swipeEnabled =
        widget.allowHorizontalTabSwipe &&
        incomingChild == null &&
        outgoingChild == null;

    if (incomingChild == null || outgoingChild == null) {
      return _TabSwipeDetector(
        enabled: swipeEnabled,
        onSwipe: widget.onHorizontalTabSwipe,
        child: _ShellBodyInset(
          bottomInset: widget.bottomInset,
          child: KeyedSubtree(
            key: ValueKey<String>('static:${widget.currentLocation}'),
            child: widget.child,
          ),
        ),
      );
    }

    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    final reverseDirection = -_direction.toDouble();

    return _TabSwipeDetector(
      enabled: false,
      onSwipe: widget.onHorizontalTabSwipe,
      child: ClipRect(
        child: AnimatedBuilder(
          animation: curved,
          builder: (context, _) {
            return Stack(
              fit: StackFit.expand,
              children: [
                FractionalTranslation(
                  translation: Offset(curved.value * reverseDirection, 0),
                  child: _ShellBodyInset(
                    bottomInset: widget.bottomInset,
                    child: outgoingChild,
                  ),
                ),
                FractionalTranslation(
                  translation: Offset((1 - curved.value) * _direction, 0),
                  child: _ShellBodyInset(
                    bottomInset: widget.bottomInset,
                    child: incomingChild,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ShellBodyInset extends StatelessWidget {
  const _ShellBodyInset({
    required this.bottomInset,
    required this.child,
  });

  final double bottomInset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (bottomInset <= 0) {
      return child;
    }

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: child,
    );
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
    required this.enableHorizontalSwipe,
    required this.onDestinationSelected,
    required this.onHorizontalSwipe,
  });

  final int selectedIndex;
  final List<_ShellDestination> destinations;
  final bool enableHorizontalSwipe;
  final ValueChanged<int> onDestinationSelected;
  final ValueChanged<int> onHorizontalSwipe;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return _TabSwipeDetector(
      enabled: enableHorizontalSwipe,
      onSwipe: onHorizontalSwipe,
      child: SafeArea(
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
      ),
    );
  }
}

class _TabSwipeDetector extends StatefulWidget {
  const _TabSwipeDetector({
    required this.enabled,
    required this.onSwipe,
    required this.child,
  });

  final bool enabled;
  final ValueChanged<int> onSwipe;
  final Widget child;

  @override
  State<_TabSwipeDetector> createState() => _TabSwipeDetectorState();
}

class _TabSwipeDetectorState extends State<_TabSwipeDetector> {
  static const double _minDragDistance = 44;
  static const double _minDragVelocity = 240;

  double _dragDistance = 0;

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (_) {
        _dragDistance = 0;
      },
      onHorizontalDragUpdate: (details) {
        _dragDistance += details.primaryDelta ?? 0;
      },
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        final dragDistance = _dragDistance;
        _dragDistance = 0;

        if (!_didCrossSwipeThreshold(dragDistance, velocity)) {
          return;
        }

        if (dragDistance < 0 || velocity < -_minDragVelocity) {
          widget.onSwipe(1);
          return;
        }

        if (dragDistance > 0 || velocity > _minDragVelocity) {
          widget.onSwipe(-1);
        }
      },
      onHorizontalDragCancel: () {
        _dragDistance = 0;
      },
      child: widget.child,
    );
  }

  bool _didCrossSwipeThreshold(double dragDistance, double velocity) {
    return dragDistance.abs() >= _minDragDistance ||
        velocity.abs() >= _minDragVelocity;
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
