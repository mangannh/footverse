import 'package:json_annotation/json_annotation.dart';

part 'coupon_preview_request.g.dart';

/// The write body for previewing a checkout summary (dto-spec §14).
///
/// [code] is optional (dto-spec §14, `W, O`): omitted when unset so the wire body
/// carries only what the caller provided. [cartItemIds] is serialized as entered —
/// a duplicate id is not removed here; the server's `@UniqueElements` remains the
/// authority (validation-spec §9). This model only serializes the wire body.
@JsonSerializable(createFactory: false, includeIfNull: false)
class CouponPreviewRequest {
  const CouponPreviewRequest({required this.cartItemIds, this.code});

  final String? code;
  final List<int> cartItemIds;

  Map<String, dynamic> toJson() => _$CouponPreviewRequestToJson(this);
}
