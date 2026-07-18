import type { OrderItemResponse } from './order-item-response';
import type { OrderStatus } from './order-status';
import type { PaymentMethod } from './payment-method';
import type { PaymentStatus } from './payment-status';

/**
 * Full order detail for ADMIN (dto-spec §15, `GET /admin/orders/{id}`).
 * Mirrors the customer `OrderDetailResponse` field-for-field — including the
 * shipping snapshot, which **is** the delivery address (no separate
 * `customerAddress` field exists) — plus the owning customer's account
 * identity, which the customer-scoped DTO deliberately omits. `items` reuses
 * the unchanged `OrderItemResponse`. Mirrors the frozen DTO field-for-field.
 *
 * `couponCode`, `note`, `cancelledAt`, and `deliveredAt` are optional on the
 * backend record with no `@JsonInclude(NON_NULL)`, so Jackson's default
 * inclusion serializes an unset value as an explicit JSON `null` rather than
 * omitting the key — the response can carry `null`, not only `undefined`
 * (the Sprint 11 `CouponResponse` precedent).
 */
export interface AdminOrderDetailResponse {
  readonly id: number;
  readonly orderCode: string;
  readonly status: OrderStatus;
  readonly paymentMethod: PaymentMethod;
  readonly paymentStatus: PaymentStatus;
  readonly subtotal: number;
  readonly discountAmount: number;
  readonly shippingFee: number;
  readonly total: number;
  readonly couponCode?: string | null;
  readonly shippingRecipientName: string;
  readonly shippingRecipientPhone: string;
  readonly shippingProvince: string;
  readonly shippingDistrict: string;
  readonly shippingWard: string;
  readonly shippingStreetAddress: string;
  readonly note?: string | null;
  readonly items: readonly OrderItemResponse[];
  readonly createdAt: string;
  readonly cancelledAt?: string | null;
  readonly deliveredAt?: string | null;
  readonly customerId: number;
  readonly customerFullName: string;
  readonly customerEmail: string;
  readonly customerPhone: string;
}
