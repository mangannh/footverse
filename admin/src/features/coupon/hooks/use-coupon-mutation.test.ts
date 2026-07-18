import { act, renderHook } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';

import { AppError } from '@/core/error/app-error';

import { useCouponMutation } from './use-coupon-mutation';
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

const request = {
  code: 'SUMMER10',
  name: 'Summer Sale',
  discountType: 'PERCENT' as const,
  discountValue: 10,
  minOrderAmount: 50,
  startAt: '2026-01-01T00:00:00',
  endAt: '2026-02-01T00:00:00',
  enabled: true,
};

function fakeRepository(overrides: Partial<CouponRepository>): CouponRepository {
  return overrides as unknown as CouponRepository;
}

describe('useCouponMutation', () => {
  it('create succeeds and reloads the list from the server', async () => {
    const repository = fakeRepository({ create: vi.fn().mockResolvedValue(coupon) });
    const reload = vi.fn().mockResolvedValue(undefined);
    const { result } = renderHook(() => useCouponMutation(repository, reload));

    await act(async () => {
      await result.current.create(request);
    });

    expect(repository.create).toHaveBeenCalledWith(request);
    expect(reload).toHaveBeenCalledTimes(1);
    expect(result.current.isMutating).toBe(false);
  });

  it('update succeeds and reloads the list from the server', async () => {
    const repository = fakeRepository({ update: vi.fn().mockResolvedValue(coupon) });
    const reload = vi.fn().mockResolvedValue(undefined);
    const { result } = renderHook(() => useCouponMutation(repository, reload));

    await act(async () => {
      await result.current.update(1, request);
    });

    expect(repository.update).toHaveBeenCalledWith(1, request);
    expect(reload).toHaveBeenCalledTimes(1);
  });

  it('rethrows a duplicate-code AppError and does not reload', async () => {
    const duplicateError = new AppError({
      message: 'Coupon code already exists',
      statusCode: 409,
      errorCode: 'COUPON_CODE_DUPLICATED',
    });
    const repository = fakeRepository({ create: vi.fn().mockRejectedValue(duplicateError) });
    const reload = vi.fn().mockResolvedValue(undefined);
    const { result } = renderHook(() => useCouponMutation(repository, reload));

    await act(async () => {
      await expect(result.current.create(request)).rejects.toBe(duplicateError);
    });

    expect(reload).not.toHaveBeenCalled();
    expect(result.current.isMutating).toBe(false);
  });

  it('rethrows an invalid-date-range AppError on update and does not reload', async () => {
    const dateRangeError = new AppError({
      message: 'Coupon end date must be after start date',
      statusCode: 400,
      errorCode: 'COUPON_INVALID_DATE_RANGE',
    });
    const repository = fakeRepository({ update: vi.fn().mockRejectedValue(dateRangeError) });
    const reload = vi.fn().mockResolvedValue(undefined);
    const { result } = renderHook(() => useCouponMutation(repository, reload));

    await act(async () => {
      await expect(result.current.update(1, request)).rejects.toBe(dateRangeError);
    });

    expect(reload).not.toHaveBeenCalled();
  });

  it('is single-flight: a concurrent create is ignored', async () => {
    let resolveCreate: (value: CouponResponse) => void = () => undefined;
    const create = vi.fn().mockImplementation(
      () =>
        new Promise<CouponResponse>((resolve) => {
          resolveCreate = resolve;
        }),
    );
    const repository = fakeRepository({ create });
    const reload = vi.fn().mockResolvedValue(undefined);
    const { result } = renderHook(() => useCouponMutation(repository, reload));

    await act(async () => {
      const first = result.current.create(request);
      const second = result.current.create(request);
      resolveCreate(coupon);
      await Promise.all([first, second]);
    });

    expect(create).toHaveBeenCalledTimes(1);
    expect(reload).toHaveBeenCalledTimes(1);
  });
});
