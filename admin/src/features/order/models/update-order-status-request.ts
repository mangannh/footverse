import type { OrderStatus } from './order-status';

/**
 * Admin request to advance an order's status (dto-spec §17,
 * `PATCH /orders/{id}/status`). Allowed transitions:
 * `PENDING→CONFIRMED→SHIPPING→DELIVERED` and `PENDING→CANCELLED`; the server
 * remains authoritative for the transition machine. Mirrors the frozen DTO
 * field-for-field.
 */
export interface UpdateOrderStatusRequest {
  readonly status: OrderStatus;
}
