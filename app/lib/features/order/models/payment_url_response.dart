import 'package:json_annotation/json_annotation.dart';

part 'payment_url_response.g.dart';

/// The signed VNPay sandbox payment URL for a `VNPAY` order (dto-spec §15,
/// `POST /orders/{id}/payment`, Sprint 13 Task 10).
@JsonSerializable(createToJson: false)
class PaymentUrlResponse {
  const PaymentUrlResponse({
    required this.paymentUrl,
    required this.txnRef,
    required this.expiresAt,
  });

  factory PaymentUrlResponse.fromJson(Map<String, dynamic> json) =>
      _$PaymentUrlResponseFromJson(json);

  /// The signed VNPay sandbox payment URL to open in the WebView.
  final String paymentUrl;

  /// The unique transaction reference the return callback resolves.
  final String txnRef;

  /// When the payment URL expires.
  final DateTime expiresAt;
}
