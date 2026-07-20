import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:footverse/core/theme/app_theme.dart';
import 'package:footverse/core/theme/app_typography.dart';
import 'package:footverse/core/widgets/price_text.dart';

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

Text _textOf(WidgetTester tester) => tester.widget<Text>(find.byType(Text));

void main() {
  group('PriceText — formatting (design/03 §2)', () {
    testWidgets('zero renders with the currency symbol and no decimals', (
      tester,
    ) async {
      await _pump(tester, const PriceText(amount: 0));

      expect(_textOf(tester).data, '₫0');
    });

    testWidgets('a large amount groups thousands with commas', (tester) async {
      await _pump(tester, const PriceText(amount: 1234567890));

      expect(_textOf(tester).data, '₫1,234,567,890');
    });

    testWidgets('a typical product price matches the design mock-up exactly', (
      tester,
    ) async {
      await _pump(tester, const PriceText(amount: 1250000));

      expect(_textOf(tester).data, '₫1,250,000');
    });

    testWidgets(
      'a fractional double rounds for display — never shows a decimal',
      (tester) async {
        await _pump(tester, const PriceText(amount: 1250000.7));

        expect(_textOf(tester).data, isNot(contains('.')));
        expect(_textOf(tester).data, '₫1,250,001');
      },
    );

    testWidgets(
      'a negative amount renders the explicit Unicode minus sign (U+2212)',
      (tester) async {
        await _pump(tester, const PriceText(amount: -50000));

        final data = _textOf(tester).data!;
        expect(data, startsWith('−'));
        expect(data, isNot(startsWith('-'))); // never the ASCII hyphen
        expect(data, '−₫50,000');
      },
    );

    testWidgets('showCurrency: false omits the currency symbol', (
      tester,
    ) async {
      await _pump(
        tester,
        const PriceText(amount: 1250000, showCurrency: false),
      );

      expect(_textOf(tester).data, '1,250,000');
      expect(_textOf(tester).data, isNot(contains('₫')));
    });

    testWidgets(
      'showCurrency: false still shows the explicit minus sign when negative',
      (tester) async {
        await _pump(
          tester,
          const PriceText(amount: -1250000, showCurrency: false),
        );

        expect(
          _textOf(tester).data,
          '−'
          '1,250,000',
        );
      },
    );
  });

  group('PriceText — no arithmetic (dto-spec §1)', () {
    testWidgets(
      'amount is rendered exactly as given, with no rounding beyond display',
      (tester) async {
        await _pump(tester, const PriceText(amount: 100));

        expect(_textOf(tester).data, '₫100');
      },
    );
  });

  group('PriceText — the four variants (design/03 §2)', () {
    const amount = 1250000.0;

    testWidgets(
      'every variant renders the identical digit string for the same amount',
      (tester) async {
        final texts = <PriceVariant, String>{};
        for (final variant in PriceVariant.values) {
          await _pump(tester, PriceText(amount: amount, variant: variant));
          texts[variant] = _textOf(tester).data!;
        }

        final distinctStrings = texts.values.toSet();
        expect(
          distinctStrings.length,
          1,
          reason: 'variants must differ only in presentation',
        );
        expect(distinctStrings.single, '₫1,250,000');
      },
    );

    testWidgets('regular uses the theme price role unmodified', (tester) async {
      await _pump(tester, const PriceText(amount: amount));
      final theme = AppTheme.light();
      final priceStyle = theme.extension<PriceTextStyle>()!.style;

      expect(_textOf(tester).style?.fontWeight, priceStyle.fontWeight);
      expect(_textOf(tester).style?.fontSize, priceStyle.fontSize);
      expect(_textOf(tester).style?.fontFeatures, priceStyle.fontFeatures);
    });

    testWidgets(
      'emphasis is larger than regular but keeps the price weight and tabular figures',
      (tester) async {
        await _pump(
          tester,
          const PriceText(amount: amount, variant: PriceVariant.emphasis),
        );
        final emphasisStyle = _textOf(tester).style!;

        await _pump(tester, const PriceText(amount: amount));
        final regularStyle = _textOf(tester).style!;

        expect(emphasisStyle.fontSize, greaterThan(regularStyle.fontSize!));
        expect(emphasisStyle.fontWeight, regularStyle.fontWeight);
        expect(emphasisStyle.fontFeatures, regularStyle.fontFeatures);
      },
    );

    testWidgets(
      'compact is smaller than regular but keeps the price weight and tabular figures',
      (tester) async {
        await _pump(
          tester,
          const PriceText(amount: amount, variant: PriceVariant.compact),
        );
        final compactStyle = _textOf(tester).style!;

        await _pump(tester, const PriceText(amount: amount));
        final regularStyle = _textOf(tester).style!;

        expect(compactStyle.fontSize, lessThan(regularStyle.fontSize!));
        expect(compactStyle.fontWeight, regularStyle.fontWeight);
        expect(compactStyle.fontFeatures, regularStyle.fontFeatures);
      },
    );

    testWidgets(
      'strikethrough applies a line-through decoration and a de-emphasised colour',
      (tester) async {
        await _pump(
          tester,
          const PriceText(amount: amount, variant: PriceVariant.strikethrough),
        );
        final theme = AppTheme.light();

        final style = _textOf(tester).style!;
        expect(style.decoration, TextDecoration.lineThrough);
        expect(style.color, theme.colorScheme.onSurfaceVariant);
        expect(style.fontWeight, FontWeight.w700);
      },
    );
  });

  group('PriceText — accessibility (design/03 §2, design/02 §12)', () {
    testWidgets(
      'emits a Semantics label spelling the amount, not the raw glyph string',
      (tester) async {
        await _pump(tester, const PriceText(amount: 1250000));

        expect(
          find.bySemanticsLabel('1,250,000 Vietnamese dong'),
          findsOneWidget,
        );
      },
    );

    testWidgets('a negative amount is spelled "minus" in the semantics label', (
      tester,
    ) async {
      await _pump(tester, const PriceText(amount: -50000));

      expect(
        find.bySemanticsLabel('minus 50,000 Vietnamese dong'),
        findsOneWidget,
      );
    });

    testWidgets(
      'showCurrency: false still names the currency in the semantics label',
      (tester) async {
        await _pump(
          tester,
          const PriceText(amount: 1250000, showCurrency: false),
        );

        expect(
          find.bySemanticsLabel('1,250,000 Vietnamese dong'),
          findsOneWidget,
        );
      },
    );

    testWidgets('the raw digit glyphs are excluded from the semantics tree', (
      tester,
    ) async {
      await _pump(tester, const PriceText(amount: 1250000));

      final semantics = tester.getSemantics(find.byType(PriceText));
      expect(semantics.label, isNot(contains('₫1,250,000')));
    });
  });
}
