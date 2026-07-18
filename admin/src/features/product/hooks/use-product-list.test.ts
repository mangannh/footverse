import { act, renderHook } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';

import { AppError } from '@/core/error/app-error';

import { useProductList } from './use-product-list';
import type { AdminProductSummaryResponse } from '../models/admin-product-summary-response';
import type { ProductRepository } from '../repositories/product-repository';

const product: AdminProductSummaryResponse = {
  id: 1,
  name: 'Air Zoom',
  basePrice: 120,
  brandName: 'Nike',
  categoryName: 'Running',
  averageRating: 4.5,
  available: true,
};

function fakeRepository(overrides: Partial<ProductRepository>): ProductRepository {
  return overrides as unknown as ProductRepository;
}

function page(
  content: readonly AdminProductSummaryResponse[],
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

describe('useProductList', () => {
  it('loads the first page and exposes it as ready', async () => {
    const list = vi.fn().mockResolvedValue(page([product], { page: 0, totalPages: 3 }));
    const repository = fakeRepository({ list });
    const { result } = renderHook(() => useProductList(repository));

    expect(result.current.status).toBe('loading');

    await act(async () => {
      await result.current.load();
    });

    expect(result.current.status).toBe('ready');
    expect(result.current.products).toEqual([product]);
    expect(result.current.page).toBe(0);
    expect(result.current.totalPages).toBe(3);
    expect(result.current.error).toBeNull();
    expect(list).toHaveBeenCalledWith({ page: 0, size: 20 });
  });

  it('moves to the error status on a failed load', async () => {
    const repository = fakeRepository({
      list: vi.fn().mockRejectedValue(new AppError({ message: 'Unable to reach the server' })),
    });
    const { result } = renderHook(() => useProductList(repository));

    await act(async () => {
      await result.current.load();
    });

    expect(result.current.status).toBe('error');
    expect(result.current.error).toBeInstanceOf(AppError);
    expect(result.current.products).toEqual([]);
  });

  it('retry re-reads the same page and recovers from an error', async () => {
    const list = vi
      .fn()
      .mockRejectedValueOnce(new AppError({ message: 'down' }))
      .mockResolvedValueOnce(page([product]));
    const repository = fakeRepository({ list });
    const { result } = renderHook(() => useProductList(repository));

    await act(async () => {
      await result.current.load();
    });
    expect(result.current.status).toBe('error');

    await act(async () => {
      await result.current.retry();
    });

    expect(result.current.status).toBe('ready');
    expect(result.current.products).toEqual([product]);
    expect(list).toHaveBeenCalledTimes(2);
    expect(list).toHaveBeenNthCalledWith(2, { page: 0, size: 20 });
  });

  it('goToPage loads the requested page and load() then reloads that same page', async () => {
    const otherProduct: AdminProductSummaryResponse = { ...product, id: 2, name: 'Air Max' };
    const list = vi
      .fn()
      .mockResolvedValueOnce(page([product], { page: 0, totalPages: 2 }))
      .mockResolvedValueOnce(page([otherProduct], { page: 1, totalPages: 2 }))
      .mockResolvedValueOnce(page([otherProduct], { page: 1, totalPages: 2 }));
    const repository = fakeRepository({ list });
    const { result } = renderHook(() => useProductList(repository));

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
    expect(result.current.products).toEqual([otherProduct]);

    // A subsequent load() (e.g. a post-delete reload) re-reads the current
    // page (1), not the first page — preserving list position.
    await act(async () => {
      await result.current.load();
    });

    expect(list).toHaveBeenNthCalledWith(3, { page: 1, size: 20 });
  });
});
