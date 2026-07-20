import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:footverse/core/widgets/rating_display.dart';

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
}

void main() {
  group('RatingDisplay — no reviews renders nothing (design/03 §3)', () {
    testWidgets('reviewCount: null renders nothing at all — not "0.0"', (
      tester,
    ) async {
      await _pump(tester, const RatingDisplay(rating: 0, reviewCount: null));

      expect(find.textContaining('0.0'), findsNothing);
      expect(find.byIcon(Icons.star), findsNothing);
      expect(tester.getSize(find.byType(RatingDisplay)), Size.zero);
    });

    testWidgets('reviewCount: 0 renders nothing at all — not "0.0"', (
      tester,
    ) async {
      await _pump(tester, const RatingDisplay(rating: 4.5, reviewCount: 0));

      expect(find.textContaining('0.0'), findsNothing);
      expect(find.text('4.5'), findsNothing);
      expect(find.byIcon(Icons.star), findsNothing);
    });

    testWidgets(
      'a genuinely zero rating with real reviews is never hidden or misread as "no reviews"',
      (tester) async {
        await _pump(tester, const RatingDisplay(rating: 0, reviewCount: 3));

        expect(find.text('0.0'), findsOneWidget);
      },
    );
  });

  group('RatingDisplay — renders the rating and count (design/03 §3)', () {
    testWidgets('formats the rating to one decimal place', (tester) async {
      await _pump(tester, const RatingDisplay(rating: 4.5, reviewCount: 23));

      expect(find.text('4.5'), findsOneWidget);
    });

    testWidgets('rounds a longer decimal to one place for display only', (
      tester,
    ) async {
      await _pump(tester, const RatingDisplay(rating: 4.567, reviewCount: 12));

      expect(find.text('4.6'), findsOneWidget);
    });

    testWidgets('shows the review count in parentheses', (tester) async {
      await _pump(tester, const RatingDisplay(rating: 4.5, reviewCount: 23));

      expect(find.text('(23)'), findsOneWidget);
    });

    testWidgets('shows the star icon', (tester) async {
      await _pump(tester, const RatingDisplay(rating: 4.5, reviewCount: 23));

      expect(find.byIcon(Icons.star), findsOneWidget);
    });
  });

  group('RatingDisplay — accessibility (design/03 §3)', () {
    testWidgets(
      'emits the "X out of 5" semantics label, not just the bare number',
      (tester) async {
        await _pump(tester, const RatingDisplay(rating: 4.5, reviewCount: 23));

        expect(
          find.bySemanticsLabel('Rated 4.5 out of 5, 23 reviews.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('uses singular "review" for exactly one review', (
      tester,
    ) async {
      await _pump(tester, const RatingDisplay(rating: 5.0, reviewCount: 1));

      expect(
        find.bySemanticsLabel('Rated 5.0 out of 5, 1 review.'),
        findsOneWidget,
      );
    });
  });

  group(
    'RatingDisplay — reviewCount unknown (sprint-14-plan Task 07 extension)',
    () {
      testWidgets(
        'averageRating > 0 renders the rating without a count suffix',
        (tester) async {
          await _pump(
            tester,
            const RatingDisplay(rating: 4.5, reviewCount: null),
          );

          expect(find.text('4.5'), findsOneWidget);
          expect(find.byIcon(Icons.star), findsOneWidget);
          expect(find.textContaining('('), findsNothing);
        },
      );

      testWidgets('averageRating <= 0 still renders nothing at all', (
        tester,
      ) async {
        await _pump(tester, const RatingDisplay(rating: 0, reviewCount: null));

        expect(find.byIcon(Icons.star), findsNothing);
        expect(tester.getSize(find.byType(RatingDisplay)), Size.zero);
      });

      testWidgets(
        'the semantics label omits the reviews clause when the count is unknown',
        (tester) async {
          await _pump(
            tester,
            const RatingDisplay(rating: 4.5, reviewCount: null),
          );

          expect(find.bySemanticsLabel('Rated 4.5 out of 5.'), findsOneWidget);
        },
      );

      testWidgets(
        'passing an explicit reviewCount is unaffected — still shows the suffix',
        (tester) async {
          await _pump(
            tester,
            const RatingDisplay(rating: 4.5, reviewCount: 23),
          );

          expect(find.text('(23)'), findsOneWidget);
          expect(
            find.bySemanticsLabel('Rated 4.5 out of 5, 23 reviews.'),
            findsOneWidget,
          );
        },
      );
    },
  );

  group('RatingDisplay — size variants (design/03 §3)', () {
    testWidgets('small and medium both render without throwing', (
      tester,
    ) async {
      await _pump(
        tester,
        const Column(
          children: [
            RatingDisplay(rating: 4.5, reviewCount: 10, size: RatingSize.small),
            RatingDisplay(
              rating: 4.5,
              reviewCount: 10,
              size: RatingSize.medium,
            ),
          ],
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('4.5'), findsNWidgets(2));
    });
  });
}
