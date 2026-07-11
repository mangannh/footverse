package com.footverse.order.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

import com.footverse.order.entity.OrderItem;

/**
 * Data access for {@link OrderItem}. Standard CRUD is inherited from {@link JpaRepository}; the
 * order-scoped read below lets {@code OrderService} assemble an order's detail and item count.
 */
public interface OrderItemRepository extends JpaRepository<OrderItem, Long> {

    /**
     * Returns every line of an order.
     *
     * @param orderId the owning order id
     * @return the order's lines (empty when the order has none)
     */
    List<OrderItem> findByOrderId(Long orderId);
}
