import type { CreateProductVariantRequest } from './create-product-variant-request';

/**
 * Update a product variant (dto-spec §9). Field-for-field identical to
 * [CreateProductVariantRequest] in the frozen DTO; aliased rather than
 * duplicated.
 */
export type UpdateProductVariantRequest = CreateProductVariantRequest;
