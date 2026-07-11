package com.footverse.cart.service;

import java.util.Collection;
import java.util.List;

import com.footverse.cart.dto.AddCartItemRequest;
import com.footverse.cart.dto.CartResponse;
import com.footverse.cart.dto.CheckoutCartLine;
import com.footverse.cart.dto.UpdateCartItemRequest;

/**
 * Cart-module façade for the caller's shopping cart. Every operation is scoped to the authenticated
 * user resolved through {@code CurrentUserProvider} (security-spec §7) — no method accepts a user
 * id or a cart id, so a caller can never reach another user's cart. Each operation returns the
 * whole cart with its server-computed {@code subtotal} and {@code itemCount} (dto-spec §1).
 */
public interface CartService {

    /**
     * Returns the caller's cart. A caller who has never added an item has no cart row yet; that is
     * reported as an empty cart, not an error.
     *
     * @return the caller's cart
     */
    CartResponse getMyCart();

    /**
     * Adds a quantity of a variant to the caller's cart, creating the cart on the first add. The
     * variant must exist and be {@code ACTIVE}. When the cart already holds the variant, the
     * requested quantity is added to the existing line rather than inserting a second one
     * (business-rules → Shopping Cart); the resulting quantity must not exceed available stock.
     *
     * @param request the validated add payload
     * @return the caller's cart after the add
     */
    CartResponse addItem(AddCartItemRequest request);

    /**
     * Replaces the quantity of one of the caller's cart lines. The new quantity must not exceed the
     * variant's available stock.
     *
     * @param cartItemId the id of the cart line to update
     * @param request    the validated update payload
     * @return the caller's cart after the update
     */
    CartResponse updateItemQuantity(Long cartItemId, UpdateCartItemRequest request);

    /**
     * Removes one of the caller's cart lines. Removing the last line leaves the cart row in place
     * (business-rules → Shopping Cart).
     *
     * @param cartItemId the id of the cart line to remove
     * @return the caller's cart after the removal
     */
    CartResponse removeItem(Long cartItemId);

    /**
     * Resolves the caller's selected cart lines for checkout, reading each under a
     * {@code PESSIMISTIC_WRITE} lock held for the remainder of the caller's transaction so two
     * concurrent checkouts cannot both consume the same lines (Checkout Concurrency Protection,
     * architecture-spec §19). Every requested id must belong to the caller: an id owned by another
     * user is a {@code 403}, an id that does not exist is a {@code 404}. The returned
     * {@link CheckoutCartLine}s are a module-internal projection, never the {@code CartItem} entity —
     * so {@code OrderService} consumes cart data through this façade and never the repository
     * (architecture-spec §6/§7).
     *
     * <p>The lock is <strong>concurrency control, not a new business rule</strong>: it changes
     * nothing about what checkout means; it only makes each selected line a one-shot input that a
     * single transaction may consume at a time.</p>
     *
     * @param cartItemIds the caller's selected cart item ids (unique; the request DTO rejects
     *                    duplicates before this call)
     * @return the caller's selected cart lines, locked, in the requested order
     * @throws com.footverse.common.exception.BusinessException {@code 403 CART_ITEM_FORBIDDEN} when
     *         an id belongs to another user's cart
     * @throws com.footverse.common.exception.ResourceNotFoundException {@code 404 CART_ITEM_NOT_FOUND}
     *         when an id does not exist
     */
    List<CheckoutCartLine> resolveCheckoutItems(Collection<Long> cartItemIds);

    /**
     * Resolves the caller's selected cart lines for a read-only checkout preview, with a plain
     * caller-scoped read and <strong>no lock</strong> — the preview prices the lines but consumes
     * nothing, so it must not contend with live checkouts (sprint-4-plan item 08). Ownership is
     * enforced exactly as {@link #resolveCheckoutItems(Collection)}: another user's id is a
     * {@code 403}, an unknown id a {@code 404}. Returns the same module-internal
     * {@link CheckoutCartLine} projection, never the {@code CartItem} entity.
     *
     * @param cartItemIds the caller's selected cart item ids
     * @return the caller's selected cart lines, unlocked, in the requested order
     * @throws com.footverse.common.exception.BusinessException {@code 403 CART_ITEM_FORBIDDEN} when
     *         an id belongs to another user's cart
     * @throws com.footverse.common.exception.ResourceNotFoundException {@code 404 CART_ITEM_NOT_FOUND}
     *         when an id does not exist
     */
    List<CheckoutCartLine> resolvePreviewItems(Collection<Long> cartItemIds);

    /**
     * Removes the caller's given cart lines after a successful checkout, scoped to the caller so only
     * their own listed lines are deleted — never a line outside the list and never the {@code cart}
     * row itself (business-rules → Checkout). No-op when the caller has no cart.
     *
     * @param cartItemIds the checked-out cart item ids to remove
     */
    void removeCheckedOutItems(Collection<Long> cartItemIds);
}
