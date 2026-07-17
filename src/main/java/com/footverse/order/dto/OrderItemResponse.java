package com.footverse.order.dto;

import java.math.BigDecimal;

/**
 * One line of an order, returned with its checkout snapshots (dto-spec §15).
 *
 * <p>{@code productId} is the current product the line's variant belongs to (not a snapshot): it lets
 * the client navigate from a delivered order line to the product detail to review it. The order line
 * itself stores only its {@code productVariantId} (database-spec §12), so the owning product id is
 * resolved by the service through {@code ProductVariantService}, never by the pure mapper.</p>
 *
 * @param id               the order item id
 * @param productVariantId the variant id, kept for traceability
 * @param productId        the id of the product the variant belongs to
 * @param productName      the product name snapshotted at checkout
 * @param productImageUrl  the primary image URL snapshotted at checkout, if any
 * @param color            the variant color snapshotted at checkout
 * @param size             the variant size snapshotted at checkout
 * @param unitPrice        the unit price actually paid, snapshotted at checkout
 * @param quantity         the purchased quantity
 * @param lineTotal        {@code unitPrice × quantity}
 */
public record OrderItemResponse(
        Long id,
        Long productVariantId,
        Long productId,
        String productName,
        String productImageUrl,
        String color,
        String size,
        BigDecimal unitPrice,
        int quantity,
        BigDecimal lineTotal) {
}
