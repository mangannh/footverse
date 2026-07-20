import 'package:flutter/material.dart';

import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

/// The primary call-to-action (design/03 §1).
///
/// **Exactly one per screen**, spans full content width. Enforces the
/// loading contract: while [loading] is `true`, the label is replaced by an
/// in-button spinner, the button disables, and — because the button is
/// always wrapped at [double.infinity] width — its rendered **width never
/// changes** between idle and loading (design/02 §14; the exact defect that
/// moves a control under a finger mid-tap).
class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  /// The action, phrased as a verb ("Add to cart", not "OK").
  final String label;

  /// `null` disables the button, exactly like a plain [FilledButton].
  final VoidCallback? onPressed;

  /// While `true`, shows an in-button spinner and disables the button —
  /// single-flight, matching the `isMutating` pattern already used by the
  /// providers.
  final bool loading;

  static const double _spinnerSize = 20;

  @override
  Widget build(BuildContext context) {
    final onPressed = this.onPressed;
    final enabled = !loading && onPressed != null;

    return Semantics(
      label: label,
      button: true,
      enabled: enabled,
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: enabled ? onPressed : null,
          style: FilledButton.styleFrom(
            minimumSize: const Size(AppSpacing.xxl, AppSpacing.xxl),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
          ),
          child: loading
              ? const ExcludeSemantics(
                  child: SizedBox(
                    height: _spinnerSize,
                    width: _spinnerSize,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : ExcludeSemantics(child: Text(label)),
        ),
      ),
    );
  }
}

/// A destructive action — **always requires confirmation** at the call
/// site before this button's [onPressed] fires (design/03 §1). Coloured
/// with the `error` role so the destructive weight is visible without
/// depending on the label text alone.
class AppDestructiveButton extends StatelessWidget {
  const AppDestructiveButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  /// The action, phrased as a verb ("Delete address", not "OK").
  final String label;

  /// `null` disables the button.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: colorScheme.error,
        foregroundColor: colorScheme.onError,
        minimumSize: const Size(AppSpacing.xxl, AppSpacing.xxl),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
      child: Text(label),
    );
  }
}
