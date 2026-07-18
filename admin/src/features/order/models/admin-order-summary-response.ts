import type { OrderStatus } from './order-status';
import type { PaymentStatus } from './payment-status';

/**
 * A compact order for the ADMIN order-management list (dto-spec §15,
 * `GET /admin/orders`). A dedicated ADMIN DTO — never the customer
 * `OrderSummaryResponse` — because it additionally carries the owning
 * customer's account identity, which the customer-scoped DTO deliberately
 * omits. Mirrors the frozen DTO field-for-field.
 */
export interface AdminOrderSummaryResponse {
  readonly id: number;
  readonly orderCode: string;
  readonly status: OrderStatus;
  readonly paymentStatus: PaymentStatus;
  readonly total: number;
  readonly itemCount: number;
  readonly createdAt: string;
  readonly customerId: number;
  readonly customerFullName: string;
  readonly customerEmail: string;
  readonly customerPhone: string;
}
