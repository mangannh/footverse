import 'package:json_annotation/json_annotation.dart';

import '../../product/models/decimal_json.dart';

part 'coupon_preview_response.g.dart';

/// The full server-computed checkout summary for the previewed items
/// (dto-spec §14).
///
/// Every amount is computed by the server and rendered exactly as delivered; the
/// client never computes discounts or totals (dto-spec §1; business-rules →
/// Checkout Preview). [code] / [name] are present only when a valid coupon was
/// supplied.
@JsonSerializable(createToJson: false)
class CouponPreviewResponse {
  const CouponPreviewResponse({
    required this.subtotal,
    required this.discountAmount,
    required this.shippingFee,
    required this.total,
    this.code,
    this.name,
  });

  factory CouponPreviewResponse.fromJson(Map<String, dynamic> json) =>
      _$CouponPreviewResponseFromJson(json);

  final String? code;
  final String? name;
  @JsonKey(fromJson: decimalFromJson)
  final double subtotal;
  @JsonKey(fromJson: decimalFromJson)
  final double discountAmount;
  @JsonKey(fromJson: decimalFromJson)
  final double shippingFee;
  @JsonKey(fromJson: decimalFromJson)
  final double total;
}
