import { act, renderHook } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';

import { AppError } from '@/core/error/app-error';

import { useOrderDetail } from './use-order-detail';
import type { AdminOrderDetailResponse } from '../models/admin-order-detail-response';
import type { OrderRepository } from '../repositories/order-repository';

const ORDER_ID = 9;

const detail: AdminOrderDetailResponse = {
  id: ORDER_ID,
  orderCode: 'FV-ORDER-9',
  status: 'PENDING',
  paymentMethod: 'COD',
  paymentStatus: 'UNPAID',
  subtotal: 200,
  discountAmount: 0,
  shippingFee: 30000,
  total: 30200,
  couponCode: null,
  shippingRecipientName: 'Jane',
  shippingRecipientPhone: '0900000000',
  shippingProvince: 'HCM',
  shippingDistrict: 'D1',
  shippingWard: 'W1',
  shippingStreetAddress: '1 Street',
  note: null,
  items: [
    {
      id: 1,
      productVariantId: 7,
      productId: 100,
      productName: 'Air Force 1',
      productImageUrl: 'https://example.com/air-force-1.png',
      color: 'Black',
      size: '42',
      unitPrice: 100,
      quantity: 2,
      lineTotal: 200,
    },
  ],
  createdAt: '2026-01-01T00:00:00',
  cancelledAt: null,
  deliveredAt: null,
  customerId: 42,
  customerFullName: 'Jane Doe',
  customerEmail: 'jane@example.com',
  customerPhone: '0900000001',
};

function fakeRepository(overrides: Partial<OrderRepository>): OrderRepository {
  return overrides as unknown as OrderRepository;
}

