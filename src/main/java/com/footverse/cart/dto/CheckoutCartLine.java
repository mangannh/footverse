package com.footverse.cart.dto;

/**
 * The minimal projection of a caller's cart line that checkout consumes: the line id, the variant
 * it holds, and its quantity.
 *
 * <p>This record is internal to the {@code cart} module and is never serialized — it exists only so
 * {@code OrderService} can read the caller's selected lines through {@code CartService} without
 * reaching into {@code CartItemRepository} or importing the
 * {@link com.footverse.cart.entity.CartItem} entity across modules (architecture-spec §6/§7). It is
 * not a public API DTO and is never returned by a controller, mirroring the {@code WishlistAddResult}
 * precedent.</p>
 *
 * @param cartItemId       the cart line id
 * @param productVariantId the variant the line holds
 * @param quantity         the quantity the line holds
 */
public record CheckoutCartLine(
        Long cartItemId,
        Long productVariantId,
        int quantity) {
}
