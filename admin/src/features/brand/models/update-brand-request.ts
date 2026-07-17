import type { CreateBrandRequest } from './create-brand-request';

/**
 * Fully update a brand (dto-spec §11). Field-for-field identical to
 * [CreateBrandRequest] in the frozen DTO; aliased rather than duplicated.
 */
export type UpdateBrandRequest = CreateBrandRequest;
