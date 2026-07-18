import type { AdminProductVariantResponse } from './admin-product-variant-response';
import type { ProductImageResponse } from './product-image-response';

/**
 * Full product detail for ADMIN (dto-spec §9, `GET /admin/products/{id}`).
 * Mirrors the frozen DTO field-for-field: `variants` carry the ADMIN-only
 * `costPrice`; `images` reuse the non-sensitive `ProductImageResponse`.
 */
export interface AdminProductDetailResponse {
  readonly id: number;
  readonly name: string;
  readonly description?: string;
  readonly basePrice: number;
  readonly brandId: number;
  readonly brandName: string;
  readonly categoryId: number;
  readonly categoryName: string;
  readonly images: readonly ProductImageResponse[];
  readonly variants: readonly AdminProductVariantResponse[];
  readonly averageRating: number;
  readonly reviewCount: number;
  readonly available: boolean;
  readonly createdAt: string;
}
