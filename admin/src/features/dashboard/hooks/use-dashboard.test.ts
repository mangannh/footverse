import { act, renderHook } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';

import { AppError } from '@/core/error/app-error';
import type { AdminOrderSummaryResponse } from '@/features/order/models/admin-order-summary-response';

import { useDashboard } from './use-dashboard';
import type { DashboardResponse } from '../models/dashboard-response';
import type { DashboardRepository } from '../repositories/dashboard-repository';

const recentOrder: AdminOrderSummaryResponse = {
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

const dashboard: DashboardResponse = {
  totalRevenue: 500000,
  totalOrders: 12,
  grossProfit: 120000,
  profitLinesWithCost: 8,
  profitLinesTotal: 10,
  ordersByStatus: [
    { status: 'PENDING', count: 3 },
    { status: 'CONFIRMED', count: 0 },
    { status: 'SHIPPING', count: 0 },
    { status: 'DELIVERED', count: 9 },
    { status: 'CANCELLED', count: 0 },
  ],
  monthlyRevenue: [{ year: 2026, month: 7, revenue: 500000, orderCount: 12 }],
  bestSellingProducts: [
    {
      productId: 100,
      productName: 'Air Force 1',
      productImageUrl: 'https://example.com/air-force-1.png',
      quantitySold: 10,
      revenue: 1000,
    },
  ],
  recentOrders: [recentOrder],
};

const emptyStoreDashboard: DashboardResponse = {
  totalRevenue: 0,
  totalOrders: 0,
  grossProfit: 0,
  profitLinesWithCost: 0,
  profitLinesTotal: 0,
  ordersByStatus: [
    { status: 'PENDING', count: 0 },
    { status: 'CONFIRMED', count: 0 },
    { status: 'SHIPPING', count: 0 },
    { status: 'DELIVERED', count: 0 },
    { status: 'CANCELLED', count: 0 },
  ],
  monthlyRevenue: Array.from({ length: 12 }, (_, i) => ({
    year: 2026,
    month: i + 1,
    revenue: 0,
    orderCount: 0,
  })),
  bestSellingProducts: [],
  recentOrders: [],
};

function fakeRepository(overrides: Partial<DashboardRepository>): DashboardRepository {
  return overrides as unknown as DashboardRepository;
}

describe('useDashboard', () => {
  it('starts in the loading status', () => {
    const repository = fakeRepository({ get: vi.fn().mockResolvedValue(dashboard) });
    const { result } = renderHook(() => useDashboard(repository));

    expect(result.current.status).toBe('loading');
    expect(result.current.data).toBeNull();
  });

  it('load reads the dashboard and exposes it as ready', async () => {
    const get = vi.fn().mockResolvedValue(dashboard);
    const repository = fakeRepository({ get });
    const { result } = renderHook(() => useDashboard(repository));

    await act(async () => {
      await result.current.load();
    });

    expect(get).toHaveBeenCalledTimes(1);
    expect(result.current.status).toBe('ready');
    expect(result.current.data).toEqual(dashboard);
    expect(result.current.error).toBeNull();
  });

  it('moves to the error status on a failed load', async () => {
    const repository = fakeRepository({
      get: vi.fn().mockRejectedValue(new AppError({ message: 'Unable to reach the server' })),
    });
    const { result } = renderHook(() => useDashboard(repository));

    await act(async () => {
      await result.current.load();
    });

    expect(result.current.status).toBe('error');
    expect(result.current.error).toBeInstanceOf(AppError);
    expect(result.current.data).toBeNull();
  });

  it('surfaces a non-ADMIN forbidden response as AppError with FORBIDDEN', async () => {
    const forbidden = new AppError({
      message: 'You cannot access this resource',
      statusCode: 403,
      errorCode: 'FORBIDDEN',
    });
    const repository = fakeRepository({ get: vi.fn().mockRejectedValue(forbidden) });
    const { result } = renderHook(() => useDashboard(repository));

    await act(async () => {
      await result.current.load();
    });

    expect(result.current.status).toBe('error');
    expect(result.current.error).toMatchObject({ statusCode: 403, errorCode: 'FORBIDDEN' });
  });

  it('retry re-reads the dashboard and recovers from an error', async () => {
    const get = vi
      .fn()
      .mockRejectedValueOnce(new AppError({ message: 'down' }))
      .mockResolvedValueOnce(dashboard);
    const repository = fakeRepository({ get });
    const { result } = renderHook(() => useDashboard(repository));

    await act(async () => {
      await result.current.load();
    });
    expect(result.current.status).toBe('error');

    await act(async () => {
      await result.current.retry();
    });

    expect(result.current.status).toBe('ready');
    expect(result.current.data).toEqual(dashboard);
    expect(get).toHaveBeenCalledTimes(2);
  });

  it('is single-flight: a concurrent load call issues only one request', async () => {
    let resolveGet: (value: DashboardResponse) => void = () => undefined;
    const get = vi.fn().mockImplementation(
      () =>
        new Promise<DashboardResponse>((resolve) => {
          resolveGet = resolve;
        }),
    );
    const repository = fakeRepository({ get });
    const { result } = renderHook(() => useDashboard(repository));

    await act(async () => {
      const first = result.current.load();
      const second = result.current.load();
      resolveGet(dashboard);
      await Promise.all([first, second]);
    });

    expect(get).toHaveBeenCalledTimes(1);
    expect(result.current.status).toBe('ready');
  });

  it('loads an empty-store payload as ready — zeros and empty lists, never an error', async () => {
    const get = vi.fn().mockResolvedValue(emptyStoreDashboard);
    const repository = fakeRepository({ get });
    const { result } = renderHook(() => useDashboard(repository));

    await act(async () => {
      await result.current.load();
    });

    expect(result.current.status).toBe('ready');
    expect(result.current.error).toBeNull();
    expect(result.current.data?.totalOrders).toBe(0);
    expect(result.current.data?.ordersByStatus).toHaveLength(5);
    expect(result.current.data?.monthlyRevenue).toHaveLength(12);
    expect(result.current.data?.bestSellingProducts).toEqual([]);
    expect(result.current.data?.recentOrders).toEqual([]);
  });
});