describe('useOrderDetail', () => {
  it('starts in the loading status', () => {
    const repository = fakeRepository({ get: vi.fn().mockResolvedValue(detail) });
    const { result } = renderHook(() => useOrderDetail(repository, ORDER_ID));

    expect(result.current.status).toBe('loading');
    expect(result.current.order).toBeNull();
  });

  it('load reads the order by the given id and exposes it as ready', async () => {
    const get = vi.fn().mockResolvedValue(detail);
    const repository = fakeRepository({ get });
    const { result } = renderHook(() => useOrderDetail(repository, ORDER_ID));

    await act(async () => {
      await result.current.load();
    });

    expect(get).toHaveBeenCalledWith(ORDER_ID);
    expect(result.current.status).toBe('ready');
    expect(result.current.order).toEqual(detail);
    expect(result.current.error).toBeNull();
  });

  it('moves to the error status on a failed load', async () => {
    const repository = fakeRepository({
      get: vi.fn().mockRejectedValue(new AppError({ message: 'Unable to reach the server' })),
    });
    const { result } = renderHook(() => useOrderDetail(repository, ORDER_ID));

    await act(async () => {
      await result.current.load();
    });

    expect(result.current.status).toBe('error');
    expect(result.current.error).toBeInstanceOf(AppError);
    expect(result.current.order).toBeNull();
  });

  it('surfaces a stale id as AppError with ORDER_NOT_FOUND', async () => {
    const notFound = new AppError({
      message: 'Order not found',
      statusCode: 404,
      errorCode: 'ORDER_NOT_FOUND',
    });
    const repository = fakeRepository({ get: vi.fn().mockRejectedValue(notFound) });
    const { result } = renderHook(() => useOrderDetail(repository, ORDER_ID));

    await act(async () => {
      await result.current.load();
    });

    expect(result.current.status).toBe('error');
    expect(result.current.error).toMatchObject({ statusCode: 404, errorCode: 'ORDER_NOT_FOUND' });
  });

  it('retry re-reads the order and recovers from an error', async () => {
    const get = vi
      .fn()
      .mockRejectedValueOnce(new AppError({ message: 'down' }))
      .mockResolvedValueOnce(detail);
    const repository = fakeRepository({ get });
    const { result } = renderHook(() => useOrderDetail(repository, ORDER_ID));

    await act(async () => {
      await result.current.load();
    });
    expect(result.current.status).toBe('error');

    await act(async () => {
      await result.current.retry();
    });

    expect(result.current.status).toBe('ready');
    expect(result.current.order).toEqual(detail);
    expect(get).toHaveBeenCalledTimes(2);
  });

  it('updateStatus succeeds and replaces order entirely with the server response', async () => {
    const delivered: AdminOrderDetailResponse = {
      ...detail,
      status: 'DELIVERED',
      paymentStatus: 'PAID',
      deliveredAt: '2026-01-05T00:00:00',
    };
    const get = vi.fn().mockResolvedValue(detail);
    const updateStatus = vi.fn().mockResolvedValue(delivered);
    const repository = fakeRepository({ get, updateStatus });
    const { result } = renderHook(() => useOrderDetail(repository, ORDER_ID));

    await act(async () => {
      await result.current.load();
    });

    await act(async () => {
      await result.current.updateStatus('DELIVERED');
    });

    expect(updateStatus).toHaveBeenCalledWith(ORDER_ID, { status: 'DELIVERED' });
    // The new state is exactly the server's response — paymentStatus and
    // deliveredAt are never computed client-side.
    expect(result.current.order).toEqual(delivered);
    expect(result.current.order).toBe(delivered);
    expect(result.current.isUpdatingStatus).toBe(false);
  });

  it('rejects an invalid transition with AppError ORDER_INVALID_STATUS_TRANSITION and leaves order unchanged', async () => {
    const invalidTransition = new AppError({
      message: 'Order status transition is not allowed',
      statusCode: 409,
      errorCode: 'ORDER_INVALID_STATUS_TRANSITION',
    });
    const get = vi.fn().mockResolvedValue(detail);
    const updateStatus = vi.fn().mockRejectedValue(invalidTransition);
    const repository = fakeRepository({ get, updateStatus });
    const { result } = renderHook(() => useOrderDetail(repository, ORDER_ID));

    await act(async () => {
      await result.current.load();
    });

    await act(async () => {
      await expect(result.current.updateStatus('DELIVERED')).rejects.toBe(invalidTransition);
    });

    expect(result.current.order).toEqual(detail);
    expect(result.current.isUpdatingStatus).toBe(false);
  });

  it('rejects a non-cancellable order with AppError ORDER_NOT_CANCELLABLE and leaves order unchanged', async () => {
    const notCancellable = new AppError({
      message: 'Order can only be cancelled while PENDING',
      statusCode: 409,
      errorCode: 'ORDER_NOT_CANCELLABLE',
    });
    const get = vi.fn().mockResolvedValue(detail);
    const updateStatus = vi.fn().mockRejectedValue(notCancellable);
    const repository = fakeRepository({ get, updateStatus });
    const { result } = renderHook(() => useOrderDetail(repository, ORDER_ID));

    await act(async () => {
      await result.current.load();
    });

    await act(async () => {
      await expect(result.current.updateStatus('CANCELLED')).rejects.toBe(notCancellable);
    });

    expect(result.current.order).toEqual(detail);
  });

  it('is single-flight: a concurrent updateStatus call is ignored', async () => {
    let resolveUpdate: (value: AdminOrderDetailResponse) => void = () => undefined;
    const updateStatus = vi.fn().mockImplementation(
      () =>
        new Promise<AdminOrderDetailResponse>((resolve) => {
          resolveUpdate = resolve;
        }),
    );
    const get = vi.fn().mockResolvedValue(detail);
    const repository = fakeRepository({ get, updateStatus });
    const { result } = renderHook(() => useOrderDetail(repository, ORDER_ID));

    await act(async () => {
      await result.current.load();
    });

    await act(async () => {
      const first = result.current.updateStatus('CONFIRMED');
      const second = result.current.updateStatus('CONFIRMED');
      resolveUpdate({ ...detail, status: 'CONFIRMED' });
      await Promise.all([first, second]);
    });

    expect(updateStatus).toHaveBeenCalledTimes(1);
  });
});
