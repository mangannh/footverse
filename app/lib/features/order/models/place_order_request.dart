import 'package:json_annotation/json_annotation.dart';

import 'payment_method.dart';

part 'place_order_request.g.dart';

/// The write body for placing an order from selected cart items (dto-spec §15).
///
/// Partial checkout is supported: only the listed [cartItemIds] become the order.
/// [couponCode], [note], and [paymentMethod] are optional (dto-spec §15, `W, O`):
/// omitted when unset so the wire body carries only what the caller provided.
/// [paymentMethod] is left unset for `COD` (Sprint 13 Task 10) — the server
/// already defaults an absent value to `COD` (dto-spec §15, validation-spec §10),
/// so the client never sends the string `"COD"`, `null`, or an empty value for
/// it; only an explicit `VNPAY` choice is ever serialized. [cartItemIds] is
/// serialized as entered — a duplicate id is not removed here; the server's
/// `@UniqueElements` remains the authority (validation-spec §10). This model only
/// serializes the wire body.
@JsonSerializable(createFactory: false, includeIfNull: false)
class PlaceOrderRequest {
  const PlaceOrderRequest({
    required this.cartItemIds,
    required this.addressId,
    this.couponCode,
    this.note,
    this.paymentMethod,
  });

  final List<int> cartItemIds;
  final int addressId;
  final String? couponCode;
  final String? note;
  final PaymentMethod? paymentMethod;

  Map<String, dynamic> toJson() => _$PlaceOrderRequestToJson(this);
}
