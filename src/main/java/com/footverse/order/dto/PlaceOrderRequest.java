package com.footverse.order.dto;

import java.util.List;

import org.hibernate.validator.constraints.UniqueElements;

import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;

/**
 * Request to place an order from the caller's selected cart items ({@code POST /orders}, dto-spec
 * §15, validation-spec §10). Partial checkout is supported: only the listed cart items become the
 * order and are removed from the cart afterwards.
 *
 * <p>Ownership of the cart items and the address, coupon applicability, and per-variant stock are
 * business rules enforced by the service, not field-level constraints.</p>
 *
 * @param cartItemIds the selected cart item ids to purchase; required, non-empty, each positive and
 *                    unique (a duplicate id is rejected as {@code 400 VALIDATION_ERROR},
 *                    sprint-4-plan assumption 8)
 * @param addressId   the shipping address to snapshot onto the order; required and positive
 * @param couponCode  optional coupon code to apply; at most 64 characters
 * @param note        optional customer note; at most 500 characters
 */
public record PlaceOrderRequest(
        @NotEmpty @UniqueElements List<@Positive Long> cartItemIds,
        @NotNull @Positive Long addressId,
        @Size(max = 64) String couponCode,
        @Size(max = 500) String note) {
}
