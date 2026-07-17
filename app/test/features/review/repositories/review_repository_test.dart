import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:footverse/core/error/app_exception.dart';
import 'package:footverse/features/review/models/create_review_request.dart';
import 'package:footverse/features/review/models/update_review_request.dart';
import 'package:footverse/features/review/repositories/review_repository.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'review_repository_test.mocks.dart';

Map<String, dynamic> _reviewData() => <String, dynamic>{
  'id': 55,
  'productId': 42,
  'userId': 7,
  'userFullName': 'Nguyen Van A',
  'userAvatarUrl': 'https://cdn.example.com/a.jpg',
  'rating': 5,
  'comment': 'Excellent shoe',
  'createdAt': '2025-01-15T10:30:00',
  'updatedAt': '2025-01-15T10:30:00',
};

Response<Map<String, dynamic>> _envelope(String path, Object data) =>
    Response<Map<String, dynamic>>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data: <String, dynamic>{
        'success': true,
        'message': 'OK',
        'data': data,
        'timestamp': '2025-01-15T10:30:00',
      },
    );

Response<void> _voidResponse(String path) =>
    Response<void>(requestOptions: RequestOptions(path: path), statusCode: 200);

DioException _errorWith(String errorCode, int statusCode) => DioException(
  requestOptions: RequestOptions(path: '/api/v1/reviews'),
  error: AppException(
    message: 'error',
    statusCode: statusCode,
    errorCode: errorCode,
  ),
);

const CreateReviewRequest _createRequest = CreateReviewRequest(
  productId: 42,
  rating: 5,
  comment: 'Excellent shoe',
);

const UpdateReviewRequest _updateRequest = UpdateReviewRequest(
  rating: 4,
  comment: 'Good after a week',
);

@GenerateNiceMocks([MockSpec<Dio>()])
void main() {
  late MockDio dio;
  late ReviewRepository repository;

  setUp(() {
    dio = MockDio();
    repository = ReviewRepository(dio);
  });

  group('createReview', () {
    test(
      'POSTs the reviews path with the body, returns typed review',
      () async {
        when(
          dio.post<Map<String, dynamic>>(any, data: anyNamed('data')),
        ).thenAnswer((_) async => _envelope('/api/v1/reviews', _reviewData()));

        final review = await repository.createReview(_createRequest);

        final captured = verify(
          dio.post<Map<String, dynamic>>(
            captureAny,
            data: captureAnyNamed('data'),
          ),
        ).captured;
        expect(captured[0], '/api/v1/reviews');
        expect(captured[1], _createRequest.toJson());
        expect(review.id, 55);
        expect(review.productId, 42);
        expect(review.userId, 7);
        expect(review.rating, 5);
        expect(review.comment, 'Excellent shoe');
      },
    );

    test('surfaces REVIEW_NOT_ELIGIBLE as a typed AppException', () async {
      when(
        dio.post<Map<String, dynamic>>(any, data: anyNamed('data')),
      ).thenThrow(_errorWith('REVIEW_NOT_ELIGIBLE', 403));

      await expectLater(
        repository.createReview(_createRequest),
        throwsA(
          isA<AppException>().having(
            (e) => e.errorCode,
            'errorCode',
            'REVIEW_NOT_ELIGIBLE',
          ),
        ),
      );
    });

    test('surfaces REVIEW_DUPLICATED as a typed AppException', () async {
      when(
        dio.post<Map<String, dynamic>>(any, data: anyNamed('data')),
      ).thenThrow(_errorWith('REVIEW_DUPLICATED', 409));

      await expectLater(
        repository.createReview(_createRequest),
        throwsA(
          isA<AppException>().having(
            (e) => e.errorCode,
            'errorCode',
            'REVIEW_DUPLICATED',
          ),
        ),
      );
    });
  });

  group('updateReview', () {
    test(
      'PUTs the review id path with the body, returns typed review',
      () async {
        when(
          dio.put<Map<String, dynamic>>(any, data: anyNamed('data')),
        ).thenAnswer(
          (_) async => _envelope(
            '/api/v1/reviews/55',
            _reviewData()
              ..['rating'] = 4
              ..['comment'] = 'Good after a week',
          ),
        );

        final review = await repository.updateReview(55, _updateRequest);

        final captured = verify(
          dio.put<Map<String, dynamic>>(
            captureAny,
            data: captureAnyNamed('data'),
          ),
        ).captured;
        expect(captured[0], '/api/v1/reviews/55');
        expect(captured[1], _updateRequest.toJson());
        expect(review.id, 55);
        expect(review.rating, 4);
        expect(review.comment, 'Good after a week');
      },
    );

    test('surfaces REVIEW_FORBIDDEN as a typed AppException', () async {
      when(
        dio.put<Map<String, dynamic>>(any, data: anyNamed('data')),
      ).thenThrow(_errorWith('REVIEW_FORBIDDEN', 403));

      await expectLater(
        repository.updateReview(55, _updateRequest),
        throwsA(
          isA<AppException>().having(
            (e) => e.errorCode,
            'errorCode',
            'REVIEW_FORBIDDEN',
          ),
        ),
      );
    });

    test('surfaces REVIEW_NOT_FOUND as a typed AppException', () async {
      when(
        dio.put<Map<String, dynamic>>(any, data: anyNamed('data')),
      ).thenThrow(_errorWith('REVIEW_NOT_FOUND', 404));

      await expectLater(
        repository.updateReview(999, _updateRequest),
        throwsA(
          isA<AppException>().having(
            (e) => e.errorCode,
            'errorCode',
            'REVIEW_NOT_FOUND',
          ),
        ),
      );
    });
  });

  group('deleteReview', () {
    test('DELETEs the review id path', () async {
      when(
        dio.delete<void>(any),
      ).thenAnswer((_) async => _voidResponse('/api/v1/reviews/55'));

      await repository.deleteReview(55);

      final captured = verify(dio.delete<void>(captureAny)).captured;
      expect(captured[0], '/api/v1/reviews/55');
    });

    test('surfaces REVIEW_FORBIDDEN as a typed AppException', () async {
      when(
        dio.delete<void>(any),
      ).thenThrow(_errorWith('REVIEW_FORBIDDEN', 403));

      await expectLater(
        repository.deleteReview(55),
        throwsA(
          isA<AppException>().having(
            (e) => e.errorCode,
            'errorCode',
            'REVIEW_FORBIDDEN',
          ),
        ),
      );
    });

    test('surfaces REVIEW_NOT_FOUND as a typed AppException', () async {
      when(
        dio.delete<void>(any),
      ).thenThrow(_errorWith('REVIEW_NOT_FOUND', 404));

      await expectLater(
        repository.deleteReview(999),
        throwsA(
          isA<AppException>().having(
            (e) => e.errorCode,
            'errorCode',
            'REVIEW_NOT_FOUND',
          ),
        ),
      );
    });
  });
}
