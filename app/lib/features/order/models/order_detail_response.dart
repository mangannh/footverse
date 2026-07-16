import 'package:json_annotation/json_annotation.dart';

import '../../product/models/decimal_json.dart';
import 'order_item_response.dart';
import 'order_status.dart';
import 'payment_method.dart';
import 'payment_status.dart';

part 'order_detail_response.g.dart';

/// The full detail of an order with its checkout snapshots (dto-spec §15).
///
/// Money and shipping fields are frozen at checkout and returned exactly as
/// persisted; the client renders them and never recomputes them (dto-spec §1;
/// business-rules → Order). [couponCode], [note], [cancelledAt], and
/// [deliveredAt] are present only when they apply.
@JsonSerializable(createToJson: false)
class OrderDetailResponse {
  const OrderDetailResponse({
    required this.id,
    required this.orderCode,
    required this.status,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.subtotal,
    required this.discountAmount,
    required this.shippingFee,
    required this.total,
    required this.shippingRecipientName,
    required this.shippingRecipientPhone,
    required this.shippingProvince,
    required this.shippingDistrict,
    required this.shippingWard,
    required this.shippingStreetAddress,
    required this.items,
    required this.createdAt,
    this.couponCode,
    this.note,
    this.cancelledAt,
    this.deliveredAt,
  });

  factory OrderDetailResponse.fromJson(Map<String, dynamic> json) =>
      _$OrderDetailResponseFromJson(json);

  final int id;
  final String orderCode;
  final OrderStatus status;
  final PaymentMethod paymentMethod;
  final PaymentStatus paymentStatus;
  @JsonKey(fromJson: decimalFromJson)
  final double subtotal;
  @JsonKey(fromJson: decimalFromJson)
  final double discountAmount;
  @JsonKey(fromJson: decimalFromJson)
  final double shippingFee;
  @JsonKey(fromJson: decimalFromJson)
  final double total;
  final String? couponCode;
  final String shippingRecipientName;
  final String shippingRecipientPhone;
  final String shippingProvince;
  final String shippingDistrict;
  final String shippingWard;
  final String shippingStreetAddress;
  final String? note;
  final List<OrderItemResponse> items;
  final DateTime createdAt;
  final DateTime? cancelledAt;
  final DateTime? deliveredAt;
}
