import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// Builds the application [ThemeData] — the **only** place a [ColorScheme]
/// is constructed anywhere in FootVerse (design/02 §2.2, §1).
///
/// [AppTheme] is structured around a private [Brightness]-parameterised
/// builder so the deferred dark theme (design/02 §10.3) is an addition —
/// `AppTheme.dark()` reusing [_build] — rather than a refactor. Sprint 14
/// ships [light] only; `app.dart` declares `theme:` alone, with no
/// `darkTheme` and no `themeMode` (design/02 §10, Decision 5).
class AppTheme {
  const AppTheme._();

  /// The light theme (design/02 §10.3: `AppTheme.light()`, `fromSeed(seed)`).
  static ThemeData light() => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.seed,
      brightness: brightness,
    );

    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: AppTypography.textTheme(
        Typography.englishLike2021,
        colorScheme.onSurface,
      ),
    );

    // The `price` type role has no Material 3 slot, so it is derived once
    // here from the theme's own `titleMedium` — which, after
    // `AppTypography.textTheme`, already carries `colorScheme.onSurface` —
    // and carried as the theme's one ThemeExtension (design/02 §4.2).
    return theme.copyWith(extensions: [PriceTextStyle.from(theme.textTheme)]);
  }
}
