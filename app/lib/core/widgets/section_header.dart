import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// A section title with an optional trailing action (design/03 §12) —
/// replaces ad-hoc `Text` widgets scattered across long screens.
///
/// Establishes the vertical rhythm itself (`AppSpacing.lg` above,
/// `AppSpacing.sm` below), so every screen that composes it scans
/// consistently without having to remember the spacing.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.action,
    this.onAction,
  });

  final String title;

  /// The trailing action's label. Rendered only when [onAction] is also
  /// given.
  final String? action;

  /// The trailing action's callback. Rendered only when [action] is also
  /// given.
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final action = this.action;
    final onAction = this.onAction;
    final hasAction = action != null && onAction != null;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (hasAction)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                minimumSize: const Size(AppSpacing.xxl, AppSpacing.xxl),
              ),
              child: Text(action),
            ),
        ],
      ),
    );
  }
}
