import type { CreateProductRequest } from './create-product-request';

/**
 * Fully update a product (dto-spec §9). Field-for-field identical to
 * [CreateProductRequest] in the frozen DTO; aliased rather than duplicated.
 */
export type UpdateProductRequest = CreateProductRequest;
