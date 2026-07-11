package com.footverse.cart.repository;

import java.util.Collection;
import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.footverse.cart.entity.CartItem;

import jakarta.persistence.LockModeType;

/**
 * Data access for {@link CartItem}. Standard CRUD is inherited from {@link JpaRepository}; the
 * cart-scoped reads below serve {@code CartService}, which is the only caller.
 */
public interface CartItemRepository extends JpaRepository<CartItem, Long> {

    /**
     * Returns every line of a cart, for assembling the cart response.
     *
     * @param cartId the owning cart id
     * @return the cart's lines (empty when the cart holds none)
     */
    List<CartItem> findByCartId(Long cartId);

    /**
     * Returns the line holding a given variant in a cart, so the service can merge a repeated add
     * into it. At most one exists, by the {@code (cart_id, product_variant_id)} unique constraint.
     *
     * @param cartId           the owning cart id
     * @param productVariantId the product variant id
     * @return the cart line, or empty when the cart does not hold that variant
     */
    Optional<CartItem> findByCartIdAndProductVariantId(Long cartId, Long productVariantId);

    /**
     * Returns a line only when it belongs to the given cart, so the service can resolve and
     * ownership-check in one read.
     *
     * @param id     the cart item id
     * @param cartId the owning cart id
     * @return the cart line, or empty when it does not exist or belongs to another cart
     */
    Optional<CartItem> findByIdAndCartId(Long id, Long cartId);

    /**
     * Returns the given cart's lines among the supplied ids, each acquired under a
     * {@code PESSIMISTIC_WRITE} row lock, ordered by ascending id. Mirrors the Sprint 2 locking
     * precedent {@code findByIdAndDeletedAtIsNullForUpdate}; the ascending order gives checkout a
     * deterministic lock-acquisition order so concurrent checkouts of overlapping selections cannot
     * deadlock (architecture-spec §19). Scoping to {@code cartId} makes this the ownership check as
     * well: a line of another cart is simply not returned. This is <strong>concurrency control, not
     * a business rule</strong> — it changes nothing about what the cart or checkout means.
     *
     * @param ids    the requested cart item ids
     * @param cartId the caller's cart id
     * @return the caller's cart lines among the ids, locked for update, in ascending id order
     */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT ci FROM CartItem ci WHERE ci.id IN :ids AND ci.cart.id = :cartId ORDER BY ci.id")
    List<CartItem> findByIdInAndCartIdForUpdate(@Param("ids") Collection<Long> ids, @Param("cartId") Long cartId);

    /**
     * Returns the given cart's lines among the supplied ids, scoped to {@code cartId} as the
     * ownership check, <strong>without</strong> a lock. This is the read-only counterpart of
     * {@link #findByIdInAndCartIdForUpdate}: the checkout preview prices the lines but consumes
     * nothing, so it needs no lock and must not contend with live checkouts (sprint-4-plan item 08).
     *
     * @param ids    the requested cart item ids
     * @param cartId the caller's cart id
     * @return the caller's cart lines among the ids (empty when none match)
     */
    List<CartItem> findByIdInAndCartId(Collection<Long> ids, Long cartId);

    /**
     * Deletes the given cart's lines among the supplied ids, scoped to {@code cartId} so only the
     * caller's own lines are removed and never a line of another cart. The {@code cart} row itself is
     * untouched (business-rules → Checkout / Shopping Cart).
     *
     * @param ids    the cart item ids to delete
     * @param cartId the caller's cart id
     */
    void deleteByIdInAndCartId(Collection<Long> ids, Long cartId);
}
