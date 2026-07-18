import { act, renderHook } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';

import { AppError } from '@/core/error/app-error';

import { useOrderList } from './use-order-list';
import type { AdminOrderSummaryResponse } from '../models/admin-order-summary-response';
import type { OrderRepository } from '../repositories/order-repository';

const order: AdminOrderSummaryResponse = {
  id: 5,
  orderCode: 'FV-ORDER-5',
  status: 'PENDING',
  paymentStatus: 'UNPAID',
  total: 30200,
  itemCount: 5,
  createdAt: '2026-01-01T00:00:00',
  customerId: 42,
  customerFullName: 'Jane Doe',
  customerEmail: 'jane@example.com',
  customerPhone: '0900000001',
};

function fakeRepository(overrides: Partial<OrderRepository>): OrderRepository {
  return overrides as unknown as OrderRepository;
}

function page(
  content: readonly AdminOrderSummaryResponse[],
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

describe('useOrderList', () => {
  it('starts in the loading status', () => {
    const repository = fakeRepository({ list: vi.fn().mockResolvedValue(page([])) });
    const { result } = renderHook(() => useOrderList(repository));

    expect(result.current.status).toBe('loading');
    expect(result.current.orders).toEqual([]);
  });

  it('load reads the first page and exposes it as ready', async () => {
    const list = vi.fn().mockResolvedValue(page([order], { page: 0, totalPages: 3 }));
    const repository = fakeRepository({ list });
    const { result } = renderHook(() => useOrderList(repository));

    await act(async () => {
      await result.current.load();
    });

    expect(result.current.status).toBe('ready');
    expect(result.current.orders).toEqual([order]);
    expect(result.current.page).toBe(0);
    expect(result.current.totalPages).toBe(3);
    expect(result.current.error).toBeNull();
    expect(list).toHaveBeenCalledWith({ page: 0, size: 20, status: undefined, orderCode: '' });
  });

  it('load with an empty result exposes ready with no orders', async () => {
    const repository = fakeRepository({ list: vi.fn().mockResolvedValue(page([])) });
    const { result } = renderHook(() => useOrderList(repository));

    await act(async () => {
      await result.current.load();
    });

    expect(result.current.status).toBe('ready');
    expect(result.current.orders).toEqual([]);
    expect(result.current.totalPages).toBe(1);
  });

  it('moves to the error status on a failed load', async () => {
    const repository = fakeRepository({
      list: vi.fn().mockRejectedValue(new AppError({ message: 'Unable to reach the server' })),
    });
    const { result } = renderHook(() => useOrderList(repository));

    await act(async () => {
      await result.current.load();
    });

    expect(result.current.status).toBe('error');
    expect(result.current.error).toBeInstanceOf(AppError);
    expect(result.current.orders).toEqual([]);
  });

  it('retry re-reads the same page and recovers from an error', async () => {
    const list = vi
      .fn()
      .mockRejectedValueOnce(new AppError({ message: 'down' }))
      .mockResolvedValueOnce(page([order]));
    const repository = fakeRepository({ list });
    const { result } = renderHook(() => useOrderList(repository));

    await act(async () => {
      await result.current.load();
    });
    expect(result.current.status).toBe('error');

    await act(async () => {
      await result.current.retry();
    });

    expect(result.current.status).toBe('ready');
    expect(result.current.orders).toEqual([order]);
    expect(list).toHaveBeenCalledTimes(2);
    expect(list).toHaveBeenNthCalledWith(2, {
      page: 0,
      size: 20,
      status: undefined,
      orderCode: '',
    });
  });

  it('goToPage loads the requested page and load() then reloads that same page', async () => {
    const otherOrder: AdminOrderSummaryResponse = { ...order, id: 6, orderCode: 'FV-ORDER-6' };
    const list = vi
      .fn()
      .mockResolvedValueOnce(page([order], { page: 0, totalPages: 2 }))
      .mockResolvedValueOnce(page([otherOrder], { page: 1, totalPages: 2 }))
      .mockResolvedValueOnce(page([otherOrder], { page: 1, totalPages: 2 }));
    const repository = fakeRepository({ list });
    const { result } = renderHook(() => useOrderList(repository));

    await act(async () => {
      await result.current.load();
    });
    expect(result.current.page).toBe(0);

    await act(async () => {
      await result.current.goToPage(1);
    });

    expect(list).toHaveBeenNthCalledWith(2, {
      page: 1,
      size: 20,
      status: undefined,
      orderCode: '',
    });
    expect(result.current.status).toBe('ready');
    expect(result.current.page).toBe(1);
    expect(result.current.orders).toEqual([otherOrder]);

    // A subsequent load() re-reads the current page (1), not the first page —
    // preserving list position.
    await act(async () => {
      await result.current.load();
    });

    expect(list).toHaveBeenNthCalledWith(3, {
      page: 1,
      size: 20,
      status: undefined,
      orderCode: '',
    });
  });

  it('setStatusFilter applies the filter and resets to page 0', async () => {
    const list = vi
      .fn()
      .mockResolvedValueOnce(page([order], { page: 1, totalPages: 2 }))
      .mockResolvedValueOnce(page([order], { page: 0, totalPages: 1 }));
    const repository = fakeRepository({ list });
    const { result } = renderHook(() => useOrderList(repository));

    await act(async () => {
      await result.current.goToPage(1);
    });
    expect(result.current.page).toBe(1);

    await act(async () => {
      await result.current.setStatusFilter('DELIVERED');
    });

    expect(list).toHaveBeenNthCalledWith(2, {
      page: 0,
      size: 20,
      status: 'DELIVERED',
      orderCode: '',
    });
    expect(result.current.statusFilter).toBe('DELIVERED');
    expect(result.current.page).toBe(0);
  });

  it('the status filter survives a subsequent page change', async () => {
    const list = vi
      .fn()
      .mockResolvedValueOnce(page([order], { page: 0, totalPages: 3 }))
      .mockResolvedValueOnce(page([order], { page: 1, totalPages: 3 }));
    const repository = fakeRepository({ list });
    const { result } = renderHook(() => useOrderList(repository));

    await act(async () => {
      await result.current.setStatusFilter('PENDING');
    });

    await act(async () => {
      await result.current.goToPage(1);
    });

    expect(list).toHaveBeenNthCalledWith(2, {
      page: 1,
      size: 20,
      status: 'PENDING',
      orderCode: '',
    });
  });

  it('setStatusFilter(undefined) clears the filter and re-queries with no status param', async () => {
    const list = vi
      .fn()
      .mockResolvedValueOnce(page([order]))
      .mockResolvedValueOnce(page([order]));
    const repository = fakeRepository({ list });
    const { result } = renderHook(() => useOrderList(repository));

    await act(async () => {
      await result.current.setStatusFilter('CANCELLED');
    });
    expect(result.current.statusFilter).toBe('CANCELLED');

    await act(async () => {
      await result.current.setStatusFilter(undefined);
    });

    expect(list).toHaveBeenNthCalledWith(2, {
      page: 0,
      size: 20,
      status: undefined,
      orderCode: '',
    });
    expect(result.current.statusFilter).toBeUndefined();
  });

  it('setOrderCodeSearch applies the search and resets to page 0', async () => {
    const list = vi
      .fn()
      .mockResolvedValueOnce(page([order], { page: 1, totalPages: 2 }))
      .mockResolvedValueOnce(page([order], { page: 0, totalPages: 1 }));
    const repository = fakeRepository({ list });
    const { result } = renderHook(() => useOrderList(repository));

    await act(async () => {
      await result.current.goToPage(1);
    });
    expect(result.current.page).toBe(1);

    await act(async () => {
      await result.current.setOrderCodeSearch('FV-2026');
    });

    expect(list).toHaveBeenNthCalledWith(2, {
      page: 0,
      size: 20,
      status: undefined,
      orderCode: 'FV-2026',
    });
    expect(result.current.orderCodeSearch).toBe('FV-2026');
    expect(result.current.page).toBe(0);
  });

  it('the order-code search survives a subsequent page change', async () => {
    const list = vi
      .fn()
      .mockResolvedValueOnce(page([order], { page: 0, totalPages: 3 }))
      .mockResolvedValueOnce(page([order], { page: 1, totalPages: 3 }));
    const repository = fakeRepository({ list });
    const { result } = renderHook(() => useOrderList(repository));

    await act(async () => {
      await result.current.setOrderCodeSearch('FV-2026');
    });

    await act(async () => {
      await result.current.goToPage(1);
    });

    expect(list).toHaveBeenNthCalledWith(2, {
      page: 1,
      size: 20,
      status: undefined,
      orderCode: 'FV-2026',
    });
  });

  it("setOrderCodeSearch('') clears the search and re-queries with no orderCode param", async () => {
    const list = vi
      .fn()
      .mockResolvedValueOnce(page([order]))
      .mockResolvedValueOnce(page([order]));
    const repository = fakeRepository({ list });
    const { result } = renderHook(() => useOrderList(repository));

    await act(async () => {
      await result.current.setOrderCodeSearch('FV-2026');
    });
    expect(result.current.orderCodeSearch).toBe('FV-2026');

    await act(async () => {
      await result.current.setOrderCodeSearch('');
    });

    expect(list).toHaveBeenNthCalledWith(2, {
      page: 0,
      size: 20,
      status: undefined,
      orderCode: '',
    });
    expect(result.current.orderCodeSearch).toBe('');
  });

  it('the status filter and order-code search combine on every request', async () => {
    const list = vi
      .fn()
      .mockResolvedValueOnce(page([order]))
      .mockResolvedValueOnce(page([order]))
      .mockResolvedValueOnce(page([order], { page: 1, totalPages: 2 }));
    const repository = fakeRepository({ list });
    const { result } = renderHook(() => useOrderList(repository));

    await act(async () => {
      await result.current.setStatusFilter('PENDING');
    });
    await act(async () => {
      await result.current.setOrderCodeSearch('FV-2026');
    });

    expect(list).toHaveBeenNthCalledWith(2, {
      page: 0,
      size: 20,
      status: 'PENDING',
      orderCode: 'FV-2026',
    });
    expect(result.current.statusFilter).toBe('PENDING');
    expect(result.current.orderCodeSearch).toBe('FV-2026');

    // Both criteria still apply together on a subsequent page change.
    await act(async () => {
      await result.current.goToPage(1);
    });

    expect(list).toHaveBeenNthCalledWith(3, {
      page: 1,
      size: 20,
      status: 'PENDING',
      orderCode: 'FV-2026',
    });
  });
});
