import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:footverse/core/theme/app_radius.dart';
import 'package:footverse/core/widgets/app_chips.dart';

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
}

void main() {
  group(
    'CategoryChip — selection is fill + check, never fill alone (design/03 §7)',
    () {
      testWidgets('renders the label', (tester) async {
        await _pump(
          tester,
          CategoryChip(label: 'Nike', selected: false, onSelected: (_) {}),
        );

        expect(find.text('Nike'), findsOneWidget);
      });

      testWidgets('always requests the checkmark treatment when selected', (
        tester,
      ) async {
        await _pump(
          tester,
          CategoryChip(label: 'Nike', selected: true, onSelected: (_) {}),
        );

        final chip = tester.widget<FilterChip>(find.byType(FilterChip));
        expect(chip.selected, isTrue);
        expect(chip.showCheckmark, isTrue);
      });

      testWidgets(
        'the underlying selected flag reflects the selected param when false',
        (tester) async {
          await _pump(
            tester,
            CategoryChip(label: 'Nike', selected: false, onSelected: (_) {}),
          );

          final chip = tester.widget<FilterChip>(find.byType(FilterChip));
          expect(chip.selected, isFalse);
        },
      );

      testWidgets('tapping invokes onSelected with the toggled value', (
        tester,
      ) async {
        bool? received;
        await _pump(
          tester,
          CategoryChip(
            label: 'Nike',
            selected: false,
            onSelected: (value) => received = value,
          ),
        );

        await tester.tap(find.byType(FilterChip));
        await tester.pump();

        expect(received, isTrue);
      });

      testWidgets('onSelected: null disables the chip', (tester) async {
        await _pump(
          tester,
          const CategoryChip(label: 'Nike', selected: false, onSelected: null),
        );

        final chip = tester.widget<FilterChip>(find.byType(FilterChip));
        expect(chip.onSelected, isNull);
      });

      testWidgets('uses the AppRadius.sm corner radius — no other value', (
        tester,
      ) async {
        await _pump(
          tester,
          CategoryChip(label: 'Nike', selected: false, onSelected: (_) {}),
        );

        final chip = tester.widget<FilterChip>(find.byType(FilterChip));
        final shape = chip.shape as RoundedRectangleBorder?;
        expect(shape?.borderRadius, BorderRadius.circular(AppRadius.sm));
      });

      testWidgets(
        'meets the 48 dp touch target via the padded tap target size',
        (tester) async {
          await _pump(
            tester,
            CategoryChip(label: 'Nike', selected: false, onSelected: (_) {}),
          );

          final size = tester.getSize(find.byType(FilterChip));
          expect(size.height, greaterThanOrEqualTo(48));
        },
      );
    },
  );

  group(
    'ActiveFilterChip — an applied filter, always shown selected (design/03 §7)',
    () {
      testWidgets('renders the label', (tester) async {
        await _pump(tester, ActiveFilterChip(label: 'Nike', onRemove: () {}));

        expect(find.text('Nike'), findsOneWidget);
      });

      testWidgets(
        'is always rendered selected — fill and check, never fill alone',
        (tester) async {
          await _pump(tester, ActiveFilterChip(label: 'Nike', onRemove: () {}));

          final chip = tester.widget<InputChip>(find.byType(InputChip));
          expect(chip.selected, isTrue);
          expect(chip.showCheckmark, isTrue);
        },
      );

      testWidgets('tapping the delete icon invokes onRemove', (tester) async {
        var removed = false;
        await _pump(
          tester,
          ActiveFilterChip(label: 'Nike', onRemove: () => removed = true),
        );

        await tester.tap(find.byIcon(Icons.close));
        await tester.pump();

        expect(removed, isTrue);
      });

      testWidgets(
        'the delete affordance carries a semantics tooltip naming the filter',
        (tester) async {
          await _pump(tester, ActiveFilterChip(label: 'Nike', onRemove: () {}));

          final chip = tester.widget<InputChip>(find.byType(InputChip));
          expect(chip.deleteButtonTooltipMessage, contains('Nike'));
        },
      );

      testWidgets('uses the AppRadius.sm corner radius — no other value', (
        tester,
      ) async {
        await _pump(tester, ActiveFilterChip(label: 'Nike', onRemove: () {}));

        final chip = tester.widget<InputChip>(find.byType(InputChip));
        final shape = chip.shape as RoundedRectangleBorder?;
        expect(shape?.borderRadius, BorderRadius.circular(AppRadius.sm));
      });

      testWidgets(
        'meets the 48 dp touch target via the padded tap target size',
        (tester) async {
          await _pump(tester, ActiveFilterChip(label: 'Nike', onRemove: () {}));

          final size = tester.getSize(find.byType(InputChip));
          expect(size.height, greaterThanOrEqualTo(48));
        },
      );
    },
  );
}
