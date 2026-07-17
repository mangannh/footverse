import { act, renderHook } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';

import { AppError } from '@/core/error/app-error';

import { useBrandList } from './use-brand-list';
import type { BrandResponse } from '../models/brand-response';
import type { BrandRepository } from '../repositories/brand-repository';

const brand: BrandResponse = { id: 1, name: 'Nike' };

function fakeRepository(overrides: Partial<BrandRepository>): BrandRepository {
  return overrides as unknown as BrandRepository;
}

describe('useBrandList', () => {
  it('loads the list and exposes it as ready', async () => {
    const repository = fakeRepository({ list: vi.fn().mockResolvedValue([brand]) });
    const { result } = renderHook(() => useBrandList(repository));

    expect(result.current.status).toBe('loading');

    await act(async () => {
      await result.current.load();
    });

    expect(result.current.status).toBe('ready');
    expect(result.current.brands).toEqual([brand]);
    expect(result.current.error).toBeNull();
  });

  it('moves to the error status on a failed load', async () => {
    const repository = fakeRepository({
      list: vi.fn().mockRejectedValue(new AppError({ message: 'Unable to reach the server' })),
    });
    const { result } = renderHook(() => useBrandList(repository));

    await act(async () => {
      await result.current.load();
    });

    expect(result.current.status).toBe('error');
    expect(result.current.error).toBeInstanceOf(AppError);
    expect(result.current.brands).toEqual([]);
  });

  it('retry re-reads the list and recovers from an error', async () => {
    const list = vi
      .fn()
      .mockRejectedValueOnce(new AppError({ message: 'down' }))
      .mockResolvedValueOnce([brand]);
    const repository = fakeRepository({ list });
    const { result } = renderHook(() => useBrandList(repository));

    await act(async () => {
      await result.current.load();
    });
    expect(result.current.status).toBe('error');

    await act(async () => {
      await result.current.retry();
    });

    expect(result.current.status).toBe('ready');
    expect(result.current.brands).toEqual([brand]);
    expect(list).toHaveBeenCalledTimes(2);
  });
});
