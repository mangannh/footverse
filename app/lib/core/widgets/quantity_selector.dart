import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// A +/− quantity control (design/03 §9), extracted from the private
/// `_QuantityStepper` in `cart_line_tile.dart` — same behaviour, restored
/// touch targets.
///
/// **No optimistic updates** (ratified — design/03 §9): the caller passes
/// `null` for [onIncrement]/[onDecrement] while a mutation is in flight, and
/// [enabled] additionally covers the whole-control disable during that
/// window. The decrement is defensively disabled whenever [quantity] is `1`
/// **regardless of what [onDecrement] is passed** — removal is a separate,
/// explicit action; decrementing must never delete a line.
class QuantitySelector extends StatelessWidget {
  const QuantitySelector({
    super.key,
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
    required this.enabled,
  });

  /// The current quantity, rendered verbatim.
  final int quantity;

  /// `null` disables increment (e.g. no more stock).
  final VoidCallback? onIncrement;

  /// `null` disables decrement. Ignored at `quantity == 1` — decrement is
  /// disabled there regardless.
  final VoidCallback? onDecrement;

  /// `false` while a mutation is in flight, disabling the whole control.
  final bool enabled;

  /// The digit column's width — wide enough that a quantity going from one
  /// digit to two (9 → 10) never reflows the surrounding row.
  static const double _digitColumnWidth = AppSpacing.xxl;

  @override
  Widget build(BuildContext context) {
    final decrementEnabled = enabled && quantity > 1 && onDecrement != null;
    final incrementEnabled = enabled && onIncrement != null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepButton(
          icon: Icons.remove,
          tooltip: 'Decrease quantity',
          onPressed: decrementEnabled ? onDecrement : null,
        ),
        SizedBox(
          width: _digitColumnWidth,
          child: Text(
            '$quantity',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        _StepButton(
          icon: Icons.add,
          tooltip: 'Increase quantity',
          onPressed: incrementEnabled ? onIncrement : null,
        ),
      ],
    );
  }
}

/// One +/− step button — a fixed 48 dp tap target regardless of the glyph's
/// visual size (design/03 §9 accessibility: the tap area must be restored
/// even if the glyph stays small).
class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: AppSpacing.xxl,
      height: AppSpacing.xxl,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon),
        tooltip: tooltip,
        padding: EdgeInsets.zero,
      ),
    );
  }
}
