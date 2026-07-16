// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'coupon_preview_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CouponPreviewResponse _$CouponPreviewResponseFromJson(
  Map<String, dynamic> json,
) => CouponPreviewResponse(
  subtotal: decimalFromJson(json['subtotal']),
  discountAmount: decimalFromJson(json['discountAmount']),
  shippingFee: decimalFromJson(json['shippingFee']),
  total: decimalFromJson(json['total']),
  code: json['code'] as String?,
  name: json['name'] as String?,
);
