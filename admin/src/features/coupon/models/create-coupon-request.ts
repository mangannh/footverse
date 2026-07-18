import type { DiscountType } from './discount-type';

/** Create a coupon (dto-spec §14). Mirrors the frozen DTO field-for-field. */
export interface CreateCouponRequest {
  readonly code: string;
  readonly name: string;
  readonly description?: string;
  readonly discountType: DiscountType;
  readonly discountValue: number;
  readonly minOrderAmount: number;
  readonly maxDiscountAmount?: number;
  readonly startAt: string;
  readonly endAt: string;
  readonly usageLimit?: number;
  readonly enabled: boolean;
}
