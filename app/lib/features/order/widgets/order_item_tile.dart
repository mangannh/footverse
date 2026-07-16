import 'package:flutter/material.dart';

import '../models/order_item_response.dart';

/// One line of an order (dto-spec §15): a thumbnail, the product name, the
/// colour / size snapshot, the server-computed `unitPrice`, the quantity, and the
/// server-computed `lineTotal`. It renders only — every money value is displayed
/// exactly as the server delivered it and the client computes nothing
/// (dto-spec §1).
class OrderItemTile extends StatelessWidget {
  const OrderItemTile({super.key, required this.item});

  final OrderItemResponse item;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _Thumbnail(imageUrl: item.productImageUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.productName,
                  style: textTheme.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.color} · ${item.size}',
                  style: textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.unitPrice} × ${item.quantity}',
                  style: textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text('${item.lineTotal}', style: textTheme.titleSmall),
        ],
      ),
    );
  }
}

/// The line thumbnail: the product image, or a placeholder when the line has no
/// image or the image fails to load (mirrors the cart line's thumbnail).
class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.imageUrl});

  final String? imageUrl;

  static const double _size = 56;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final placeholder = Container(
      width: _size,
      height: _size,
      color: colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.image_not_supported_outlined,
        color: colorScheme.outline,
      ),
    );

    final url = imageUrl;
    if (url == null || url.isEmpty) {
      return placeholder;
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url,
        width: _size,
        height: _size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => placeholder,
        loadingBuilder: (context, child, progress) => progress == null
            ? child
            : const SizedBox(
                width: _size,
                height: _size,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
      ),
    );
  }
}
