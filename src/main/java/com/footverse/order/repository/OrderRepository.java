package com.footverse.order.repository;

import java.util.Optional;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import com.footverse.order.entity.Order;

/**
 * Data access for {@link Order}. Standard CRUD (including {@code findById} for the admin status /
 * detail reads) is inherited from {@link JpaRepository}; the reads below serve {@code OrderService}
 * for the caller-scoped queries. Order-code uniqueness is enforced by the {@code uk_orders_order_code}
 * unique constraint on insert (a bounded retry on the resulting
 * {@link org.springframework.dao.DataIntegrityViolationException}), never by a pre-read.
 */
public interface OrderRepository extends JpaRepository<Order, Long> {

    /**
     * Returns a page of a user's orders, for the caller's order history.
     *
     * @param userId   the owning user id
     * @param pageable the pagination and sort request
     * @return the page of the user's orders
     */
    Page<Order> findByUserId(Long userId, Pageable pageable);

    /**
     * Returns an order only when it belongs to the given user, so the service can resolve and
     * ownership-check in one read.
     *
     * @param id     the order id
     * @param userId the owning user id
     * @return the order, or empty when it does not exist or belongs to another user
     */
    Optional<Order> findByIdAndUserId(Long id, Long userId);
}
