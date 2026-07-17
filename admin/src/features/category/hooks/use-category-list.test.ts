import { act, renderHook } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';

import { AppError } from '@/core/error/app-error';

import { useCategoryList } from './use-category-list';
import type { CategoryResponse } from '../models/category-response';
import type { CategoryRepository } from '../repositories/category-repository';

const category: CategoryResponse = { id: 1, name: 'Running Shoes' };

function fakeRepository(overrides: Partial<CategoryRepository>): CategoryRepository {
  return overrides as unknown as CategoryRepository;
}

describe('useCategoryList', () => {
  it('loads the list and exposes it as ready', async () => {
    const repository = fakeRepository({ list: vi.fn().mockResolvedValue([category]) });
    const { result } = renderHook(() => useCategoryList(repository));

    expect(result.current.status).toBe('loading');

    await act(async () => {
      await result.current.load();
    });

    expect(result.current.status).toBe('ready');
    expect(result.current.categories).toEqual([category]);
    expect(result.current.error).toBeNull();
  });

  it('moves to the error status on a failed load', async () => {
    const repository = fakeRepository({
      list: vi.fn().mockRejectedValue(new AppError({ message: 'Unable to reach the server' })),
    });
    const { result } = renderHook(() => useCategoryList(repository));

    await act(async () => {
      await result.current.load();
    });

    expect(result.current.status).toBe('error');
    expect(result.current.error).toBeInstanceOf(AppError);
    expect(result.current.categories).toEqual([]);
  });

  it('retry re-reads the list and recovers from an error', async () => {
    const list = vi
      .fn()
      .mockRejectedValueOnce(new AppError({ message: 'down' }))
      .mockResolvedValueOnce([category]);
    const repository = fakeRepository({ list });
    const { result } = renderHook(() => useCategoryList(repository));

    await act(async () => {
      await result.current.load();
    });
    expect(result.current.status).toBe('error');

    await act(async () => {
      await result.current.retry();
    });

    expect(result.current.status).toBe('ready');
    expect(result.current.categories).toEqual([category]);
    expect(list).toHaveBeenCalledTimes(2);
  });
});
