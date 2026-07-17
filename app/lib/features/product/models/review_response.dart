import 'package:json_annotation/json_annotation.dart';

part 'review_response.g.dart';

/// A single product review (dto-spec §16). The client shows an "edited"
/// indicator when [updatedAt] differs from [createdAt].
///
/// [productId] links the review to its product and [userId] is the author's
/// user id; together they let the client recognise the caller's own review
/// (`review.userId == currentUser.id`) to offer Edit / Delete. Authorization
/// stays server-enforced.
@JsonSerializable(createToJson: false)
class ReviewResponse {
  const ReviewResponse({
    required this.id,
    required this.productId,
    required this.userId,
    required this.userFullName,
    required this.rating,
    required this.createdAt,
    required this.updatedAt,
    this.userAvatarUrl,
    this.comment,
  });

  factory ReviewResponse.fromJson(Map<String, dynamic> json) =>
      _$ReviewResponseFromJson(json);

  final int id;

  /// The reviewed product's id.
  final int productId;

  /// The review author's user id.
  final int userId;
  final String userFullName;
  final String? userAvatarUrl;

  /// 1–5.
  final int rating;
  final String? comment;
  final DateTime createdAt;
  final DateTime updatedAt;
}
