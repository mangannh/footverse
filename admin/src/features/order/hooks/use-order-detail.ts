import { useCallback, useRef, useState } from 'react';

import { AppError } from '@/core/error/app-error';

import type { AdminOrderDetailResponse } from '../models/admin-order-detail-response';
import type { OrderStatus } from '../models/order-status';
import type { OrderRepository } from '../repositories/order-repository';

const UNEXPECTED_MESSAGE = 'An unexpected error occurred';

export type OrderDetailStatus = 'loading' | 'ready' | 'error';

export interface UseOrderDetailResult {
  readonly status: OrderDetailStatus;
  readonly order: AdminOrderDetailResponse | null;
  readonly error: AppError | null;
  /** True while a status transition is in flight (single-flight). */
  readonly isUpdatingStatus: boolean;
  /** Loads (or reloads) the order — called once on page mount. */
  load(): Promise<void>;
  /** Retries the load after an error. */
  retry(): Promise<void>;
  /** Advances the order to the given target status. */
  updateStatus(target: OrderStatus): Promise<void>;
}

/**
 * The order-detail load-and-transition state machine — the admin panel's
 * first hook combining a by-id load with a mutation on the same resource
 * (react-guidelines §Hook Lifecycle), since an order detail is reached by
 * route id, never by state handed over from the list (sprint-12-plan
 * Design Decision 5). It owns its own state (`useState`) and re-reads on
 * every mount; it caches nothing across mounts and performs no navigation.
 *
 * `updateStatus` is **single-flight** (a concurrent call is a no-op) and
 * **rethrows** `AppError` on failure, leaving `order` untouched — no
 * optimistic update. On success it replaces `order` directly with the
 * response `PATCH /orders/{id}/status` returns, which is already the full
 * updated `AdminOrderDetailResponse` (including any server-computed
 * `paymentStatus` / `deliveredAt` / `cancelledAt`) — so no second `get(id)`
 * is ever issued (sprint-12-plan Task 05).
 */
export function useOrderDetail(repository: OrderRepository, orderId: number): UseOrderDetailResult {
  const [status, setStatus] = useState<OrderDetailStatus>('loading');
  const [order, setOrder] = useState<AdminOrderDetailResponse | null>(null);
  const [error, setError] = useState<AppError | null>(null);
  const [isUpdatingStatus, setIsUpdatingStatus] = useState(false);
  const inFlight = useRef(false);

  const load = useCallback(async (): Promise<void> => {
    setStatus('loading');
    setError(null);
    try {
      const result = await repository.get(orderId);
      setOrder(result);
      setStatus('ready');
    } catch (caught) {
      setError(caught instanceof AppError ? caught : new AppError({ message: UNEXPECTED_MESSAGE }));
      setStatus('error');
    }
  }, [repository, orderId]);

  const updateStatus = useCallback(
    async (target: OrderStatus): Promise<void> => {
      if (inFlight.current) {
        return;
      }
      inFlight.current = true;
      setIsUpdatingStatus(true);
      try {
        const result = await repository.updateStatus(orderId, { status: target });
        setOrder(result);
      } finally {
        inFlight.current = false;
        setIsUpdatingStatus(false);
      }
    },
    [repository, orderId],
  );

  return { status, order, error, isUpdatingStatus, load, retry: load, updateStatus };
}
