import { describe, expect, it } from 'vitest';

import { toValues } from './coupon-form-values';
import type { CouponResponse } from '../models/coupon-response';

const baseCoupon: CouponResponse = {
  id: 1,
  code: 'SUMMER10',
  name: 'Summer Sale',
  discountType: 'PERCENT',
  discountValue: 10,
  minOrderAmount: 50,
  startAt: '2026-01-01T00:00:00',
  endAt: '2026-02-01T00:00:00',
  usedCount: 0,
  enabled: true,
};

// Bug fix: `maxDiscountAmount` / `usageLimit` are optional fields the server
// serializes as an explicit JSON `null` when unset (no `@JsonInclude`), not
// an omitted key — so the response can carry `null`, not only `undefined`.
// `toValues` must treat both as "no value" and never seed the form with the
// literal string "null" (which then failed re-validation on an untouched
// save — the reported bug).
describe('toValues — maxDiscountAmount / usageLimit optional-field handling', () => {
  it('create mode (no coupon) seeds an empty maxDiscountAmount and usageLimit', () => {
    const values = toValues(null);

    expect(values.maxDiscountAmount).toBe('');
    expect(values.usageLimit).toBe('');
  });

  it('edit mode with maxDiscountAmount/usageLimit explicitly null seeds an empty string, never "null"', () => {
    const coupon: CouponResponse = { ...baseCoupon, maxDiscountAmount: null, usageLimit: null };

    const values = toValues(coupon);

    expect(values.maxDiscountAmount).toBe('');
    expect(values.usageLimit).toBe('');
  });

  it('edit mode with maxDiscountAmount/usageLimit undefined (key absent) seeds an empty string', () => {
    const coupon: CouponResponse = { ...baseCoupon };

    const values = toValues(coupon);

    expect(values.maxDiscountAmount).toBe('');
    expect(values.usageLimit).toBe('');
  });

  it('edit mode with a set maxDiscountAmount/usageLimit seeds the stringified value', () => {
    const coupon: CouponResponse = { ...baseCoupon, maxDiscountAmount: 20, usageLimit: 100 };

    const values = toValues(coupon);

    expect(values.maxDiscountAmount).toBe('20');
    expect(values.usageLimit).toBe('100');
  });

  it('edit mode with maxDiscountAmount/usageLimit at 0 still seeds "0" (a real, if invalid, value — never coerced to empty)', () => {
    const coupon: CouponResponse = { ...baseCoupon, maxDiscountAmount: 0, usageLimit: 0 };

    const values = toValues(coupon);

    expect(values.maxDiscountAmount).toBe('0');
    expect(values.usageLimit).toBe('0');
  });
});
