import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:footverse/core/widgets/app_tag.dart';

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
}

void main() {
  group('AppTag — always pairs colour with a word (design/03 §11)', () {
    testWidgets('renders the label text', (tester) async {
      await _pump(
        tester,
        AppTag(
          label: 'Out of stock',
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
        ),
      );

      expect(find.text('Out of stock'), findsOneWidget);
    });

    testWidgets('renders with the given background colour', (tester) async {
      const background = Color(0xFF123456);
      await _pump(
        tester,
        const AppTag(
          label: '−20%',
          backgroundColor: background,
          foregroundColor: Colors.white,
        ),
      );

      final decoratedBox = tester.widget<DecoratedBox>(
        find.byType(DecoratedBox),
      );
      final decoration = decoratedBox.decoration as BoxDecoration;
      expect(decoration.color, background);
    });

    testWidgets('the text colour matches the given foreground colour', (
      tester,
    ) async {
      const foreground = Color(0xFF654321);
      await _pump(
        tester,
        const AppTag(
          label: 'Delivered',
          backgroundColor: Colors.black,
          foregroundColor: foreground,
        ),
      );

      final text = tester.widget<Text>(find.text('Delivered'));
      expect(text.style?.color, foreground);
    });

    testWidgets('an optional icon pairs with, never replaces, the word', (
      tester,
    ) async {
      await _pump(
        tester,
        AppTag(
          label: 'Out of stock',
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          icon: Icons.remove_shopping_cart_outlined,
        ),
      );

      expect(find.byIcon(Icons.remove_shopping_cart_outlined), findsOneWidget);
      expect(find.text('Out of stock'), findsOneWidget);
    });

    testWidgets(
      'cannot be constructed without both a colour and a label (compile-time)',
      (tester) async {
        // label, backgroundColor, and foregroundColor are all `required` —
        // this test documents the guarantee; the assertion is the type system
        // itself (this file would fail to compile without all three).
        const tag = AppTag(
          label: 'In stock',
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
        );
        expect(tag.label, isNotEmpty);
      },
    );
  });

  group('AppTag — non-interactive (design/03 §11)', () {
    testWidgets(
      'has no tap target of its own — no InkWell, no GestureDetector',
      (tester) async {
        await _pump(
          tester,
          AppTag(
            label: 'Pending',
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
        );

        expect(find.byType(InkWell), findsNothing);
        expect(find.byType(GestureDetector), findsNothing);
      },
    );
  });
}
