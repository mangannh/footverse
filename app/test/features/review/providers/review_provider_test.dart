import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:footverse/core/error/app_exception.dart';
import 'package:footverse/features/auth/models/role.dart';
import 'package:footverse/features/auth/models/user_response.dart';
import 'package:footverse/features/product/models/review_response.dart';
import 'package:footverse/features/profile/repositories/profile_repository.dart';
import 'package:footverse/features/review/models/create_review_request.dart';
import 'package:footverse/features/review/models/update_review_request.dart';
import 'package:footverse/features/review/providers/review_provider.dart';
import 'package:footverse/features/review/repositories/review_repository.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'review_provider_test.mocks.dart';

const int _productId = 42;

UserResponse _user(int id) => UserResponse(
  id: id,
  email: 'u$id@example.com',
  fullName: 'User $id',
  phone: '0900000000',
  role: Role.customer,
  enabled: true,
  createdAt: DateTime.parse('2025-01-15T10:30:00'),
  updatedAt: DateTime.parse('2025-01-15T10:30:00'),
);

ReviewResponse _review({
  required int id,
  required int userId,
  int rating = 5,
  String? comment,
}) => ReviewResponse(
  id: id,
  productId: _productId,
  userId: userId,
  userFullName: 'User $userId',
  rating: rating,
  comment: comment,
  createdAt: DateTime.parse('2025-01-15T10:30:00'),
  updatedAt: DateTime.parse('2025-01-15T10:30:00'),
);

AppException _error(String code, int status) =>
    AppException(message: 'error', statusCode: status, errorCode: code);

