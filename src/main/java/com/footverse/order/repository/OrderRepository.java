package com.footverse.order.repository;

import java.util.Optional;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.footverse.order.entity.Order;
import com.footverse.order.entity.OrderStatus;

/**
 * Data access for {@link Order}. Standard CRUD (including {@code findById} for the admin status /
 * detail reads) is inherited from {@link JpaRepository}; the reads below serve {@code OrderService}
 * for the caller-scoped queries and the ADMIN management search. Order-code uniqueness is enforced by
 * the {@code uk_orders_order_code} unique constraint on insert (a bounded retry on the resulting
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

    /**
     * Returns a page of orders for ADMIN management, optionally filtered by {@code status} and/or
     * searched by an {@code orderCode} fragment (contains match) — a single query serving all four
     * combinations (neither / status only / code only / both, sprint-12-plan Task 01) rather than four
     * overloads. A {@code null} argument means "no filter" for that criterion; the caller
     * ({@code OrderService}) normalises a blank {@code orderCode} to {@code null} before calling, so
     * this method never has to.
     *
     * @param status    the status to filter by, or {@code null} for every status
     * @param orderCode the order-code fragment to search for (contains match), or {@code null} for no
     *                  search
     * @param pageable  the pagination and sort request
     * @return the page of matching orders
     */
    @Query("""
            SELECT o FROM Order o
            WHERE (:status IS NULL OR o.status = :status)
              AND (:orderCode IS NULL OR o.orderCode LIKE %:orderCode%)
            """)
    Page<Order> searchForAdmin(@Param("status") OrderStatus status, @Param("orderCode") String orderCode,
            Pageable pageable);
}
