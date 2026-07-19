// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'place_order_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$PlaceOrderRequestToJson(PlaceOrderRequest instance) =>
    <String, dynamic>{
      'cartItemIds': instance.cartItemIds,
      'addressId': instance.addressId,
      'couponCode': ?instance.couponCode,
      'note': ?instance.note,
      'paymentMethod': ?_$PaymentMethodEnumMap[instance.paymentMethod],
    };

const _$PaymentMethodEnumMap = {
  PaymentMethod.cod: 'COD',
  PaymentMethod.vnpay: 'VNPAY',
};
