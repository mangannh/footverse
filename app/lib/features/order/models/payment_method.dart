import 'package:json_annotation/json_annotation.dart';

/// Payment method of an order (dto-spec §4, §15). `vnpay` is the sandbox-only
/// online gateway added in Sprint 13 Task 10.
enum PaymentMethod {
  @JsonValue('COD')
  cod,
  @JsonValue('VNPAY')
  vnpay,
}
