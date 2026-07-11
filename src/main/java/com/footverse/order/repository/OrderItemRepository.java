package com.footverse.order.repository;

import java.util.Collection;
import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

import com.footverse.order.entity.OrderItem;

/**
 * Data access for {@link OrderItem}. Standard CRUD is inherited from {@link JpaRepository}; the
 * order-scoped reads below let {@code OrderService} assemble an order's detail and item counts.
 */
public interface OrderItemRepository extends JpaRepository<OrderItem, Long> {

    /**
     * Returns every line of an order.
     *
     * @param orderId the owning order id
     * @return the order's lines (empty when the order has none)
     */
    List<OrderItem> findByOrderId(Long orderId);

    /**
     * Returns every line of the given orders in a single query, so the service can compute each
     * order's {@code itemCount} (Σ quantity) for an order-history page without a per-order N+1 —
     * mirroring the batch {@code findByProductIdIn} precedent used by catalog search.
     *
     * @param orderIds the owning order ids
     * @return the lines of those orders (empty when none have any)
     */
    List<OrderItem> findByOrderIdIn(Collection<Long> orderIds);
}
