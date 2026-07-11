package com.footverse.order.dto;

import java.math.BigDecimal;

/**
 * One line of an order, returned with its checkout snapshots (dto-spec §15).
 *
 * @param id               the order item id
 * @param productVariantId the variant id, kept for traceability
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
        String productName,
        String productImageUrl,
        String color,
        String size,
        BigDecimal unitPrice,
        int quantity,
        BigDecimal lineTotal) {
}
