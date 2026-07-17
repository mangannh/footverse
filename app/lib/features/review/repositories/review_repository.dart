import 'package:dio/dio.dart';

import '../../../core/error/app_exception.dart';
import '../../../shared/models/api_response.dart';
import '../../product/models/review_response.dart';
import '../models/create_review_request.dart';
import '../models/update_review_request.dart';

/// The typed client of the three frozen customer review-write endpoints
/// (dto-spec §20): create, edit, and delete the caller's own product review.
///
/// It only calls the API, unwraps the [ApiResponse] envelope, and returns the
/// typed payload — throwing [AppException] on failure (the injected [Dio]'s
/// `ErrorInterceptor` has already mapped the transport error, and its
/// `AuthInterceptor` has attached the CUSTOMER bearer). It holds no business
/// logic and touches no storage or navigation, so every enveloped business error
/// (`REVIEW_NOT_ELIGIBLE`, `REVIEW_DUPLICATED`, `REVIEW_FORBIDDEN`,
/// `REVIEW_NOT_FOUND` — error-spec §8.12) propagates unchanged as an
/// [AppException] carrying the registry code. The reused [ReviewResponse] is the
/// shared model owned by the product feature (Sprint 9 Design Decision 1).
class ReviewRepository {
  const ReviewRepository(this._dio);

  static const String _reviewsPath = '/api/v1/reviews';

  final Dio _dio;

  /// `POST /reviews` — create the caller's review for a purchased product.
  Future<ReviewResponse> createReview(CreateReviewRequest request) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        _reviewsPath,
        data: request.toJson(),
      );
      return _unwrapReview(response);
    } on DioException catch (exception) {
      throw _asAppException(exception);
    }
  }

  /// `PUT /reviews/{id}` — edit the caller's own review.
  Future<ReviewResponse> updateReview(
    int id,
    UpdateReviewRequest request,
  ) async {
    try {
      final response = await _dio.put<Map<String, dynamic>>(
        '$_reviewsPath/$id',
        data: request.toJson(),
      );
      return _unwrapReview(response);
    } on DioException catch (exception) {
      throw _asAppException(exception);
    }
  }

  /// `DELETE /reviews/{id}` — permanently delete the caller's own review.
  Future<void> deleteReview(int id) async {
    try {
      await _dio.delete<void>('$_reviewsPath/$id');
    } on DioException catch (exception) {
      throw _asAppException(exception);
    }
  }

  ReviewResponse _unwrapReview(Response<Map<String, dynamic>> response) {
    final envelope = ApiResponse<ReviewResponse>.fromJson(
      response.data!,
      (json) => ReviewResponse.fromJson(json! as Map<String, dynamic>),
    );
    return envelope.data!;
  }

  AppException _asAppException(DioException exception) {
    final error = exception.error;
    if (error is AppException) {
      return error;
    }
    return const AppException(message: 'An unexpected error occurred');
  }
}
