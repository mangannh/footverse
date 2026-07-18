import { act, renderHook } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';

import { AppError } from '@/core/error/app-error';

import { useCouponList } from './use-coupon-list';
import type { CouponResponse } from '../models/coupon-response';
import type { CouponRepository } from '../repositories/coupon-repository';

const coupon: CouponResponse = {
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

function fakeRepository(overrides: Partial<CouponRepository>): CouponRepository {
  return overrides as unknown as CouponRepository;
}

function page(
  content: readonly CouponResponse[],
  overrides: Partial<{ page: number; totalPages: number }> = {},
) {
  return {
    content,
    page: overrides.page ?? 0,
    size: 20,
    totalElements: content.length,
    totalPages: overrides.totalPages ?? 1,
    last: true,
  };
}

describe('useCouponList', () => {
  it('loads the first page and exposes it as ready', async () => {
    const list = vi.fn().mockResolvedValue(page([coupon], { page: 0, totalPages: 3 }));
    const repository = fakeRepository({ list });
    const { result } = renderHook(() => useCouponList(repository));

    expect(result.current.status).toBe('loading');

    await act(async () => {
      await result.current.load();
    });

    expect(result.current.status).toBe('ready');
    expect(result.current.coupons).toEqual([coupon]);
    expect(result.current.page).toBe(0);
    expect(result.current.totalPages).toBe(3);
    expect(result.current.error).toBeNull();
    expect(list).toHaveBeenCalledWith({ page: 0, size: 20 });
  });

  it('moves to the error status on a failed load', async () => {
    const repository = fakeRepository({
      list: vi.fn().mockRejectedValue(new AppError({ message: 'Unable to reach the server' })),
    });
    const { result } = renderHook(() => useCouponList(repository));

    await act(async () => {
      await result.current.load();
    });

    expect(result.current.status).toBe('error');
    expect(result.current.error).toBeInstanceOf(AppError);
    expect(result.current.coupons).toEqual([]);
  });

  it('retry re-reads the same page and recovers from an error', async () => {
    const list = vi
      .fn()
      .mockRejectedValueOnce(new AppError({ message: 'down' }))
      .mockResolvedValueOnce(page([coupon]));
    const repository = fakeRepository({ list });
    const { result } = renderHook(() => useCouponList(repository));

    await act(async () => {
      await result.current.load();
    });
    expect(result.current.status).toBe('error');

    await act(async () => {
      await result.current.retry();
    });

    expect(result.current.status).toBe('ready');
    expect(result.current.coupons).toEqual([coupon]);
    expect(list).toHaveBeenCalledTimes(2);
    expect(list).toHaveBeenNthCalledWith(2, { page: 0, size: 20 });
  });

  it('goToPage loads the requested page and load() then reloads that same page', async () => {
    const otherCoupon: CouponResponse = { ...coupon, id: 2, code: 'WINTER15' };
    const list = vi
      .fn()
      .mockResolvedValueOnce(page([coupon], { page: 0, totalPages: 2 }))
      .mockResolvedValueOnce(page([otherCoupon], { page: 1, totalPages: 2 }))
      .mockResolvedValueOnce(page([otherCoupon], { page: 1, totalPages: 2 }));
    const repository = fakeRepository({ list });
    const { result } = renderHook(() => useCouponList(repository));

    await act(async () => {
      await result.current.load();
    });
    expect(result.current.page).toBe(0);

    await act(async () => {
      await result.current.goToPage(1);
    });

    expect(list).toHaveBeenNthCalledWith(2, { page: 1, size: 20 });
    expect(result.current.status).toBe('ready');
    expect(result.current.page).toBe(1);
    expect(result.current.coupons).toEqual([otherCoupon]);

    await act(async () => {
      await result.current.load();
    });

    expect(list).toHaveBeenNthCalledWith(3, { page: 1, size: 20 });
  });
});
