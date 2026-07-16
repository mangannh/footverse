import 'package:json_annotation/json_annotation.dart';

/// Payment status of an order (dto-spec §4, §15). An order starts `UNPAID` and
/// becomes `PAID` when delivered.
enum PaymentStatus {
  @JsonValue('UNPAID')
  unpaid,
  @JsonValue('PAID')
  paid,
}
