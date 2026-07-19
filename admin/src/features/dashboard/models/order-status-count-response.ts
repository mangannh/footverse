/**
 * Lifecycle status of an order (dto-spec §4). Mirrors the frozen enum values —
 * the same five values as the `order` feature's own `OrderStatus`, defined
 * again here rather than imported: `AdminOrderSummaryResponse` is the one
 * cross-feature import this feature makes (sprint-13-plan Task 02 Design
 * Note), and a five-value string-literal union frozen since Sprint 1 carries
 * no meaningful drift risk the way a multi-field interface would.
 */
export type OrderStatus = 'PENDING' | 'CONFIRMED' | 'SHIPPING' | 'DELIVERED' | 'CANCELLED';

/**
 * One row of the ADMIN dashboard's per-status order count (dto-spec §15,
 * Sprint 13). The dashboard always returns exactly one row per `OrderStatus`
 * value, zero-filled server-side for a status with no orders. Mirrors the
 * frozen DTO field-for-field.
 */
export interface OrderStatusCountResponse {
  readonly status: OrderStatus;
  readonly count: number;
}
