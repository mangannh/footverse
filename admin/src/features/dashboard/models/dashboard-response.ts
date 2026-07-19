import type { AdminOrderSummaryResponse } from '@/features/order/models/admin-order-summary-response';

import type { BestSellingProductResponse } from './best-selling-product-response';
import type { MonthlyRevenueResponse } from './monthly-revenue-response';
import type { OrderStatusCountResponse } from './order-status-count-response';

/**
 * The core operating figures for the ADMIN dashboard (dto-spec §15,
 * `GET /admin/dashboard`, Sprint 13). Assembled entirely from `orders` /
 * `order_item` aggregates on the server — no figure is computed or
 * recomputed on the client (react-guidelines §Server Authoritative). Mirrors
 * the frozen DTO field-for-field.
 *
 * `grossProfit` sums only `DELIVERED` order items whose unit cost is known;
 * `profitLinesWithCost` / `profitLinesTotal` report how much of the period it
 * covers — rendered as the server sent them, never re-derived here.
 *
 * `recentOrders` reuses the `order` feature's `AdminOrderSummaryResponse`
 * unchanged rather than a near-duplicate row type — the one cross-feature
 * import this feature makes (sprint-13-plan Task 02 Design Note), imported
 * for its **type only**; no repository, hook, or component of the `order`
 * feature is imported.
 */
export interface DashboardResponse {
  readonly totalRevenue: number;
  readonly totalOrders: number;
  readonly grossProfit: number;
  readonly profitLinesWithCost: number;
  readonly profitLinesTotal: number;
  readonly ordersByStatus: readonly OrderStatusCountResponse[];
  readonly monthlyRevenue: readonly MonthlyRevenueResponse[];
  readonly bestSellingProducts: readonly BestSellingProductResponse[];
  readonly recentOrders: readonly AdminOrderSummaryResponse[];
}
