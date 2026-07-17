import { useCallback, useState } from 'react';

import { AppError } from '@/core/error/app-error';

import type { CategoryResponse } from '../models/category-response';
import type { CategoryRepository } from '../repositories/category-repository';

const UNEXPECTED_MESSAGE = 'An unexpected error occurred';

export type CategoryListStatus = 'loading' | 'ready' | 'error';

export interface UseCategoryListResult {
  readonly status: CategoryListStatus;
  readonly categories: readonly CategoryResponse[];
  readonly error: AppError | null;
  /** Loads the category list (called once on page mount). */
  load(): Promise<void>;
  /** Retries the load after an error. Same implementation as [load]. */
  retry(): Promise<void>;
}

/**
 * The category-list load state machine — the React analog of the Flutter
 * `AddressProvider` load half (react-guidelines §Hook Lifecycle). Mirrors
 * `useBrandList` (Task 04) verbatim for the category domain.
 *
 * It owns its own state (`useState`) and re-reads on every mount — it caches
 * nothing across mounts, and the server is always the source of truth. It
 * performs no navigation and touches no storage.
 */
export function useCategoryList(repository: CategoryRepository): UseCategoryListResult {
  const [status, setStatus] = useState<CategoryListStatus>('loading');
  const [categories, setCategories] = useState<readonly CategoryResponse[]>([]);
  const [error, setError] = useState<AppError | null>(null);

  const load = useCallback(async (): Promise<void> => {
    setStatus('loading');
    setError(null);
    try {
      const result = await repository.list();
      setCategories(result);
      setStatus('ready');
    } catch (caught) {
      setError(caught instanceof AppError ? caught : new AppError({ message: UNEXPECTED_MESSAGE }));
      setStatus('error');
    }
  }, [repository]);

  return { status, categories, error, load, retry: load };
}
