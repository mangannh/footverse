package com.footverse.order.dto;

import java.math.BigDecimal;
import java.util.List;

/**
 * The core operating figures for the ADMIN dashboard (dto-spec §15, {@code GET /admin/dashboard},
 * Sprint 13). Assembled entirely from {@code orders} / {@code order_item} aggregates — no statistic
 * is stored, every figure is computed on read (architecture-spec §20, no {@code StatisticsService});
 * the response is a single, internally consistent snapshot, never six independent reads (Design
 * Decision 1).
 *
 * <p>{@code grossProfit} sums only {@code DELIVERED} order items whose {@code unitCostPrice} is
 * known (non-null): a line whose cost predates Sprint 12's snapshot is <strong>excluded</strong>,
 * never coerced to zero (Design Decision 2, sprint-12-plan Design Decision 2) — coercing it would
 * report that unit as pure profit, the single most misleading number this dashboard could produce.
 * {@code profitLinesWithCost} / {@code profitLinesTotal} report how much of the period the figure
 * actually covers, so the coverage is never hidden. The figure is <em>gross</em> — computed
 * {@code Σ (unitPrice − unitCostPrice) × quantity} before order-level discount and shipping fee, since
 * business-rules defines no rule for apportioning an order's discount across its lines.</p>
 *
 * <p>{@code recentOrders} reuses {@link AdminOrderSummaryResponse} unchanged rather than a
 * near-duplicate row type (Design Decision 1) — the admin already has that contract, and each row
 * links straight into the Sprint 12 order detail.</p>
 *
 * @param totalRevenue         the sum of {@code total} over {@code DELIVERED} orders
 * @param totalOrders          the count of all orders, regardless of status
 * @param grossProfit          {@code Σ (unitPrice − unitCostPrice) × quantity} over {@code DELIVERED}
 *                             order items with a known cost, before order-level discount and shipping
 * @param profitLinesWithCost  the number of {@code DELIVERED} order items included in
 *                             {@code grossProfit} (non-null {@code unitCostPrice})
 * @param profitLinesTotal     the total number of {@code DELIVERED} order items, with or without a
 *                             known cost
 * @param ordersByStatus       exactly one row per {@code OrderStatus} value, zero-filled
 * @param monthlyRevenue       exactly twelve rows — the current month and the eleven before it,
 *                             oldest first, zero-filled
 * @param bestSellingProducts  up to five products, ordered by {@code quantitySold} descending
 * @param recentOrders         up to five most-recently-placed orders
 */
public record DashboardResponse(
        BigDecimal totalRevenue,
        long totalOrders,
        BigDecimal grossProfit,
        long profitLinesWithCost,
        long profitLinesTotal,
        List<OrderStatusCountResponse> ordersByStatus,
        List<MonthlyRevenueResponse> monthlyRevenue,
        List<BestSellingProductResponse> bestSellingProducts,
        List<AdminOrderSummaryResponse> recentOrders) {
}
