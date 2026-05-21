import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

bool usesCupertinoModals(BuildContext context) {
  final platform = Theme.of(context).platform;
  return platform == TargetPlatform.iOS;
}

class PlatformActionSheetAction<T> {
  const PlatformActionSheetAction({
    required this.label,
    required this.value,
    this.icon,
    this.isDefault = false,
    this.isDestructive = false,
  });

  final String label;
  final T value;
  final IconData? icon;
  final bool isDefault;
  final bool isDestructive;
}

Future<bool> showPlatformConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = '取消',
  bool isDestructive = false,
}) async {
  if (usesCupertinoModals(context)) {
    final result = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return CupertinoAlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(cancelLabel),
            ),
            CupertinoDialogAction(
              isDestructiveAction: isDestructive,
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(cancelLabel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );

  return result ?? false;
}

Future<T?> showPlatformActionSheet<T>({
  required BuildContext context,
  String? title,
  String? message,
  required List<PlatformActionSheetAction<T>> actions,
  String cancelLabel = '取消',
}) {
  if (usesCupertinoModals(context)) {
    return showCupertinoModalPopup<T>(
      context: context,
      builder: (sheetContext) {
        return CupertinoActionSheet(
          title: title == null ? null : Text(title),
          message: message == null ? null : Text(message),
          actions: [
            for (final action in actions)
              CupertinoActionSheetAction(
                isDefaultAction: action.isDefault,
                isDestructiveAction: action.isDestructive,
                onPressed: () => Navigator.of(sheetContext).pop(action.value),
                child: Text(action.label),
              ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(sheetContext).pop(),
            child: Text(cancelLabel),
          ),
        );
      },
    );
  }

  return showModalBottomSheet<T>(
    context: context,
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final action in actions)
              ListTile(
                leading: action.icon == null ? null : Icon(action.icon),
                title: Text(action.label),
                onTap: () => Navigator.of(sheetContext).pop(action.value),
              ),
            ListTile(
              title: Text(
                cancelLabel,
                style: Theme.of(sheetContext).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(sheetContext).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              onTap: () => Navigator.of(sheetContext).pop(),
            ),
          ],
        ),
      );
    },
  );
}

Future<T?> showPlatformModalSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
}) {
  if (usesCupertinoModals(context)) {
    final inheritedTheme = Theme.of(context);
    return showCupertinoModalPopup<T>(
      context: context,
      builder: (sheetContext) {
        final mediaQuery = MediaQuery.of(sheetContext);
        final bottomSafeArea = math.max(
          12,
          mediaQuery.padding.bottom,
        );

        return Material(
          color: Colors.transparent,
          child: SafeArea(
            top: false,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: AnimatedPadding(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: EdgeInsets.fromLTRB(
                  12,
                  12,
                  12,
                  bottomSafeArea + mediaQuery.viewInsets.bottom,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Material(
                    color: inheritedTheme.colorScheme.surface,
                    child: builder(sheetContext),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    showDragHandle: true,
    useSafeArea: true,
    builder: builder,
  );
}
