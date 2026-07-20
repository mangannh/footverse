import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_typography.dart';

/// Presentation variants for [PriceText] (design/03 §2).
enum PriceVariant {
  /// Product cards, list lines.
  regular,

  /// Order total, cart subtotal.
  emphasis,

  /// Original price beside a discounted one.
  strikethrough,

  /// Dense contexts where a shorter form is needed.
  compact,
}

/// Renders every monetary value in FootVerse (design/03 §2).
///
/// `PriceText` is the **only** widget permitted to use the `price` type role
/// ([design/02 §4.2](../../../../docs/design/02-design-system.md#42-why-price-is-a-separate-step),
/// Decision 6) and the only widget that formats money at all — it never adds,
/// subtracts, multiplies, divides, or otherwise derives a value. [amount] is
/// rendered exactly as delivered by the server (`dto-spec` §1).
///
/// All four variants ([PriceVariant]) format the same [amount] to the
/// **identical digit string** — they differ only in presentation (size,
/// colour, decoration), never in the numeric value shown.
class PriceText extends StatelessWidget {
  const PriceText({
    super.key,
    required this.amount,
    this.variant = PriceVariant.regular,
    this.showCurrency = true,
  });

  /// The amount to display, exactly as delivered by the server.
  final double amount;

  /// The presentation variant. Defaults to [PriceVariant.regular].
  final PriceVariant variant;

  /// Whether the currency symbol is shown. Defaults to `true`.
  final bool showCurrency;

  /// Locale is fixed to match the English interface language
  /// (design/02 §16.1) — never the device locale, so the same amount reads
  /// identically on every phone.
  static const String _locale = 'en_US';

  static const String _currencySymbol = '₫';

  /// The Unicode minus sign, never a hyphen — matches design/03 §2 exactly
  /// and is never conveyed by colour alone (design/02 §12 A-7).
  static const String _negativeSign = '−';

  static const String _currencyName = 'Vietnamese dong';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNegative = amount.isNegative;
    final magnitude = amount.abs();
    final digits = _formatMagnitude(magnitude, showCurrency: showCurrency);
    final display = isNegative ? '$_negativeSign$digits' : digits;

    return Semantics(
      label: _semanticsLabel(magnitude: magnitude, isNegative: isNegative),
      excludeSemantics: true,
      child: Text(
        display,
        style: _styleFor(variant, theme),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  static String _formatMagnitude(
    double magnitude, {
    required bool showCurrency,
  }) {
    final format = showCurrency
        ? NumberFormat.currency(
            locale: _locale,
            symbol: _currencySymbol,
            decimalDigits: 0,
          )
        : NumberFormat('#,##0', _locale);
    return format.format(magnitude);
  }

  static String _semanticsLabel({
    required double magnitude,
    required bool isNegative,
  }) {
    final digits = NumberFormat('#,##0', _locale).format(magnitude);
    final sign = isNegative ? 'minus ' : '';
    return '$sign$digits $_currencyName';
  }

  /// Resolves the [variant]'s style from tokens only — the theme's own
  /// `price` role ([PriceTextStyle], design/02 §4.2) composed with an
  /// existing `textTheme` role's size where a variant needs a different
  /// prominence, and a `colorScheme` role where a variant needs a different
  /// colour (design/02 §4.3: colour only, sourced from a `colorScheme`
  /// role). No literal font size, weight, or colour is ever introduced here.
  static TextStyle? _styleFor(PriceVariant variant, ThemeData theme) {
    final priceStyle = theme.extension<PriceTextStyle>()?.style;
    if (priceStyle == null) {
      return null;
    }
    switch (variant) {
      case PriceVariant.regular:
        return priceStyle;
      case PriceVariant.emphasis:
        return priceStyle.copyWith(
          fontSize: theme.textTheme.headlineMedium?.fontSize,
        );
      case PriceVariant.strikethrough:
        return priceStyle.copyWith(
          decoration: TextDecoration.lineThrough,
          color: theme.colorScheme.onSurfaceVariant,
        );
      case PriceVariant.compact:
        return priceStyle.copyWith(
          fontSize: theme.textTheme.bodySmall?.fontSize,
        );
    }
  }
}
