import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:footverse/core/widgets/quantity_selector.dart';

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
}

IconButton _decrementButton(WidgetTester tester) =>
    tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.remove));

IconButton _incrementButton(WidgetTester tester) =>
    tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.add));

void main() {
  group('QuantitySelector — contract (design/03 §9)', () {
    testWidgets('renders the current quantity verbatim', (tester) async {
      await _pump(
        tester,
        QuantitySelector(
          quantity: 3,
          onIncrement: () {},
          onDecrement: () {},
          enabled: true,
        ),
      );

      expect(find.text('3'), findsOneWidget);
    });

    testWidgets(
      'decrement is disabled at quantity 1, even when onDecrement is non-null',
      (tester) async {
        await _pump(
          tester,
          QuantitySelector(
            quantity: 1,
            onIncrement: () {},
            onDecrement: () {},
            enabled: true,
          ),
        );

        expect(_decrementButton(tester).onPressed, isNull);
        expect(_incrementButton(tester).onPressed, isNotNull);
      },
    );

    testWidgets('decrement is enabled above quantity 1', (tester) async {
      await _pump(
        tester,
        QuantitySelector(
          quantity: 2,
          onIncrement: () {},
          onDecrement: () {},
          enabled: true,
        ),
      );

      expect(_decrementButton(tester).onPressed, isNotNull);
    });

    testWidgets(
      'decrement stays disabled at quantity 1 even if the caller passes null too',
      (tester) async {
        await _pump(
          tester,
          QuantitySelector(
            quantity: 1,
            onIncrement: () {},
            onDecrement: null,
            enabled: true,
          ),
        );

        expect(_decrementButton(tester).onPressed, isNull);
      },
    );

    testWidgets('onIncrement: null disables increment (e.g. no more stock)', (
      tester,
    ) async {
      await _pump(
        tester,
        QuantitySelector(
          quantity: 3,
          onIncrement: null,
          onDecrement: () {},
          enabled: true,
        ),
      );

      expect(_incrementButton(tester).onPressed, isNull);
    });

    testWidgets('enabled: false disables the whole control while mutating', (
      tester,
    ) async {
      await _pump(
        tester,
        QuantitySelector(
          quantity: 3,
          onIncrement: () {},
          onDecrement: () {},
          enabled: false,
        ),
      );

      expect(_decrementButton(tester).onPressed, isNull);
      expect(_incrementButton(tester).onPressed, isNull);
    });

    testWidgets('tapping increment invokes the callback when enabled', (
      tester,
    ) async {
      var incremented = false;
      await _pump(
        tester,
        QuantitySelector(
          quantity: 3,
          onIncrement: () => incremented = true,
          onDecrement: () {},
          enabled: true,
        ),
      );

      await tester.tap(find.widgetWithIcon(IconButton, Icons.add));
      await tester.pump();

      expect(incremented, isTrue);
    });

    testWidgets('tapping decrement invokes the callback when enabled', (
      tester,
    ) async {
      var decremented = false;
      await _pump(
        tester,
        QuantitySelector(
          quantity: 3,
          onIncrement: () {},
          onDecrement: () => decremented = true,
          enabled: true,
        ),
      );

      await tester.tap(find.widgetWithIcon(IconButton, Icons.remove));
      await tester.pump();

      expect(decremented, isTrue);
    });
  });

  group('QuantitySelector — accessibility (design/02 §12 A-1, design/03 §9)', () {
    testWidgets(
      'both step buttons meet the 48 dp touch target, glyph stays default size',
      (tester) async {
        await _pump(
          tester,
          QuantitySelector(
            quantity: 3,
            onIncrement: () {},
            onDecrement: () {},
            enabled: true,
          ),
        );

        final decrementSize = tester.getSize(
          find.widgetWithIcon(IconButton, Icons.remove),
        );
        final incrementSize = tester.getSize(
          find.widgetWithIcon(IconButton, Icons.add),
        );

        expect(decrementSize.width, greaterThanOrEqualTo(48));
        expect(decrementSize.height, greaterThanOrEqualTo(48));
        expect(incrementSize.width, greaterThanOrEqualTo(48));
        expect(incrementSize.height, greaterThanOrEqualTo(48));
      },
    );

    testWidgets('carries the decrease/increase tooltips', (tester) async {
      await _pump(
        tester,
        QuantitySelector(
          quantity: 3,
          onIncrement: () {},
          onDecrement: () {},
          enabled: true,
        ),
      );

      expect(_decrementButton(tester).tooltip, 'Decrease quantity');
      expect(_incrementButton(tester).tooltip, 'Increase quantity');
    });
  });
}
