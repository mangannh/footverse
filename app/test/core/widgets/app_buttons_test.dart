import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:footverse/core/widgets/app_buttons.dart';

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
}

void main() {
  group('AppPrimaryButton — loading contract (design/03 §1, mandatory AC)', () {
    testWidgets(
      'the in-button spinner appears while loading, not a full-screen one',
      (tester) async {
        await _pump(
          tester,
          AppPrimaryButton(
            label: 'Add to cart',
            onPressed: () {},
            loading: true,
          ),
        );

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Add to cart'), findsNothing);
      },
    );

    testWidgets('the button disables while loading', (tester) async {
      await _pump(
        tester,
        AppPrimaryButton(label: 'Add to cart', onPressed: () {}, loading: true),
      );

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });

    testWidgets(
      'the rendered width is identical between idle and loading — no layout shift',
      (tester) async {
        await _pump(
          tester,
          AppPrimaryButton(
            label: 'Add to cart',
            onPressed: () {},
            loading: false,
          ),
        );
        final idleWidth = tester.getSize(find.byType(FilledButton)).width;

        await _pump(
          tester,
          AppPrimaryButton(
            label: 'Add to cart',
            onPressed: () {},
            loading: true,
          ),
        );
        final loadingWidth = tester.getSize(find.byType(FilledButton)).width;

        expect(loadingWidth, idleWidth);
      },
    );

    testWidgets(
      'the rendered height is also identical between idle and loading',
      (tester) async {
        await _pump(
          tester,
          AppPrimaryButton(
            label: 'Add to cart',
            onPressed: () {},
            loading: false,
          ),
        );
        final idleHeight = tester.getSize(find.byType(FilledButton)).height;

        await _pump(
          tester,
          AppPrimaryButton(
            label: 'Add to cart',
            onPressed: () {},
            loading: true,
          ),
        );
        final loadingHeight = tester.getSize(find.byType(FilledButton)).height;

        expect(loadingHeight, idleHeight);
      },
    );

    testWidgets(
      'tapping while loading does not invoke onPressed (single-flight)',
      (tester) async {
        var tapCount = 0;
        await _pump(
          tester,
          AppPrimaryButton(
            label: 'Add to cart',
            onPressed: () => tapCount++,
            loading: true,
          ),
        );

        await tester.tap(find.byType(FilledButton), warnIfMissed: false);
        await tester.pump();

        expect(tapCount, 0);
      },
    );
  });

  group('AppPrimaryButton — contract (design/03 §1)', () {
    testWidgets('spans the full available width', (tester) async {
      await _pump(
        tester,
        AppPrimaryButton(label: 'Checkout', onPressed: () {}),
      );

      final buttonWidth = tester.getSize(find.byType(FilledButton)).width;
      final screenWidth = tester.getSize(find.byType(Scaffold)).width;
      expect(buttonWidth, screenWidth);
    });

    testWidgets('meets the 48 dp minimum height', (tester) async {
      await _pump(
        tester,
        AppPrimaryButton(label: 'Checkout', onPressed: () {}),
      );

      expect(
        tester.getSize(find.byType(FilledButton)).height,
        greaterThanOrEqualTo(48),
      );
    });

    testWidgets('onPressed: null disables the button (idle, not loading)', (
      tester,
    ) async {
      await _pump(
        tester,
        const AppPrimaryButton(label: 'Checkout', onPressed: null),
      );

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('tapping when enabled invokes onPressed', (tester) async {
      var tapped = false;
      await _pump(
        tester,
        AppPrimaryButton(label: 'Checkout', onPressed: () => tapped = true),
      );

      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets(
      'the accessible label is the action name in both idle and loading states',
      (tester) async {
        await _pump(
          tester,
          AppPrimaryButton(
            label: 'Add to cart',
            onPressed: () {},
            loading: true,
          ),
        );

        expect(find.bySemanticsLabel('Add to cart'), findsOneWidget);
      },
    );
  });

  group('AppDestructiveButton — contract (design/03 §1)', () {
    testWidgets('uses the error colour role, not the default primary colour', (
      tester,
    ) async {
      await _pump(
        tester,
        AppDestructiveButton(label: 'Delete address', onPressed: () {}),
      );
      final theme = Theme.of(tester.element(find.byType(FilledButton)));

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      final backgroundColor = button.style?.backgroundColor?.resolve(
        <WidgetState>{},
      );
      expect(backgroundColor, theme.colorScheme.error);
    });

    testWidgets('meets the 48 dp minimum height', (tester) async {
      await _pump(
        tester,
        AppDestructiveButton(label: 'Delete address', onPressed: () {}),
      );

      expect(
        tester.getSize(find.byType(FilledButton)).height,
        greaterThanOrEqualTo(48),
      );
    });

    testWidgets('onPressed: null disables the button', (tester) async {
      await _pump(
        tester,
        const AppDestructiveButton(label: 'Delete address', onPressed: null),
      );

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('tapping when enabled invokes onPressed', (tester) async {
      var tapped = false;
      await _pump(
        tester,
        AppDestructiveButton(
          label: 'Delete address',
          onPressed: () => tapped = true,
        ),
      );

      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      expect(tapped, isTrue);
    });
  });
}