@GenerateNiceMocks([
  MockSpec<ReviewRepository>(),
  MockSpec<ProfileRepository>(),
])
void main() {
  late MockReviewRepository reviewRepository;
  late MockProfileRepository profileRepository;
  late int reloadCount;
  late ReviewProvider provider;

  setUp(() {
    reviewRepository = MockReviewRepository();
    profileRepository = MockProfileRepository();
    reloadCount = 0;
    provider = ReviewProvider(
      reviewRepository: reviewRepository,
      profileRepository: profileRepository,
      productId: _productId,
      onReviewsChanged: () => reloadCount++,
    );
  });

  group('identity + own-review resolution', () {
    test('resolves the caller\'s own review by userId after loading '
        'identity', () async {
      when(profileRepository.getMe()).thenAnswer((_) async => _user(7));

      await provider.loadCurrentUser();

      expect(provider.currentUserId, 7);
      expect(provider.identityLoaded, isTrue);
      final own = provider.ownReviewFrom(<ReviewResponse>[
        _review(id: 1, userId: 9),
        _review(id: 2, userId: 7),
      ]);
      expect(own?.id, 2);
      expect(
        provider.ownReviewFrom(<ReviewResponse>[_review(id: 3, userId: 9)]),
        isNull,
      );
    });

    test('a guest (no identity loaded) has no own review and never calls '
        'getMe', () {
      expect(provider.currentUserId, isNull);
      expect(
        provider.ownReviewFrom(<ReviewResponse>[_review(id: 1, userId: 7)]),
        isNull,
      );
      verifyNever(profileRepository.getMe());
    });

    test(
      'a failed identity load degrades to a null id (best-effort)',
      () async {
        when(profileRepository.getMe()).thenThrow(_error('BOOM', 500));

        await provider.loadCurrentUser();

        expect(provider.currentUserId, isNull);
        expect(provider.identityLoaded, isTrue);
      },
    );
  });

  group('submit', () {
    test('creates the review, holds it, and triggers the reload', () async {
      final created = _review(id: 10, userId: 7, comment: 'Great');
      when(reviewRepository.createReview(any)).thenAnswer((_) async => created);

      await provider.submit(5, 'Great');

      final request =
          verify(reviewRepository.createReview(captureAny)).captured.single
              as CreateReviewRequest;
      expect(request.productId, _productId);
      expect(request.rating, 5);
      expect(request.comment, 'Great');
      // The held write result is authoritative even before the list reload, so
      // ownReviewFrom returns it without any list scan.
      expect(provider.ownReviewFrom(const <ReviewResponse>[]), same(created));
      expect(reloadCount, 1);
      expect(provider.isMutating, isFalse);
    });

    test('rethrows REVIEW_NOT_ELIGIBLE and triggers no reload', () async {
      when(
        reviewRepository.createReview(any),
      ).thenThrow(_error('REVIEW_NOT_ELIGIBLE', 403));

      await expectLater(
        provider.submit(5, null),
        throwsA(
          isA<AppException>().having(
            (e) => e.errorCode,
            'errorCode',
            'REVIEW_NOT_ELIGIBLE',
          ),
        ),
      );
      expect(reloadCount, 0);
      expect(provider.ownReviewFrom(const <ReviewResponse>[]), isNull);
      expect(provider.isMutating, isFalse);
    });

    test('rethrows REVIEW_DUPLICATED and triggers no reload', () async {
      when(
        reviewRepository.createReview(any),
      ).thenThrow(_error('REVIEW_DUPLICATED', 409));

      await expectLater(
        provider.submit(5, null),
        throwsA(
          isA<AppException>().having(
            (e) => e.errorCode,
            'errorCode',
            'REVIEW_DUPLICATED',
          ),
        ),
      );
      expect(reloadCount, 0);
    });
  });

  group('edit', () {
    test('updates the review, holds it, and triggers the reload', () async {
      final existing = _review(id: 10, userId: 7);
      final updated = _review(id: 10, userId: 7, rating: 4, comment: 'ok');
      when(
        reviewRepository.updateReview(any, any),
      ).thenAnswer((_) async => updated);

      await provider.edit(existing, 4, 'ok');

      final captured = verify(
        reviewRepository.updateReview(captureAny, captureAny),
      ).captured;
      expect(captured[0], 10);
      final request = captured[1] as UpdateReviewRequest;
      expect(request.rating, 4);
      expect(request.comment, 'ok');
      expect(provider.ownReviewFrom(const <ReviewResponse>[]), same(updated));
      expect(reloadCount, 1);
    });

    test('rethrows REVIEW_FORBIDDEN and triggers no reload', () async {
      final existing = _review(id: 10, userId: 7);
      when(
        reviewRepository.updateReview(any, any),
      ).thenThrow(_error('REVIEW_FORBIDDEN', 403));

      await expectLater(
        provider.edit(existing, 4, null),
        throwsA(
          isA<AppException>().having(
            (e) => e.errorCode,
            'errorCode',
            'REVIEW_FORBIDDEN',
          ),
        ),
      );
      expect(reloadCount, 0);
    });
  });

  group('remove', () {
    test(
      'deletes the review, clears ownership, and triggers the reload',
      () async {
        final existing = _review(id: 10, userId: 7);
        when(reviewRepository.deleteReview(any)).thenAnswer((_) async {});

        await provider.remove(existing);

        verify(reviewRepository.deleteReview(10)).called(1);
        // hasWritten wins over a list scan, so a stale list still holding the
        // review no longer resurrects ownership.
        expect(provider.ownReviewFrom(<ReviewResponse>[existing]), isNull);
        expect(reloadCount, 1);
      },
    );

    test('rethrows REVIEW_NOT_FOUND and triggers no reload', () async {
      final existing = _review(id: 10, userId: 7);
      when(
        reviewRepository.deleteReview(any),
      ).thenThrow(_error('REVIEW_NOT_FOUND', 404));

      await expectLater(
        provider.remove(existing),
        throwsA(
          isA<AppException>().having(
            (e) => e.errorCode,
            'errorCode',
            'REVIEW_NOT_FOUND',
          ),
        ),
      );
      expect(reloadCount, 0);
    });
  });

  group('single-flight', () {
    test('a second write while one is in flight is ignored', () async {
      final completer = Completer<ReviewResponse>();
      when(
        reviewRepository.createReview(any),
      ).thenAnswer((_) => completer.future);

      final first = provider.submit(5, null);
      final second = provider.submit(5, null);
      expect(provider.isMutating, isTrue);

      completer.complete(_review(id: 10, userId: 7));
      await first;
      await second;

      verify(reviewRepository.createReview(any)).called(1);
      expect(reloadCount, 1);
      expect(provider.isMutating, isFalse);
    });
  });
}
