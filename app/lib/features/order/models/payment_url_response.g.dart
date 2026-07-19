// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment_url_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PaymentUrlResponse _$PaymentUrlResponseFromJson(Map<String, dynamic> json) =>
    PaymentUrlResponse(
      paymentUrl: json['paymentUrl'] as String,
      txnRef: json['txnRef'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
    );
