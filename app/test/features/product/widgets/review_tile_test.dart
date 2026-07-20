import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:footverse/core/widgets/app_network_image.dart';
import 'package:footverse/core/widgets/rating_display.dart';
import 'package:footverse/features/product/models/review_response.dart';
import 'package:footverse/features/product/widgets/review_tile.dart';

ReviewResponse _review({
  required DateTime createdAt,
  required DateTime updatedAt,
  int rating = 5,
  String? userAvatarUrl,
}) => ReviewResponse(
  id: 1,
  productId: 10,
  userId: 7,
  userFullName: 'Nguyen Van A',
  rating: rating,
  comment: 'Great shoe.',
  createdAt: createdAt,
  updatedAt: updatedAt,
  userAvatarUrl: userAvatarUrl,
);

Future<void> _pumpTile(WidgetTester tester, ReviewResponse review) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: ReviewTile(review: review)),
    ),
  );
}

void main() {
  group('ReviewTile — "Edited" indicator', () {
    testWidgets('hides "Edited" when updatedAt equals createdAt', (
      tester,
    ) async {
      final at = DateTime.parse('2025-01-15T10:30:00');
      await _pumpTile(tester, _review(createdAt: at, updatedAt: at));

      expect(find.text('Edited'), findsNothing);
    });

    testWidgets('shows "Edited" when updatedAt differs from createdAt', (
      tester,
    ) async {
      await _pumpTile(
        tester,
        _review(
          createdAt: DateTime.parse('2025-01-15T10:30:00'),
          updatedAt: DateTime.parse('2025-01-16T08:00:00'),
        ),
      );

      expect(find.text('Edited'), findsOneWidget);
    });
  });

  group('ReviewTile — shared components (sprint-14-plan Task 09)', () {
    testWidgets(
      'formats the date through AppDateFormat, not a raw ISO string',
      (tester) async {
        await _pumpTile(
          tester,
          _review(
            createdAt: DateTime.parse('2025-01-15T10:30:00'),
            updatedAt: DateTime.parse('2025-01-15T10:30:00'),
          ),
        );

        expect(find.text('15 Jan 2025'), findsOneWidget);
        expect(find.textContaining('2025-01-15'), findsNothing);
      },
    );

    testWidgets('shows the rating through RatingDisplay — star and value', (
      tester,
    ) async {
      await _pumpTile(
        tester,
        _review(
          createdAt: DateTime.parse('2025-01-15T10:30:00'),
          updatedAt: DateTime.parse('2025-01-15T10:30:00'),
          rating: 4,
        ),
      );

      expect(find.byType(RatingDisplay), findsOneWidget);
      expect(find.byIcon(Icons.star), findsOneWidget);
      expect(find.text('4.0'), findsOneWidget);
      // A reviewer's own rating is not an aggregate — no "(N reviews)" suffix.
      expect(find.textContaining('('), findsNothing);
    });

    testWidgets(
      'renders the avatar through AppNetworkImage, not Image.network',
      (tester) async {
        await _pumpTile(
          tester,
          _review(
            createdAt: DateTime.parse('2025-01-15T10:30:00'),
            updatedAt: DateTime.parse('2025-01-15T10:30:00'),
            userAvatarUrl: 'https://cdn.example.com/avatar.jpg',
          ),
        );

        expect(find.byType(AppNetworkImage), findsOneWidget);
        // Caching is mandatory (design/03 §4): the underlying provider is
        // `CachedNetworkImageProvider`, not a bare uncached `NetworkImage`.
        final image = tester.widget<Image>(find.byType(Image));
        expect(image.image, isNot(isA<NetworkImage>()));
        // Avatars are the one shape exempted from the rectangles-only rule
        // (design/02 §8) — clipped circular over AppNetworkImage.
        expect(find.byType(ClipOval), findsOneWidget);
      },
    );

    testWidgets('a missing avatar still renders through AppNetworkImage', (
      tester,
    ) async {
      await _pumpTile(
        tester,
        _review(
          createdAt: DateTime.parse('2025-01-15T10:30:00'),
          updatedAt: DateTime.parse('2025-01-15T10:30:00'),
        ),
      );

      expect(find.byType(AppNetworkImage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
