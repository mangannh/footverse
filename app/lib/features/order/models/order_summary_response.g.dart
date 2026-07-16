// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_summary_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OrderSummaryResponse _$OrderSummaryResponseFromJson(
  Map<String, dynamic> json,
) => OrderSummaryResponse(
  id: (json['id'] as num).toInt(),
  orderCode: json['orderCode'] as String,
  status: $enumDecode(_$OrderStatusEnumMap, json['status']),
  paymentStatus: $enumDecode(_$PaymentStatusEnumMap, json['paymentStatus']),
  total: decimalFromJson(json['total']),
  itemCount: (json['itemCount'] as num).toInt(),
  createdAt: DateTime.parse(json['createdAt'] as String),
);

const _$OrderStatusEnumMap = {
  OrderStatus.pending: 'PENDING',
  OrderStatus.confirmed: 'CONFIRMED',
  OrderStatus.shipping: 'SHIPPING',
  OrderStatus.delivered: 'DELIVERED',
  OrderStatus.cancelled: 'CANCELLED',
};

const _$PaymentStatusEnumMap = {
  PaymentStatus.unpaid: 'UNPAID',
  PaymentStatus.paid: 'PAID',
};
