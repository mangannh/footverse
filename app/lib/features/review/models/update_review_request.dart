import 'package:json_annotation/json_annotation.dart';

part 'update_review_request.g.dart';

/// The write body for editing the caller's own review (dto-spec §16).
///
/// Only [rating] and [comment] are editable — the review's product is immutable,
/// so no `productId` is sent. Ownership is server-enforced. [comment] is optional
/// (dto-spec §16, `W, O`): omitted from the JSON when unset, mirroring the
/// Sprint 8 request models. This model only serializes the wire body.
@JsonSerializable(createFactory: false, includeIfNull: false)
class UpdateReviewRequest {
  const UpdateReviewRequest({required this.rating, this.comment});

  /// 1–5.
  final int rating;
  final String? comment;

  Map<String, dynamic> toJson() => _$UpdateReviewRequestToJson(this);
}
