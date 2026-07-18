import type { ProductVariantStatus } from './product-variant-status';

/**
 * A product variant returned by the public/write endpoints (dto-spec §9) —
 * `costPrice` is ADMIN-only and is omitted here (see
 * `AdminProductVariantResponse`). Mirrors the frozen DTO field-for-field.
 * Returned by `POST/PUT /products/{id}/variants`.
 */
export interface ProductVariantResponse {
  readonly id: number;
  readonly color: string;
  readonly size: string;
  readonly price: number;
  readonly stockQuantity: number;
  readonly status: ProductVariantStatus;
  readonly sku: string;
}
