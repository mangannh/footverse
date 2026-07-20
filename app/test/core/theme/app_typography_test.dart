import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:footverse/core/theme/app_typography.dart';

void main() {
  const testColor = Color(0xFF123456);

  group('AppTypography.textTheme (design/02 §4.1)', () {
    final textTheme = AppTypography.textTheme(
      Typography.englishLike2021,
      testColor,
    );

    test('display role (headlineMedium) is weight 600', () {
      expect(textTheme.headlineMedium?.fontWeight, FontWeight.w600);
    });

    test('title role (titleMedium) is weight 600', () {
      expect(textTheme.titleMedium?.fontWeight, FontWeight.w600);
    });

    test('body role (bodyMedium) is weight 400', () {
      expect(textTheme.bodyMedium?.fontWeight, FontWeight.w400);
    });

    test('label role (labelLarge) is weight 500', () {
      expect(textTheme.labelLarge?.fontWeight, FontWeight.w500);
    });

    test('caption role (bodySmall) is weight 400', () {
      expect(textTheme.bodySmall?.fontWeight, FontWeight.w400);
    });

    test(
      'every customised role carries the given colour explicitly — the near-invisible-text regression fix',
      () {
        // `Typography.englishLike2021` ships every style with `inherit:
        // false` and no colour. A `RenderParagraph` painted with a null,
        // non-inheriting colour falls through to the engine's raw default,
        // which paints white regardless of theme — the exact cause of the
        // ProductCard regression. Every role must carry the colour
        // explicitly so it is legible on its own.
        expect(textTheme.headlineMedium?.color, testColor);
        expect(textTheme.titleMedium?.color, testColor);
        expect(textTheme.bodyMedium?.color, testColor);
        expect(textTheme.labelLarge?.color, testColor);
        expect(textTheme.bodySmall?.color, testColor);
      },
    );

    test(
      'roles this ramp does not explicitly customise are still coloured',
      () {
        // TextTheme.apply covers every role, not just the five the ramp
        // adjusts weight on — a widget reading e.g. titleLarge or bodyLarge
        // directly (as several Material components do internally) must be
        // legible too.
        expect(textTheme.titleLarge?.color, testColor);
        expect(textTheme.bodyLarge?.color, testColor);
        expect(textTheme.labelMedium?.color, testColor);
        expect(textTheme.displayLarge?.color, testColor);
      },
    );
  });

  group('PriceTextStyle (design/02 §4.2)', () {
    test('is built from titleMedium with weight 700 and tabular figures', () {
      final textTheme = AppTypography.textTheme(
        Typography.englishLike2021,
        testColor,
      );
      final priceStyle = PriceTextStyle.from(textTheme);

      expect(priceStyle.style.fontWeight, FontWeight.w700);
      expect(
        priceStyle.style.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
      expect(priceStyle.style.fontSize, textTheme.titleMedium?.fontSize);
    });

    test('inherits the title role\'s colour — price text is legible too', () {
      final textTheme = AppTypography.textTheme(
        Typography.englishLike2021,
        testColor,
      );
      final priceStyle = PriceTextStyle.from(textTheme);

      expect(priceStyle.style.color, testColor);
    });

    test(
      'price weight (700) differs from title weight (600) on the same M3 style',
      () {
        final textTheme = AppTypography.textTheme(
          Typography.englishLike2021,
          testColor,
        );
        final priceStyle = PriceTextStyle.from(textTheme);

        expect(
          priceStyle.style.fontWeight,
          isNot(textTheme.titleMedium?.fontWeight),
        );
      },
    );

    test('copyWith replaces only the provided style', () {
      const original = PriceTextStyle(style: TextStyle(fontSize: 16));
      final copy = original.copyWith(style: const TextStyle(fontSize: 20));

      expect(copy.style.fontSize, 20);
      expect(original.style.fontSize, 16);
    });

    test('lerp with a non-PriceTextStyle extension returns this unchanged', () {
      const style = PriceTextStyle(style: TextStyle(fontSize: 16));

      expect(style.lerp(null, 0.5), same(style));
    });

    test('lerp between two PriceTextStyle interpolates the text style', () {
      const a = PriceTextStyle(style: TextStyle(fontSize: 10));
      const b = PriceTextStyle(style: TextStyle(fontSize: 20));

      final result = a.lerp(b, 0.5);

      expect(result.style.fontSize, 15);
    });
  });
}
