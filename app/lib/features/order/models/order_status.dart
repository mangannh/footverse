import 'package:json_annotation/json_annotation.dart';

/// Lifecycle status of an order (dto-spec §4, §15).
enum OrderStatus {
  @JsonValue('PENDING')
  pending,
  @JsonValue('CONFIRMED')
  confirmed,
  @JsonValue('SHIPPING')
  shipping,
  @JsonValue('DELIVERED')
  delivered,
  @JsonValue('CANCELLED')
  cancelled,
}
