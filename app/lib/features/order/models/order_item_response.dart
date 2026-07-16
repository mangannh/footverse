import 'package:json_annotation/json_annotation.dart';

import '../../product/models/decimal_json.dart';

part 'order_item_response.g.dart';

/// One line of an order, returned with its checkout snapshots (dto-spec §15).
///
/// The snapshot fields are frozen at checkout and returned exactly as persisted;
/// [unitPrice] and [lineTotal] are server-computed money the client only renders
/// (dto-spec §1; business-rules → Order Item).
@JsonSerializable(createToJson: false)
class OrderItemResponse {
  const OrderItemResponse({
    required this.id,
    required this.productVariantId,
    required this.productName,
    required this.color,
    required this.size,
    required this.unitPrice,
    required this.quantity,
    required this.lineTotal,
    this.productImageUrl,
  });

  factory OrderItemResponse.fromJson(Map<String, dynamic> json) =>
      _$OrderItemResponseFromJson(json);

  final int id;
  final int productVariantId;
  final String productName;
  final String? productImageUrl;
  final String color;
  final String size;
  @JsonKey(fromJson: decimalFromJson)
  final double unitPrice;
  final int quantity;
  @JsonKey(fromJson: decimalFromJson)
  final double lineTotal;
}
