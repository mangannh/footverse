import { describe, expect, it } from 'vitest';

import { getCouponStatus } from './coupon-status';
import type { CouponResponse } from '../models/coupon-response';

const startAt = '2026-01-10T00:00:00';
const endAt = '2026-01-20T00:00:00';

const window: Pick<CouponResponse, 'enabled' | 'startAt' | 'endAt'> = {
  enabled: true,
  startAt,
  endAt,
};

describe('getCouponStatus', () => {
  it('returns Disabled when enabled is false, regardless of the start/end window', () => {
    expect(getCouponStatus({ ...window, enabled: false }, new Date('2026-01-15T00:00:00'))).toBe(
      'Disabled',
    );
  });

  it('returns Scheduled when now is before startAt', () => {
    expect(getCouponStatus(window, new Date('2026-01-01T00:00:00'))).toBe('Scheduled');
  });

  it('returns Valid when now is within the start/end window', () => {
    expect(getCouponStatus(window, new Date('2026-01-15T00:00:00'))).toBe('Valid');
  });

  it('returns Expired when now is after endAt', () => {
    expect(getCouponStatus(window, new Date('2026-01-25T00:00:00'))).toBe('Expired');
  });

  it('returns Valid when now equals startAt exactly (boundary)', () => {
    expect(getCouponStatus(window, new Date(startAt))).toBe('Valid');
  });

  it('returns Valid when now equals endAt exactly (boundary)', () => {
    expect(getCouponStatus(window, new Date(endAt))).toBe('Valid');
  });

  it('returns Expired when now is 1ms after endAt (boundary)', () => {
    expect(getCouponStatus(window, new Date(new Date(endAt).getTime() + 1))).toBe('Expired');
  });

  it('returns Scheduled when now is 1ms before startAt (boundary)', () => {
    expect(getCouponStatus(window, new Date(new Date(startAt).getTime() - 1))).toBe('Scheduled');
  });

  it('defaults now to the current time when not supplied', () => {
    const past: Pick<CouponResponse, 'enabled' | 'startAt' | 'endAt'> = {
      enabled: true,
      startAt: '2020-01-01T00:00:00',
      endAt: '2020-01-02T00:00:00',
    };

    expect(getCouponStatus(past)).toBe('Expired');
  });
});
