package com.footverse.order.repository;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
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
 * detail reads, and {@code count()} for the dashboard's {@code totalOrders}) is inherited from
 * {@link JpaRepository}; the reads below serve {@code OrderService} for the caller-scoped queries,
 * the ADMIN management search, and the ADMIN dashboard aggregates (Sprint 13, Task 01). Order-code
 * uniqueness is enforced by the {@code uk_orders_order_code} unique constraint on insert (a bounded
 * retry on the resulting {@link org.springframework.dao.DataIntegrityViolationException}), never by a
 * pre-read.
 *
 * <p>Every dashboard aggregate below is computed in SQL, never by loading orders into memory
 * (Task 01 Design Notes): each is a single {@code GROUP BY} or scalar aggregate query, and each is
 * scoped to {@code DELIVERED} orders except {@link #countOrdersGroupedByStatus()}, which covers every
 * status by design. Two of the five — {@link #findDeliveredOrderItemProfitSummary()} and
 * {@link #findTopSellingDeliveredVariants(Pageable)} — read from {@code OrderItem} rather than
 * {@code Order}; JPQL is not limited to the repository's own entity type, and grouping them here
 * (rather than on {@code OrderItemRepository}) keeps every dashboard aggregate in one place.</p>
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

    /**
     * Returns the sum of {@code total} over every {@code DELIVERED} order — the dashboard's
     * {@code totalRevenue} (dto-spec §15, Sprint 13). {@code COALESCE} floors an empty result at
     * zero rather than {@code null}, so an empty store never surfaces a {@code null} figure.
     *
     * @return the delivered-order revenue total, zero when there are none
     */
    @Query("SELECT COALESCE(SUM(o.total), 0) FROM Order o WHERE o.status = com.footverse.order.entity.OrderStatus.DELIVERED")
    BigDecimal sumTotalForDeliveredOrders();

    /**
     * Returns the order count grouped by status, across <strong>every</strong> status — unlike every
     * other dashboard aggregate here, this one is deliberately not scoped to {@code DELIVERED} (the
     * dashboard's {@code ordersByStatus}, dto-spec §15). A status with no orders is simply absent from
     * the result; the service zero-fills it to a full five-row set (Task 01 Design Notes).
     *
     * @return one row per status that has at least one order
     */
    @Query("SELECT o.status AS status, COUNT(o) AS count FROM Order o GROUP BY o.status")
    List<StatusCountProjection> countOrdersGroupedByStatus();

    /**
     * Returns the dashboard's gross-profit summary over every {@code DELIVERED} order item (dto-spec
     * §15, Sprint 13): the profit sum restricted to lines with a known cost, and the two coverage
     * counts. A line whose {@code unitCostPrice} is {@code null} contributes {@code 0} to the profit
     * sum and is excluded from {@code linesWithCost} — <strong>never</strong> treated as a zero-cost,
     * all-profit line (Design Decision 2) — but is still counted in {@code linesTotal}, so the
     * response can state exactly how much of the period the profit figure covers. With no matching
     * rows the aggregate still returns one row, its {@code SUM} floored to zero by {@code COALESCE}
     * and both counts naturally zero.
     *
     * @return the single summary row (never absent, even for an empty store)
     */
    @Query("""
            SELECT
                COALESCE(SUM(CASE WHEN oi.unitCostPrice IS NOT NULL
                    THEN (oi.unitPrice - oi.unitCostPrice) * oi.quantity ELSE 0 END), 0) AS grossProfit,
                SUM(CASE WHEN oi.unitCostPrice IS NOT NULL THEN 1L ELSE 0L END) AS linesWithCost,
                COUNT(oi) AS linesTotal
            FROM OrderItem oi
            WHERE oi.order.status = com.footverse.order.entity.OrderStatus.DELIVERED
            """)
    ProfitSummaryProjection findDeliveredOrderItemProfitSummary();

    /**
     * Returns delivered revenue and order count grouped by calendar year/month, for every month with
     * at least one {@code DELIVERED} order placed at or after {@code since} — the dashboard's
     * {@code monthlyRevenue} series (dto-spec §15, Sprint 13). A month with no orders is simply absent
     * from the result; the service zero-fills it to a full twelve-row trailing window
     * (Task 01 Design Notes).
     *
     * @param since the inclusive start of the trailing window (the first instant of its oldest month)
     * @return one row per year/month that has at least one {@code DELIVERED} order in the window
     */
    @Query("""
            SELECT FUNCTION('YEAR', o.createdAt) AS year, FUNCTION('MONTH', o.createdAt) AS month,
                   COALESCE(SUM(o.total), 0) AS revenue, COUNT(o) AS orderCount
            FROM Order o
            WHERE o.status = com.footverse.order.entity.OrderStatus.DELIVERED
              AND o.createdAt >= :since
            GROUP BY FUNCTION('YEAR', o.createdAt), FUNCTION('MONTH', o.createdAt)
            """)
    List<MonthlyRevenueProjection> findMonthlyDeliveredRevenueSince(@Param("since") LocalDateTime since);

    /**
     * Returns units sold and revenue per {@code productVariantId}, over {@code DELIVERED} order items
     * only, ordered by quantity sold descending and capped by {@code pageable} — the dashboard's raw
     * material for {@code bestSellingProducts} (dto-spec §15, Sprint 13). This aggregates by variant,
     * <strong>not</strong> by product (an order item stores only {@code productVariantId}, database-spec
     * §12); the service folds variant rows to their owning product through
     * {@code ProductVariantService} (Design Decision 10) after over-fetching more variants than the
     * final top-5 so the fold's own ranking stays correct.
     *
     * @param pageable the page request supplying the row limit (only its size is used — this is a
     *                 {@code List}, not a {@code Page}, so no separate count query runs)
     * @return the top variants by quantity sold, most first
     */
    @Query("""
            SELECT oi.productVariantId AS productVariantId,
                   SUM(oi.quantity) AS quantitySold,
                   COALESCE(SUM(oi.lineTotal), 0) AS revenue
            FROM OrderItem oi
            WHERE oi.order.status = com.footverse.order.entity.OrderStatus.DELIVERED
            GROUP BY oi.productVariantId
            ORDER BY SUM(oi.quantity) DESC
            """)
    List<VariantSalesProjection> findTopSellingDeliveredVariants(Pageable pageable);

    /**
     * Interface projection for {@link #countOrdersGroupedByStatus()}.
     */
    interface StatusCountProjection {

        /** @return the status this row counts */
        OrderStatus getStatus();

        /** @return the number of orders at this status */
        long getCount();
    }

    /**
     * Interface projection for {@link #findDeliveredOrderItemProfitSummary()}.
     */
    interface ProfitSummaryProjection {

        /** @return the gross profit summed over lines with a known cost, zero when there are none */
        BigDecimal getGrossProfit();

        /** @return the number of lines included in {@link #getGrossProfit()} */
        long getLinesWithCost();

        /** @return the total number of delivered lines, with or without a known cost */
        long getLinesTotal();
    }

    /**
     * Interface projection for {@link #findMonthlyDeliveredRevenueSince(LocalDateTime)}.
     */
    interface MonthlyRevenueProjection {

        /** @return the calendar year */
        int getYear();

        /** @return the calendar month, 1–12 */
        int getMonth();

        /** @return the delivered-order revenue for this month */
        BigDecimal getRevenue();

        /** @return the number of delivered orders placed in this month */
        long getOrderCount();
    }

    /**
     * Interface projection for {@link #findTopSellingDeliveredVariants(Pageable)}.
     */
    interface VariantSalesProjection {

        /** @return the variant id */
        Long getProductVariantId();

        /** @return the sum of order-item quantities for this variant, delivered orders only */
        long getQuantitySold();

        /** @return the sum of order-item line totals for this variant, delivered orders only */
        BigDecimal getRevenue();
    }
}
