import type { OrderStatus } from '../models/order-status';

/**
 * The frozen order status machine (business-rules → Order Status
 * Transitions): `PENDING→CONFIRMED→SHIPPING→DELIVERED` and
 * `PENDING→CANCELLED`. No other transition exists; the two terminal
 * statuses (`DELIVERED`, `CANCELLED`) allow none.
 */
const ALLOWED_TRANSITIONS: Readonly<Record<OrderStatus, readonly OrderStatus[]>> = {
  PENDING: ['CONFIRMED', 'CANCELLED'],
  CONFIRMED: ['SHIPPING'],
  SHIPPING: ['DELIVERED'],
  DELIVERED: [],
  CANCELLED: [],
};

/**
 * Returns the legal next statuses for the given current status — a
 * **presentation** decision only (which buttons to draw); the server alone
 * decides whether a transition is actually allowed
 * (`PATCH /orders/{id}/status`, sprint-12-plan Design Decision 6). This
 * function re-implements no business rule and mutates nothing.
 *
 * @param status the order's current status
 * @return the statuses that may be offered as the next transition, in a
 *         fixed forward order; empty for `DELIVERED` and `CANCELLED`
 */
export function getAllowedTransitions(status: OrderStatus): readonly OrderStatus[] {
  return ALLOWED_TRANSITIONS[status];
}

/**
 * Reports whether the given target status is the sprint's one destructive
 * transition — `true` only for `CANCELLED`. Used to gate the shared
 * `ConfirmDialog` on cancellation alone; the three forward transitions
 * (`CONFIRMED` / `SHIPPING` / `DELIVERED`) run immediately on click
 * (sprint-12-plan Task 05).
 *
 * @param target the requested target status
 * @return `true` when confirming the transition should be required first
 */
export function requiresConfirmation(target: OrderStatus): boolean {
  return target === 'CANCELLED';
}
