import 'package:flutter/material.dart';

/// Typography for FootVerse — the six-role type ramp (design/02 §4).
///
/// Widgets reference the **role**, not the Material style name, by reading
/// `Theme.of(context).textTheme`. Five of the six roles are a weight
/// adjustment on top of the Material 3 (2021) English-like geometry, so they
/// live directly on [TextTheme] — no [ThemeExtension] is introduced for a
/// value Material 3 already models (design/02 §1):
///
/// | Role     | `TextTheme` member | Weight |
/// |----------|---------------------|--------|
/// | display  | `headlineMedium`    | 600    |
/// | title    | `titleMedium`       | 600    |
/// | body     | `bodyMedium`        | 400    |
/// | label    | `labelLarge`        | 500    |
/// | caption  | `bodySmall`         | 400    |
///
/// The sixth role, `price`, has no Material 3 slot — it needs tabular
/// figures and a fixed weight distinct from `title`, which also sits on
/// `titleMedium`. It is exposed through [PriceTextStyle], the one
/// [ThemeExtension] this theme defines (design/02 §4.2).
class AppTypography {
  const AppTypography._();

  /// Builds the application [TextTheme] from the Material 3 baseline,
  /// applying the role weights above and a uniform default text [color].
  ///
  /// [base] (`Typography.englishLike2021`) is a **reference**-tier value
  /// (design/02 §1): every one of its styles ships with `inherit: false` and
  /// no `color` — it is never meant to be read directly. Left uncoloured,
  /// two things break: `ThemeData`'s own construction step,
  /// `defaultTextTheme.merge(textTheme)`, discards the colour-scheme-derived
  /// default outright (`TextStyle.merge` short-circuits to `return other`
  /// whenever `other.inherit == false` — see `TextStyle.merge` in the
  /// framework), and a `RenderParagraph` painted with a null, non-inheriting
  /// colour falls through to the engine's raw paragraph default, which
  /// paints **white regardless of theme**. That is the exact cause of the
  /// near-invisible text regression on `ProductCard` (and anywhere else a
  /// widget read `Theme.of(context).textTheme.*` without its own explicit
  /// colour override).
  ///
  /// [TextTheme.apply] gives every role — not just the five this ramp
  /// customises — an explicit colour, so `Theme.of(context).textTheme.*` is
  /// legible on its own everywhere in the app. Call sites still `copyWith`
  /// colour only to reach a genuinely *different* role (design/02 §4.3 Rule
  /// 1) — `onSurfaceVariant` for secondary text, `error` for errors, etc.
  static TextTheme textTheme(TextTheme base, Color color) {
    return base
        .copyWith(
          headlineMedium: base.headlineMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          bodyMedium: base.bodyMedium?.copyWith(fontWeight: FontWeight.w400),
          labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w500),
          bodySmall: base.bodySmall?.copyWith(fontWeight: FontWeight.w400),
        )
        .apply(bodyColor: color, displayColor: color);
  }
}

/// The `price` type role (design/02 §4.2) — the only [ThemeExtension] in the
/// theme, because Material 3 has no slot for tabular-figure monetary text.
///
/// `PriceText` ([design/03 §2](../../../../docs/design/03-component-library.md))
/// is the only widget permitted to read [style] (design/02 Decision 6).
@immutable
class PriceTextStyle extends ThemeExtension<PriceTextStyle> {
  const PriceTextStyle({required this.style});

  /// Builds the price style from the theme's `titleMedium`: weight 700 and
  /// tabular figures, so digits are equal-width and prices align vertically
  /// in a list.
  factory PriceTextStyle.from(TextTheme textTheme) {
    final base = textTheme.titleMedium ?? const TextStyle();
    return PriceTextStyle(
      style: base.copyWith(
        fontWeight: FontWeight.w700,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }

  final TextStyle style;

  @override
  PriceTextStyle copyWith({TextStyle? style}) {
    return PriceTextStyle(style: style ?? this.style);
  }

  @override
  PriceTextStyle lerp(ThemeExtension<PriceTextStyle>? other, double t) {
    if (other is! PriceTextStyle) {
      return this;
    }
    return PriceTextStyle(
      style: TextStyle.lerp(style, other.style, t) ?? style,
    );
  }
}
