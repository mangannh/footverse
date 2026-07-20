import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:footverse/core/widgets/section_header.dart';

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
}

void main() {
  group('SectionHeader — contract (design/03 §12)', () {
    testWidgets('renders the title', (tester) async {
      await _pump(tester, const SectionHeader(title: 'Related products'));

      expect(find.text('Related products'), findsOneWidget);
    });

    testWidgets('the layout works with no action at all', (tester) async {
      await _pump(tester, const SectionHeader(title: 'Related products'));

      expect(find.byType(TextButton), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'renders the trailing action when both action and onAction are given',
      (tester) async {
        var tapped = false;
        await _pump(
          tester,
          SectionHeader(
            title: 'Reviews',
            action: 'See all',
            onAction: () => tapped = true,
          ),
        );

        expect(find.widgetWithText(TextButton, 'See all'), findsOneWidget);

        await tester.tap(find.widgetWithText(TextButton, 'See all'));
        await tester.pump();
        expect(tapped, isTrue);
      },
    );

    testWidgets(
      'omits the action when only action label is given (no callback)',
      (tester) async {
        await _pump(
          tester,
          const SectionHeader(title: 'Reviews', action: 'See all'),
        );

        expect(find.byType(TextButton), findsNothing);
      },
    );
  });

  group('SectionHeader — accessibility', () {
    testWidgets('the action button meets the 48 dp touch target', (
      tester,
    ) async {
      await _pump(
        tester,
        SectionHeader(title: 'Reviews', action: 'See all', onAction: () {}),
      );

      final size = tester.getSize(find.byType(TextButton));
      expect(size.height, greaterThanOrEqualTo(48));
    });

    testWidgets(
      'a long title truncates instead of overflowing (bounded, one line)',
      (tester) async {
        await _pump(
          tester,
          const SizedBox(
            width: 200,
            child: SectionHeader(
              title:
                  'A very long section title that would otherwise overflow the row',
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        final text = tester.widget<Text>(find.byType(Text));
        expect(text.maxLines, 1);
        expect(text.overflow, TextOverflow.ellipsis);
      },
    );
  });
}
