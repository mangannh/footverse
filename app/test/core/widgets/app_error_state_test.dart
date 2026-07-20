import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:footverse/core/widgets/app_error_state.dart';

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
}

void main() {
  group('AppErrorState — contract (design/03 §27)', () {
    testWidgets('displays the message verbatim — never modified', (
      tester,
    ) async {
      const message = 'Something went wrong. Please try again.';
      await _pump(
        tester,
        AppErrorState(message: message, onRetry: () async {}),
      );

      expect(find.text(message), findsOneWidget);
    });

    testWidgets(
      'never renders an HTTP status, exception type, or stack trace',
      (tester) async {
        const message = "That size is out of stock.";
        await _pump(
          tester,
          AppErrorState(message: message, onRetry: () async {}),
        );

        expect(find.textContaining('Exception'), findsNothing);
        expect(find.textContaining('500'), findsNothing);
        expect(
          find.textContaining('#0'),
          findsNothing,
        ); // stack-trace frame marker
      },
    );

    testWidgets('tapping Retry invokes onRetry exactly once', (tester) async {
      var callCount = 0;
      await _pump(
        tester,
        AppErrorState(
          message: 'Something went wrong.',
          onRetry: () async {
            callCount++;
          },
        ),
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
      await tester.pumpAndSettle();

      expect(callCount, 1);
    });
  });

  group('AppErrorState — retry loading (design/03 §27, design/02 §14)', () {
    testWidgets(
      'shows in-button progress while onRetry is pending, no full-screen spinner',
      (tester) async {
        final completer = Completer<void>();
        await _pump(
          tester,
          AppErrorState(
            message: 'Something went wrong.',
            onRetry: () => completer.future,
          ),
        );

        await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        // The only progress indicator on screen is the in-button one.
        expect(find.byType(CircularProgressIndicator), findsNWidgets(1));

        completer.complete();
        await tester.pumpAndSettle();

        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);
      },
    );

    testWidgets('the button disables (single-flight) while retrying', (
      tester,
    ) async {
      final completer = Completer<void>();
      var callCount = 0;
      await _pump(
        tester,
        AppErrorState(
          message: 'Something went wrong.',
          onRetry: () {
            callCount++;
            return completer.future;
          },
        ),
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
      await tester.pump();

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);

      // A second tap while disabled must not re-invoke onRetry.
      await tester.tap(find.byType(FilledButton), warnIfMissed: false);
      await tester.pump();
      expect(callCount, 1);

      completer.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('the button width does not change between idle and loading', (
      tester,
    ) async {
      final completer = Completer<void>();
      await _pump(
        tester,
        AppErrorState(
          message: 'Something went wrong.',
          onRetry: () => completer.future,
        ),
      );

      final idleWidth = tester.getSize(find.byType(FilledButton)).width;

      await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
      await tester.pump();
      final loadingWidth = tester.getSize(find.byType(FilledButton)).width;

      expect(loadingWidth, idleWidth);

      completer.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('re-enables and recovers even when onRetry throws', (
      tester,
    ) async {
      await _pump(
        tester,
        AppErrorState(
          message: 'Something went wrong.',
          onRetry: () async {
            throw StateError('retry failed');
          },
        ),
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
      await tester.pumpAndSettle();

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNotNull);
    });
  });

  group('AppErrorState — accessibility', () {
    testWidgets('the retry button meets the 48 dp touch target', (
      tester,
    ) async {
      await _pump(
        tester,
        AppErrorState(message: 'Something went wrong.', onRetry: () async {}),
      );

      final size = tester.getSize(find.byType(FilledButton));
      expect(size.height, greaterThanOrEqualTo(48));
    });

    testWidgets('the message is wrapped in a live region for screen readers', (
      tester,
    ) async {
      await _pump(
        tester,
        AppErrorState(message: 'Something went wrong.', onRetry: () async {}),
      );

      final semanticsWidget = tester.widget<Semantics>(
        find
            .ancestor(
              of: find.text('Something went wrong.'),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(semanticsWidget.properties.liveRegion, isTrue);
    });
  });
}
