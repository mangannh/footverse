import 'package:json_annotation/json_annotation.dart';

/// Payment method of an order (dto-spec §4, §15). V1 supports cash on delivery
/// only.
enum PaymentMethod {
  @JsonValue('COD')
  cod,
}
