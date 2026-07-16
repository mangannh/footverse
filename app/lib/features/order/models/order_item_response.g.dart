// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_item_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OrderItemResponse _$OrderItemResponseFromJson(Map<String, dynamic> json) =>
    OrderItemResponse(
      id: (json['id'] as num).toInt(),
      productVariantId: (json['productVariantId'] as num).toInt(),
      productName: json['productName'] as String,
      color: json['color'] as String,
      size: json['size'] as String,
      unitPrice: decimalFromJson(json['unitPrice']),
      quantity: (json['quantity'] as num).toInt(),
      lineTotal: decimalFromJson(json['lineTotal']),
      productImageUrl: json['productImageUrl'] as String?,
    );
