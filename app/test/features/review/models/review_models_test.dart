import 'package:flutter_test/flutter_test.dart';
import 'package:footverse/features/product/models/review_response.dart';
import 'package:footverse/features/review/models/create_review_request.dart';
import 'package:footverse/features/review/models/update_review_request.dart';

Map<String, dynamic> _reviewJson() => <String, dynamic>{
  'id': 55,
  'productId': 42,
  'userId': 7,
  'userFullName': 'Nguyen Van A',
  'userAvatarUrl': 'https://cdn.example.com/a.jpg',
  'rating': 5,
  'comment': 'Excellent shoe',
  'createdAt': '2025-01-15T10:30:00',
  'updatedAt': '2025-01-16T08:00:00',
};

void main() {
  group('CreateReviewRequest (dto-spec §16)', () {
    test('serializes every write field', () {
      const request = CreateReviewRequest(
        productId: 42,
        rating: 5,
        comment: 'Excellent shoe',
      );

      expect(request.toJson(), <String, dynamic>{
        'productId': 42,
        'rating': 5,
        'comment': 'Excellent shoe',
      });
    });

    test('omits the optional comment when it is not set', () {
      const request = CreateReviewRequest(productId: 1, rating: 5);

      final json = request.toJson();
      expect(json.containsKey('comment'), isFalse);
      expect(json, <String, dynamic>{'productId': 1, 'rating': 5});
    });
  });

  group('UpdateReviewRequest (dto-spec §16)', () {
    test('serializes the rating and comment', () {
      const request = UpdateReviewRequest(
        rating: 4,
        comment: 'Good after a week',
      );

      expect(request.toJson(), <String, dynamic>{
        'rating': 4,
        'comment': 'Good after a week',
      });
    });

    test('omits the optional comment when it is not set', () {
      const request = UpdateReviewRequest(rating: 3);

      final json = request.toJson();
      expect(json.containsKey('comment'), isFalse);
      expect(json, <String, dynamic>{'rating': 3});
    });
  });

  group('ReviewResponse (dto-spec §16, extended by Sprint 9 item 01)', () {
    test('maps every field including productId and userId', () {
      final review = ReviewResponse.fromJson(_reviewJson());

      expect(review.id, 55);
      expect(review.productId, 42);
      expect(review.userId, 7);
      expect(review.userFullName, 'Nguyen Van A');
      expect(review.userAvatarUrl, 'https://cdn.example.com/a.jpg');
      expect(review.rating, 5);
      expect(review.comment, 'Excellent shoe');
      expect(review.createdAt, DateTime.parse('2025-01-15T10:30:00'));
      expect(review.updatedAt, DateTime.parse('2025-01-16T08:00:00'));
    });

    test('accepts a null avatar and comment', () {
      final review = ReviewResponse.fromJson(
        _reviewJson()
          ..['userAvatarUrl'] = null
          ..['comment'] = null,
      );

      expect(review.userAvatarUrl, isNull);
      expect(review.comment, isNull);
    });
  });
}
