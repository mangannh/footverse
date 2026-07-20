import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:footverse/core/theme/app_colors.dart';
import 'package:footverse/core/theme/app_theme.dart';
import 'package:footverse/core/theme/app_typography.dart';

void main() {
  group('AppTheme.light() (design/02 §1, §2.2, §10.3)', () {
    test('uses Material 3', () {
      expect(AppTheme.light().useMaterial3, isTrue);
    });

    test('colorScheme is generated from AppColors.seed', () {
      final theme = AppTheme.light();
      final expected = ColorScheme.fromSeed(
        seedColor: AppColors.seed,
        brightness: Brightness.light,
      );

      expect(theme.colorScheme.primary, expected.primary);
      expect(theme.colorScheme.surface, expected.surface);
      expect(theme.colorScheme.brightness, Brightness.light);
    });

    test('carries exactly one ThemeExtension: PriceTextStyle', () {
      final theme = AppTheme.light();

      expect(theme.extensions.length, 1);
      expect(theme.extension<PriceTextStyle>(), isNotNull);
    });

    test(
      'the PriceTextStyle extension is built from the theme\'s own titleMedium',
      () {
        final theme = AppTheme.light();
        final priceStyle = theme.extension<PriceTextStyle>()!.style;

        // Colour is deliberately left null here, exactly like every other
        // role — Text widgets resolve it from the ambient DefaultTextStyle
        // at paint time (design/02 §4.3: colour is resolved by ThemeData,
        // never baked into a role's TextStyle in isolation).
        expect(priceStyle.fontSize, theme.textTheme.titleMedium?.fontSize);
        expect(priceStyle.fontWeight, FontWeight.w700);
      },
    );

    test('the type ramp roles are present on the theme textTheme', () {
      final theme = AppTheme.light();

      expect(theme.textTheme.headlineMedium?.fontWeight, FontWeight.w600);
      expect(theme.textTheme.titleMedium?.fontWeight, FontWeight.w600);
      expect(theme.textTheme.bodyMedium?.fontWeight, FontWeight.w400);
      expect(theme.textTheme.labelLarge?.fontWeight, FontWeight.w500);
      expect(theme.textTheme.bodySmall?.fontWeight, FontWeight.w400);
    });

    test(
      'two calls to light() produce an equal colour scheme (deterministic)',
      () {
        final first = AppTheme.light();
        final second = AppTheme.light();

        expect(first.colorScheme.primary, second.colorScheme.primary);
      },
    );
  });
}
