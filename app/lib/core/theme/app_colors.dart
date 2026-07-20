import 'package:flutter/material.dart';

/// Brand color seed for FootVerse (design/02 §2.2).
///
/// Material 3 derives the full [ColorScheme] from [seed] in [AppTheme]; only
/// the brand source color is defined here. Widgets never construct a [Color]
/// directly — they consume `Theme.of(context).colorScheme` roles
/// (design/02 §2.3).
class AppColors {
  const AppColors._();

  /// Deep desaturated ink — a neutral-led seed with a single accent
  /// (design/02 §2.1, §2.2). Replaces the retired saturated green
  /// `Color(0xFF2E7D32)`, which competed with the merchandise and collided
  /// with the "in stock" success signal.
  static const Color seed = Color(0xFF243447);
}
