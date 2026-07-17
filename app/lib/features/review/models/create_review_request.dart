import 'package:json_annotation/json_annotation.dart';

part 'create_review_request.g.dart';

/// The write body for creating a product review (dto-spec §16).
///
/// The caller must have a DELIVERED order containing [productId]; eligibility,
/// the one-review-per-product rule, and ownership are all server-authoritative,
/// so this model only serializes the wire body. [comment] is optional
/// (dto-spec §16, `W, O`): omitted from the JSON when unset, exactly as the
/// Sprint 8 request models omit their optionals — the wire body carries only
/// what the caller provided.
@JsonSerializable(createFactory: false, includeIfNull: false)
class CreateReviewRequest {
  const CreateReviewRequest({
    required this.productId,
    required this.rating,
    this.comment,
  });

  final int productId;

  /// 1–5.
  final int rating;
  final String? comment;

  Map<String, dynamic> toJson() => _$CreateReviewRequestToJson(this);
}
