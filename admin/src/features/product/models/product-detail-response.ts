import type { ProductImageResponse } from './product-image-response';
import type { ProductVariantResponse } from './product-variant-response';

/**
 * Full product detail returned by `POST/PUT /products(/{id})` (dto-spec §9) —
 * the public shape, without the ADMIN-only `costPrice` (see
 * `AdminProductDetailResponse`). Mirrors the frozen DTO field-for-field.
 */
export interface ProductDetailResponse {
  readonly id: number;
  readonly name: string;
  readonly description?: string;
  readonly basePrice: number;
  readonly brandId: number;
  readonly brandName: string;
  readonly categoryId: number;
  readonly categoryName: string;
  readonly images: readonly ProductImageResponse[];
  readonly variants: readonly ProductVariantResponse[];
  readonly averageRating: number;
  readonly reviewCount: number;
  readonly available: boolean;
  readonly createdAt: string;
}
