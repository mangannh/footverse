import type { CouponFormValues } from '../components/coupon-form';
import type { CouponResponse } from '../models/coupon-response';

/** `"2026-01-01T00:00:00"` (server) → `"2026-01-01T00:00"` (`datetime-local` input). */
export function toDateTimeLocal(value: string): string {
  return value.slice(0, 16);
}

/** `"2026-01-01T00:00"` (`datetime-local` input) → `"2026-01-01T00:00:00"` (server). */
export function toServerDateTime(value: string): string {
  return `${value}:00`;
}

/**
 * Converts a `CouponResponse` (or `null` for create mode) into the form's
 * controlled string values. Extracted from `coupon-form-page.tsx` into its
 * own module (react-refresh/only-export-components) so this pure function
 * can be unit tested directly (`coupon-form-values.test.ts`) without that
 * being a component test.
 */
export function toValues(coupon: CouponResponse | null): CouponFormValues {
  return {
    code: coupon?.code ?? '',
    name: coupon?.name ?? '',
    description: coupon?.description ?? '',
    discountType: coupon?.discountType ?? 'PERCENT',
    discountValue: coupon !== null ? String(coupon.discountValue) : '',
    minOrderAmount: coupon !== null ? String(coupon.minOrderAmount) : '',
    // `maxDiscountAmount` is optional and the server sends an explicit JSON
    // `null` for "unset" (Jackson's default inclusion), not just an absent
    // key — checking only `!== undefined` let a `null` through to
    // `String(null)` = `"null"`, a value that then failed re-validation on
    // an untouched save. Both must be treated as "no value".
    maxDiscountAmount:
      coupon?.maxDiscountAmount !== undefined && coupon?.maxDiscountAmount !== null
        ? String(coupon.maxDiscountAmount)
        : '',
    startAt: coupon !== null ? toDateTimeLocal(coupon.startAt) : '',
    endAt: coupon !== null ? toDateTimeLocal(coupon.endAt) : '',
    // Same optional-with-explicit-null shape as `maxDiscountAmount` above.
    usageLimit:
      coupon?.usageLimit !== undefined && coupon?.usageLimit !== null
        ? String(coupon.usageLimit)
        : '',
    enabled: coupon?.enabled ?? true,
  };
}
