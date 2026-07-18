import type { ProductVariantStatus } from './product-variant-status';

/**
 * A product variant returned to ADMIN (dto-spec §9), carrying the ADMIN-only
 * `costPrice` and the raw `priceOverride`. Never returned by a public/customer
 * endpoint. Mirrors the frozen DTO field-for-field.
 *
 * `priceOverride` is the raw value (`undefined`/`null` when the variant
 * follows the product's `basePrice`) — distinct from `price`, the resolved
 * effective value — so the ADMIN client can prefill an edit form without
 * inferring the override from a price comparison (react-guidelines §Server
 * Authoritative: the client never synthesizes server state it was not given).
 */
export interface AdminProductVariantResponse {
  readonly id: number;
  readonly color: string;
  readonly size: string;
  readonly price: number;
  readonly priceOverride?: number | null;
  readonly costPrice: number;
  readonly stockQuantity: number;
  readonly status: ProductVariantStatus;
  readonly sku: string;
}
