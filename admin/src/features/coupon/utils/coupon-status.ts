import type { CouponResponse } from '../models/coupon-response';

/**
 * The business-meaningful coupon status the admin table displays, derived
 * from `enabled` + the `startAt`/`endAt` window — never rendered as the raw
 * `enabled` boolean. Purely a display concept: the backend alone still
 * decides whether a coupon can actually be applied at checkout.
 */
export type CouponStatus = 'Disabled' | 'Scheduled' | 'Valid' | 'Expired';

/**
 * `startAt`/`endAt` are server `LocalDateTime` strings with no zone info
 * (e.g. `"2026-01-01T00:00:00"`). `new Date(...)` parses that ISO date-time
 * form as local time per the JS spec, matching `now`'s local time — so no
 * timezone is hardcoded on either side of the comparison.
 */
export function getCouponStatus(
  coupon: Pick<CouponResponse, 'enabled' | 'startAt' | 'endAt'>,
  now: Date = new Date(),
): CouponStatus {
  if (!coupon.enabled) {
    return 'Disabled';
  }

  const startAt = new Date(coupon.startAt);
  const endAt = new Date(coupon.endAt);
  const nowMs = now.getTime();

  if (nowMs < startAt.getTime()) {
    return 'Scheduled';
  }
  if (nowMs > endAt.getTime()) {
    return 'Expired';
  }
  return 'Valid';
}
