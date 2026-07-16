// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_detail_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OrderDetailResponse _$OrderDetailResponseFromJson(Map<String, dynamic> json) =>
    OrderDetailResponse(
      id: (json['id'] as num).toInt(),
      orderCode: json['orderCode'] as String,
      status: $enumDecode(_$OrderStatusEnumMap, json['status']),
      paymentMethod: $enumDecode(_$PaymentMethodEnumMap, json['paymentMethod']),
      paymentStatus: $enumDecode(_$PaymentStatusEnumMap, json['paymentStatus']),
      subtotal: decimalFromJson(json['subtotal']),
      discountAmount: decimalFromJson(json['discountAmount']),
      shippingFee: decimalFromJson(json['shippingFee']),
      total: decimalFromJson(json['total']),
      shippingRecipientName: json['shippingRecipientName'] as String,
      shippingRecipientPhone: json['shippingRecipientPhone'] as String,
      shippingProvince: json['shippingProvince'] as String,
      shippingDistrict: json['shippingDistrict'] as String,
      shippingWard: json['shippingWard'] as String,
      shippingStreetAddress: json['shippingStreetAddress'] as String,
      items: (json['items'] as List<dynamic>)
          .map((e) => OrderItemResponse.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      couponCode: json['couponCode'] as String?,
      note: json['note'] as String?,
      cancelledAt: json['cancelledAt'] == null
          ? null
          : DateTime.parse(json['cancelledAt'] as String),
      deliveredAt: json['deliveredAt'] == null
          ? null
          : DateTime.parse(json['deliveredAt'] as String),
    );

const _$OrderStatusEnumMap = {
  OrderStatus.pending: 'PENDING',
  OrderStatus.confirmed: 'CONFIRMED',
  OrderStatus.shipping: 'SHIPPING',
  OrderStatus.delivered: 'DELIVERED',
  OrderStatus.cancelled: 'CANCELLED',
};

const _$PaymentMethodEnumMap = {PaymentMethod.cod: 'COD'};

const _$PaymentStatusEnumMap = {
  PaymentStatus.unpaid: 'UNPAID',
  PaymentStatus.paid: 'PAID',
};
