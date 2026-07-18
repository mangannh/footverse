import type { CreateProductImageRequest } from './create-product-image-request';

/**
 * Update a product image (dto-spec §9). Field-for-field identical to
 * [CreateProductImageRequest] in the frozen DTO; aliased rather than
 * duplicated.
 */
export type UpdateProductImageRequest = CreateProductImageRequest;
