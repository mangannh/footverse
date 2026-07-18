import type { CreateCouponRequest } from './create-coupon-request';

/**
 * Fully update a coupon (dto-spec §14). Field-for-field identical to
 * [CreateCouponRequest] in the frozen DTO; aliased rather than duplicated.
 */
export type UpdateCouponRequest = CreateCouponRequest;
