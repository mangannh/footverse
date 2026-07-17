import type { CreateCategoryRequest } from './create-category-request';

/**
 * Fully update a category (dto-spec §10). Field-for-field identical to
 * [CreateCategoryRequest] in the frozen DTO; aliased rather than duplicated.
 */
export type UpdateCategoryRequest = CreateCategoryRequest;
