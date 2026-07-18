import { describe, expect, it } from 'vitest';

import { couponValidators } from './coupon-validators';

describe('couponValidators.code', () => {
  it('accepts a non-blank code within the length limit', () => {
    expect(couponValidators.code('SUMMER10')).toBeUndefined();
  });

  it('rejects a blank code', () => {
    expect(couponValidators.code('')).toBe('Code is required');
  });

  it('accepts a value at the 64-character limit', () => {
    expect(couponValidators.code('a'.repeat(64))).toBeUndefined();
  });

  it('rejects a value over the 64-character limit', () => {
    expect(couponValidators.code('a'.repeat(65))).toBe('Code must be at most 64 characters');
  });
});

describe('couponValidators.name', () => {
  it('accepts a non-blank name', () => {
    expect(couponValidators.name('Summer Sale')).toBeUndefined();
  });

  it('rejects a blank name', () => {
    expect(couponValidators.name('   ')).toBe('Name is required');
  });
});

describe('couponValidators.description', () => {
  it('accepts an empty value (optional field)', () => {
    expect(couponValidators.description('')).toBeUndefined();
  });

  it('accepts a value at the 2000-character limit', () => {
    expect(couponValidators.description('a'.repeat(2000))).toBeUndefined();
  });

  it('rejects a value over the 2000-character limit', () => {
    expect(couponValidators.description('a'.repeat(2001))).toBe(
      'Description must be at most 2000 characters',
    );
  });
});

describe('couponValidators.discountValue', () => {
  it('accepts a positive value', () => {
    expect(couponValidators.discountValue('10')).toBeUndefined();
  });

  it('rejects a blank value', () => {
    expect(couponValidators.discountValue('')).toBe('Discount value is required');
  });

  it('rejects zero', () => {
    expect(couponValidators.discountValue('0')).toBe('Discount value must be greater than 0');
  });

  it('rejects a negative value', () => {
    expect(couponValidators.discountValue('-1')).toBe('Discount value must be greater than 0');
  });
});

describe('couponValidators.minOrderAmount', () => {
  it('accepts zero', () => {
    expect(couponValidators.minOrderAmount('0')).toBeUndefined();
  });

  it('accepts a positive value', () => {
    expect(couponValidators.minOrderAmount('50')).toBeUndefined();
  });

  it('rejects a blank value', () => {
    expect(couponValidators.minOrderAmount('')).toBe('Minimum order amount is required');
  });

  it('rejects a negative value', () => {
    expect(couponValidators.minOrderAmount('-1')).toBe('Minimum order amount must be zero or more');
  });
});

describe('couponValidators.maxDiscountAmount', () => {
  it('accepts an empty value (optional field)', () => {
    expect(couponValidators.maxDiscountAmount('')).toBeUndefined();
  });

  it('accepts a positive value', () => {
    expect(couponValidators.maxDiscountAmount('20')).toBeUndefined();
  });

  it('rejects zero', () => {
    expect(couponValidators.maxDiscountAmount('0')).toBe(
      'Maximum discount amount must be greater than 0',
    );
  });

  it('rejects a negative value', () => {
    expect(couponValidators.maxDiscountAmount('-1')).toBe(
      'Maximum discount amount must be greater than 0',
    );
  });

  it('does not treat the literal string "null" as empty (regression guard for the toValues bug)', () => {
    // toValues() must never seed this field with the string "null" — this
    // guards the validator's own behavior in case it ever did: "null" is
    // non-numeric, so it must be rejected, not silently accepted as blank.
    expect(couponValidators.maxDiscountAmount('null')).toBe(
      'Maximum discount amount must be greater than 0',
    );
  });
});

describe('couponValidators.startAt', () => {
  it('accepts a non-blank value', () => {
    expect(couponValidators.startAt('2026-01-01T00:00')).toBeUndefined();
  });

  it('rejects a blank value', () => {
    expect(couponValidators.startAt('')).toBe('Start date is required');
  });
});

describe('couponValidators.endAt', () => {
  it('accepts a non-blank value', () => {
    expect(couponValidators.endAt('2026-02-01T00:00')).toBeUndefined();
  });

  it('rejects a blank value', () => {
    expect(couponValidators.endAt('')).toBe('End date is required');
  });

  it('does not compare endAt against startAt (server-authoritative)', () => {
    // An end date before the start date is still accepted client-side — the
    // endAt > startAt window is a business rule enforced only by the server
    // (COUPON_INVALID_DATE_RANGE), never re-implemented here.
    expect(couponValidators.endAt('2020-01-01T00:00')).toBeUndefined();
  });
});

describe('couponValidators.usageLimit', () => {
  it('accepts an empty value (optional field)', () => {
    expect(couponValidators.usageLimit('')).toBeUndefined();
  });

  it('accepts a positive integer', () => {
    expect(couponValidators.usageLimit('100')).toBeUndefined();
  });

  it('rejects zero', () => {
    expect(couponValidators.usageLimit('0')).toBe('Usage limit must be greater than 0');
  });

  it('rejects a negative value', () => {
    expect(couponValidators.usageLimit('-1')).toBe('Usage limit must be greater than 0');
  });
});
