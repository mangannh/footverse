import { useCallback, useRef, useState } from 'react';

import { AppError } from '@/core/error/app-error';

import type { CouponResponse } from '../models/coupon-response';
import type { CouponRepository } from '../repositories/coupon-repository';

const UNEXPECTED_MESSAGE = 'An unexpected error occurred';
const PAGE_SIZE = 20;

export type CouponListStatus = 'loading' | 'ready' | 'error';

export interface UseCouponListResult {
  readonly status: CouponListStatus;
  readonly coupons: readonly CouponResponse[];
  readonly page: number;
  readonly totalPages: number;
  readonly error: AppError | null;
  /** Loads (or reloads) the current page — called once on page mount. */
  load(): Promise<void>;
  /** Retries the load of the current page after an error. */
  retry(): Promise<void>;
  /** Loads a different page (server-driven paging). */
  goToPage(page: number): Promise<void>;
}

/**
 * The coupon-list load state machine — the React analog of the Flutter
 * provider load half (react-guidelines §Hook Lifecycle), adapted for the
 * paginated coupon read. Mirrors `useProductList` (Sprint 11 Task 03)
 * verbatim, which itself mirrors `useBrandList` (Sprint 10) extended for
 * `PageResponse` (page / size / totalPages) instead of a plain array.
 *
 * It owns its own state (`useState`) and re-reads on every mount — it caches
 * nothing across mounts, and the server is always the source of truth. It
 * performs no navigation and touches no storage. `load` always re-reads the
 * currently displayed page (tracked in a ref so its identity stays stable),
 * so a caller reloads in place without resetting to the first page.
 */
export function useCouponList(repository: CouponRepository): UseCouponListResult {
  const [status, setStatus] = useState<CouponListStatus>('loading');
  const [coupons, setCoupons] = useState<readonly CouponResponse[]>([]);
  const [page, setPage] = useState(0);
  const [totalPages, setTotalPages] = useState(0);
  const [error, setError] = useState<AppError | null>(null);
  const currentPage = useRef(0);

  const loadPage = useCallback(
    async (targetPage: number): Promise<void> => {
      setStatus('loading');
      setError(null);
      try {
        const result = await repository.list({ page: targetPage, size: PAGE_SIZE });
        currentPage.current = result.page;
        setCoupons(result.content);
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

  return { status, coupons, page, totalPages, error, load, retry: load, goToPage };
}
