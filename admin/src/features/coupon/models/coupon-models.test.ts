import { describe, expect, it } from 'vitest';

import type { CouponResponse } from './coupon-response';
import type { CreateCouponRequest } from './create-coupon-request';
import type { UpdateCouponRequest } from './update-coupon-request';

// Captured backend payloads (dto-spec §14). Request types omit optional
// fields from the serialized JSON when unset (react-guidelines §Models);
// `CouponResponse` deserializes a captured payload field-for-field —
// including the explicit JSON `null` Jackson sends for an unset
// `maxDiscountAmount` / `usageLimit` (no `@JsonInclude(NON_NULL)` on the
// backend record), not only an omitted key.
describe('CreateCouponRequest', () => {
  it('omits description, maxDiscountAmount, and usageLimit from the JSON when unset', () => {
    const request: CreateCouponRequest = {
      code: 'SUMMER10',
      name: 'Summer Sale',
      discountType: 'PERCENT',
      discountValue: 10,
      minOrderAmount: 50,
      startAt: '2026-01-01T00:00:00',
      endAt: '2026-02-01T00:00:00',
      enabled: true,
    };

    const json = JSON.parse(JSON.stringify(request)) as Record<string, unknown>;

    expect(json).toEqual({
      code: 'SUMMER10',
      name: 'Summer Sale',
      discountType: 'PERCENT',
      discountValue: 10,
      minOrderAmount: 50,
      startAt: '2026-01-01T00:00:00',
      endAt: '2026-02-01T00:00:00',
      enabled: true,
    });
    expect('description' in json).toBe(false);
    expect('maxDiscountAmount' in json).toBe(false);
    expect('usageLimit' in json).toBe(false);
  });

  it('serializes every field when all are set', () => {
    const request: CreateCouponRequest = {
      code: 'SUMMER10',
      name: 'Summer Sale',
      description: '10% off',
      discountType: 'PERCENT',
      discountValue: 10,
      minOrderAmount: 50,
      maxDiscountAmount: 20,
      startAt: '2026-01-01T00:00:00',
      endAt: '2026-02-01T00:00:00',
      usageLimit: 100,
      enabled: true,
    };

    expect(JSON.parse(JSON.stringify(request))).toEqual(request);
  });
});

describe('UpdateCouponRequest', () => {
  it('is field-for-field identical to CreateCouponRequest', () => {
    const request: UpdateCouponRequest = {
      code: 'SUMMER10',
      name: 'Summer Sale',
      discountType: 'PERCENT',
      discountValue: 10,
      minOrderAmount: 50,
      startAt: '2026-01-01T00:00:00',
      endAt: '2026-02-01T00:00:00',
      enabled: true,
    };

    expect(JSON.parse(JSON.stringify(request))).toEqual(request);
  });
});

describe('CouponResponse', () => {
  it('deserializes a captured payload field-for-field, carrying usedCount', () => {
    const payload = {
      id: 1,
      code: 'SUMMER10',
      name: 'Summer Sale',
      description: '10% off',
      discountType: 'PERCENT',
      discountValue: 10,
      minOrderAmount: 50,
      maxDiscountAmount: 20,
      startAt: '2026-01-01T00:00:00',
      endAt: '2026-02-01T00:00:00',
      usageLimit: 100,
      usedCount: 3,
      enabled: true,
    };

    const coupon: CouponResponse = JSON.parse(JSON.stringify(payload));

    expect(coupon).toEqual(payload);
  });

  it('deserializes a payload with the optional fields omitted (key absent)', () => {
    const payload = {
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

    const coupon: CouponResponse = JSON.parse(JSON.stringify(payload));

    expect(coupon.description).toBeUndefined();
    expect(coupon.maxDiscountAmount).toBeUndefined();
    expect(coupon.usageLimit).toBeUndefined();
  });

  it('deserializes a payload where maxDiscountAmount/usageLimit are explicit JSON null', () => {
    const payload = {
      id: 1,
      code: 'SUMMER10',
      name: 'Summer Sale',
      discountType: 'PERCENT',
      discountValue: 10,
      minOrderAmount: 50,
      maxDiscountAmount: null,
      startAt: '2026-01-01T00:00:00',
      endAt: '2026-02-01T00:00:00',
      usageLimit: null,
      usedCount: 0,
      enabled: true,
    };

    const coupon: CouponResponse = JSON.parse(JSON.stringify(payload));

    expect(coupon.maxDiscountAmount).toBeNull();
    expect(coupon.usageLimit).toBeNull();
  });
});
