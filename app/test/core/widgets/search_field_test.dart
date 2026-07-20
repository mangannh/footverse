import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:footverse/core/widgets/search_field.dart';

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
}

void main() {
  group('SearchField — debounce (design/03 §6, fake clock)', () {
    testWidgets('does not call onSearch before 400 ms have elapsed', (
      tester,
    ) async {
      final calls = <String>[];
      await _pump(tester, SearchField(onSearch: calls.add));

      await tester.enterText(find.byType(TextField), 'shoe');
      await tester.pump(const Duration(milliseconds: 300));

      expect(calls, isEmpty);
    });

    testWidgets('calls onSearch once the 400 ms debounce elapses', (
      tester,
    ) async {
      final calls = <String>[];
      await _pump(tester, SearchField(onSearch: calls.add));

      await tester.enterText(find.byType(TextField), 'shoe');
      await tester.pump(const Duration(milliseconds: 400));

      expect(calls, ['shoe']);
    });

    testWidgets(
      'rapid keystrokes within the window collapse into a single call',
      (tester) async {
        final calls = <String>[];
        await _pump(tester, SearchField(onSearch: calls.add));

        await tester.enterText(find.byType(TextField), 's');
        await tester.pump(const Duration(milliseconds: 100));
        await tester.enterText(find.byType(TextField), 'sh');
        await tester.pump(const Duration(milliseconds: 100));
        await tester.enterText(find.byType(TextField), 'sho');
        await tester.pump(const Duration(milliseconds: 100));
        await tester.enterText(find.byType(TextField), 'shoe');
        await tester.pump(const Duration(milliseconds: 400));

        expect(calls, ['shoe']);
      },
    );

    testWidgets(
      'submitting cancels the pending debounce and searches immediately',
      (tester) async {
        final calls = <String>[];
        await _pump(tester, SearchField(onSearch: calls.add));

        await tester.enterText(find.byType(TextField), 'shoe');
        await tester.pump(const Duration(milliseconds: 50));
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pump();

        expect(calls, ['shoe']);

        // The debounce that would have fired at 400 ms must not fire again.
        await tester.pump(const Duration(milliseconds: 400));
        expect(calls, ['shoe']);
      },
    );
  });

  group(
    'SearchField — dispose safety (mandatory: no crash after teardown)',
    () {
      testWidgets(
        'a pending debounce is cancelled on dispose — no late call, no crash',
        (tester) async {
          final calls = <String>[];
          await _pump(tester, SearchField(onSearch: calls.add));

          await tester.enterText(find.byType(TextField), 'shoe');
          await tester.pump(const Duration(milliseconds: 100));

          // Replace the widget tree entirely — SearchField is disposed with its
          // debounce Timer still pending.
          await tester.pumpWidget(
            const MaterialApp(home: Scaffold(body: SizedBox())),
          );

          // Advance past when the original debounce would have fired.
          await tester.pump(const Duration(milliseconds: 400));

          expect(tester.takeException(), isNull);
          expect(calls, isEmpty);
        },
      );
    },
  );

  group('SearchField — clear affordance (design/03 §6)', () {
    testWidgets('the clear button is absent when the field is empty', (
      tester,
    ) async {
      await _pump(tester, SearchField(onSearch: (_) {}));

      expect(find.byTooltip('Clear search'), findsNothing);
    });

    testWidgets('the clear button appears once the field is non-empty', (
      tester,
    ) async {
      await _pump(tester, SearchField(onSearch: (_) {}));

      await tester.enterText(find.byType(TextField), 'shoe');
      await tester.pump();

      expect(find.byTooltip('Clear search'), findsOneWidget);
    });

    testWidgets(
      'tapping clear empties the field, searches with "", and calls onClear',
      (tester) async {
        final calls = <String>[];
        var clearedCalled = false;
        await _pump(
          tester,
          SearchField(onSearch: calls.add, onClear: () => clearedCalled = true),
        );

        await tester.enterText(find.byType(TextField), 'shoe');
        await tester.pump();
        await tester.tap(find.byTooltip('Clear search'));
        await tester.pump();

        expect(find.text('shoe'), findsNothing);
        expect(calls, ['']);
        expect(clearedCalled, isTrue);

        // No stale debounce fires later with the old text.
        await tester.pump(const Duration(milliseconds: 400));
        expect(calls, ['']);
      },
    );
  });

  group('SearchField — contract (design/03 §6)', () {
    testWidgets('shows the initial value', (tester) async {
      await _pump(tester, SearchField(onSearch: (_) {}, initialValue: 'boots'));

      expect(find.text('boots'), findsOneWidget);
    });

    testWidgets('the accessible label is "Search products"', (tester) async {
      await _pump(tester, SearchField(onSearch: (_) {}));

      expect(find.text('Search products'), findsOneWidget);
    });

    testWidgets('no autocomplete or suggestion surface is ever shown', (
      tester,
    ) async {
      await _pump(tester, SearchField(onSearch: (_) {}));

      await tester.enterText(find.byType(TextField), 'sh');
      await tester.pump();

      expect(find.byType(ListView), findsNothing);
      expect(find.byType(Autocomplete<String>), findsNothing);
    });
  });
}
