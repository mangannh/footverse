import { useCallback, useRef, useState } from 'react';

import { AppError } from '@/core/error/app-error';

import type { AdminOrderSummaryResponse } from '../models/admin-order-summary-response';
import type { OrderStatus } from '../models/order-status';
import type { OrderRepository } from '../repositories/order-repository';

const UNEXPECTED_MESSAGE = 'An unexpected error occurred';
const PAGE_SIZE = 20;

export type OrderListStatus = 'loading' | 'ready' | 'error';

export interface UseOrderListResult {
  readonly status: OrderListStatus;
  readonly orders: readonly AdminOrderSummaryResponse[];
  readonly page: number;
  readonly totalPages: number;
  readonly statusFilter: OrderStatus | undefined;
  readonly orderCodeSearch: string;
  readonly error: AppError | null;
  /** Loads (or reloads) the current page, status filter, and search — called once on page mount. */
  load(): Promise<void>;
  /** Retries the load of the current page after an error. */
  retry(): Promise<void>;
  /** Loads a different page (server-driven paging); the current filter and search are preserved. */
  goToPage(page: number): Promise<void>;
  /** Applies (or clears, with `undefined`) the status filter and reloads from page 0. */
  setStatusFilter(status: OrderStatus | undefined): Promise<void>;
  /** Applies (or clears, with `''`) the order-code search and reloads from page 0. */
  setOrderCodeSearch(orderCode: string): Promise<void>;
}

/**
 * The order-list load state machine — the React analog of the Flutter
 * `AddressProvider` load half (react-guidelines §Hook Lifecycle), adapted for
 * the paginated, status-filtered, order-code-searchable ADMIN order read.
 * Mirrors `useProductList` (Sprint 11) verbatim for paging; the only addition
 * is the status filter and order-code search, both server-driven — a filter
 * or search change re-queries the server from page 0, and the page never
 * filters, searches, or sorts a loaded page in memory (sprint-12-plan Task 04).
 *
 * It owns its own state (`useState`) and re-reads on every mount — it caches
 * nothing across mounts, and the server is always the source of truth. It
 * performs no navigation and touches no storage. The current page, status
 * filter, and order-code search are tracked in refs (mirroring the Flutter
 * "reload in place" precedent) so `load()` always re-reads exactly what is
 * currently displayed, and a page change never drops the active filter/search.
 */
export function useOrderList(repository: OrderRepository): UseOrderListResult {
  const [status, setStatus] = useState<OrderListStatus>('loading');
  const [orders, setOrders] = useState<readonly AdminOrderSummaryResponse[]>([]);
  const [page, setPage] = useState(0);
  const [totalPages, setTotalPages] = useState(0);
  const [statusFilter, setStatusFilterState] = useState<OrderStatus | undefined>(undefined);
  const [orderCodeSearch, setOrderCodeSearchState] = useState('');
  const [error, setError] = useState<AppError | null>(null);
  const currentPage = useRef(0);
  const currentStatus = useRef<OrderStatus | undefined>(undefined);
  const currentOrderCode = useRef('');

  const loadPage = useCallback(
    async (targetPage: number): Promise<void> => {
      setStatus('loading');
      setError(null);
      try {
        const result = await repository.list({
          page: targetPage,
          size: PAGE_SIZE,
          status: currentStatus.current,
          orderCode: currentOrderCode.current,
        });
        currentPage.current = result.page;
        setOrders(result.content);
        setPage(result.page);
        setTotalPages(result.totalPages);
        setStatus('ready');
      } catch (caught) {
        setError(
          caught instanceof AppError ? caught : new AppError({ message: UNEXPECTED_MESSAGE }),
        );
        setStatus('error');
      }
    },
    [repository],
  );

  const load = useCallback(() => loadPage(currentPage.current), [loadPage]);
  const goToPage = useCallback((targetPage: number) => loadPage(targetPage), [loadPage]);

  const setStatusFilter = useCallback(
    (nextStatus: OrderStatus | undefined) => {
      currentStatus.current = nextStatus;
      setStatusFilterState(nextStatus);
      return loadPage(0);
    },
    [loadPage],
  );

  const setOrderCodeSearch = useCallback(
    (nextOrderCode: string) => {
      currentOrderCode.current = nextOrderCode;
      setOrderCodeSearchState(nextOrderCode);
      return loadPage(0);
    },
    [loadPage],
  );

  return {
    status,
    orders,
    page,
    totalPages,
    statusFilter,
    orderCodeSearch,
    error,
    load,
    retry: load,
    goToPage,
    setStatusFilter,
    setOrderCodeSearch,
  };
}
