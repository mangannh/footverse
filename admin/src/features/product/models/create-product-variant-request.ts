import type { ProductVariantStatus } from './product-variant-status';

/**
 * Create a product variant (dto-spec §9). Mirrors the frozen DTO
 * field-for-field, including the ADMIN-only `costPrice` (Sprint 11).
 */
export interface CreateProductVariantRequest {
  readonly color: string;
  readonly size: string;
  readonly stockQuantity: number;
  readonly sku: string;
  readonly priceOverride?: number;
  readonly status: ProductVariantStatus;
  readonly costPrice: number;
}
