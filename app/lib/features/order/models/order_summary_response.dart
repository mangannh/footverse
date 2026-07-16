import 'package:json_annotation/json_annotation.dart';

import '../../product/models/decimal_json.dart';
import 'order_status.dart';
import 'payment_status.dart';

part 'order_summary_response.g.dart';

/// A compact order for the caller's order-history list (dto-spec §15).
///
/// [total] is the snapshotted order total, rendered exactly as delivered
/// (dto-spec §1). [itemCount] is Σ of the order-item quantities — an aggregate
/// the server assembles, not the distinct-line count.
@JsonSerializable(createToJson: false)
class OrderSummaryResponse {
  const OrderSummaryResponse({
    required this.id,
    required this.orderCode,
    required this.status,
    required this.paymentStatus,
    required this.total,
    required this.itemCount,
    required this.createdAt,
  });

  factory OrderSummaryResponse.fromJson(Map<String, dynamic> json) =>
      _$OrderSummaryResponseFromJson(json);

  final int id;
  final String orderCode;
  final OrderStatus status;
  final PaymentStatus paymentStatus;
  @JsonKey(fromJson: decimalFromJson)
  final double total;
  final int itemCount;
  final DateTime createdAt;
}
