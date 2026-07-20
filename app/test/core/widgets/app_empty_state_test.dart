import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:footverse/core/widgets/app_empty_state.dart';

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
}

void main() {
  group('AppEmptyState — contract (design/03 §26)', () {
    testWidgets('renders the icon, title, and message', (tester) async {
      await _pump(
        tester,
        const AppEmptyState(
          icon: Icons.shopping_bag_outlined,
          title: 'Your cart is empty',
          message: 'Items you add will show up here.',
        ),
      );

      expect(find.byIcon(Icons.shopping_bag_outlined), findsOneWidget);
      expect(find.text('Your cart is empty'), findsOneWidget);
      expect(find.text('Items you add will show up here.'), findsOneWidget);
    });

    testWidgets('the layout works with no action at all', (tester) async {
      await _pump(
        tester,
        const AppEmptyState(
          icon: Icons.shopping_bag_outlined,
          title: 'Your cart is empty',
          message: 'Items you add will show up here.',
        ),
      );

      expect(find.byType(FilledButton), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'renders the action button when both actionLabel and onAction are given',
      (tester) async {
        var tapped = false;
        await _pump(
          tester,
          AppEmptyState(
            icon: Icons.shopping_bag_outlined,
            title: 'Your cart is empty',
            message: 'Items you add will show up here.',
            actionLabel: 'Browse products',
            onAction: () => tapped = true,
          ),
        );

        expect(
          find.widgetWithText(FilledButton, 'Browse products'),
          findsOneWidget,
        );

        await tester.tap(find.widgetWithText(FilledButton, 'Browse products'));
        await tester.pump();

        expect(tapped, isTrue);
      },
    );

    testWidgets(
      'omits the action when only actionLabel is given (no callback)',
      (tester) async {
        await _pump(
          tester,
          const AppEmptyState(
            icon: Icons.shopping_bag_outlined,
            title: 'Your cart is empty',
            message: 'Items you add will show up here.',
            actionLabel: 'Browse products',
          ),
        );

        expect(find.byType(FilledButton), findsNothing);
      },
    );
  });

  group('AppEmptyState — accessibility (design/02 §12)', () {
    testWidgets('the action button meets the 48 dp touch target', (
      tester,
    ) async {
      await _pump(
        tester,
        AppEmptyState(
          icon: Icons.shopping_bag_outlined,
          title: 'Your cart is empty',
          message: 'Items you add will show up here.',
          actionLabel: 'Browse products',
          onAction: () {},
        ),
      );

      final size = tester.getSize(find.byType(FilledButton));
      expect(size.height, greaterThanOrEqualTo(48));
    });

    testWidgets('the icon is decorative — excluded from the semantics tree', (
      tester,
    ) async {
      await _pump(
        tester,
        const AppEmptyState(
          icon: Icons.shopping_bag_outlined,
          title: 'Your cart is empty',
          message: 'Items you add will show up here.',
        ),
      );

      // The icon carries no semantic label of its own — title/message speak
      // for themselves as plain, separately-focusable text.
      final handle = tester.ensureSemantics();
      expect(
        tester.getSemantics(find.byIcon(Icons.shopping_bag_outlined)).label,
        isEmpty,
      );
      handle.dispose();
    });
  });
}
