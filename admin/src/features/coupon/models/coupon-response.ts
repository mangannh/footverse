import type { DiscountType } from './discount-type';

/**
 * A coupon returned for admin management (dto-spec §14). Mirrors the frozen
 * DTO field-for-field.
 *
 * `maxDiscountAmount` and `usageLimit` are optional (`BigDecimal`/`Integer`)
 * on the backend record with no `@JsonInclude(NON_NULL)`, so Jackson's
 * default inclusion serializes an unset value as an explicit JSON `null`
 * rather than omitting the key — the response can carry `null`, not only
 * `undefined`.
 */
export interface CouponResponse {
  readonly id: number;
  readonly code: string;
  readonly name: string;
  readonly description?: string;
  readonly discountType: DiscountType;
  readonly discountValue: number;
  readonly minOrderAmount: number;
  readonly maxDiscountAmount?: number | null;
  readonly startAt: string;
  readonly endAt: string;
  readonly usageLimit?: number | null;
  readonly usedCount: number;
  readonly enabled: boolean;
}
