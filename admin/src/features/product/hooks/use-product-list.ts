import { useCallback, useRef, useState } from 'react';

import { AppError } from '@/core/error/app-error';

import type { AdminProductSummaryResponse } from '../models/admin-product-summary-response';
import type { ProductRepository } from '../repositories/product-repository';

const UNEXPECTED_MESSAGE = 'An unexpected error occurred';
const PAGE_SIZE = 20;

export type ProductListStatus = 'loading' | 'ready' | 'error';

export interface UseProductListResult {
  readonly status: ProductListStatus;
  readonly products: readonly AdminProductSummaryResponse[];
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
 * The product-list load state machine — the React analog of the Flutter
 * `AddressProvider` load half (react-guidelines §Hook Lifecycle), adapted for
 * the paginated ADMIN product read. Mirrors `useBrandList` (Sprint 10)
 * verbatim; the only difference is consuming `PageResponse` (page / size /
 * totalPages) instead of a plain array.
 *
 * It owns its own state (`useState`) and re-reads on every mount — it caches
 * nothing across mounts, and the server is always the source of truth. It
 * performs no navigation and touches no storage. `load` always re-reads the
 * currently displayed page (tracked in a ref so its identity stays stable),
 * so a caller — including a mutation's reload callback — reloads in place
 * without resetting to the first page.
 */
export function useProductList(repository: ProductRepository): UseProductListResult {
  const [status, setStatus] = useState<ProductListStatus>('loading');
  const [products, setProducts] = useState<readonly AdminProductSummaryResponse[]>([]);
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
        setProducts(result.content);
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

  return { status, products, page, totalPages, error, load, retry: load, goToPage };
}
