import { useCallback, useState } from 'react';

import { AppError } from '@/core/error/app-error';

import type { BrandResponse } from '../models/brand-response';
import type { BrandRepository } from '../repositories/brand-repository';

const UNEXPECTED_MESSAGE = 'An unexpected error occurred';

export type BrandListStatus = 'loading' | 'ready' | 'error';

export interface UseBrandListResult {
  readonly status: BrandListStatus;
  readonly brands: readonly BrandResponse[];
  readonly error: AppError | null;
  /** Loads the brand list (called once on page mount). */
  load(): Promise<void>;
  /** Retries the load after an error. Same implementation as [load]. */
  retry(): Promise<void>;
}

/**
 * The brand-list load state machine — the React analog of the Flutter
 * `AddressProvider` load half (react-guidelines §Hook Lifecycle).
 *
 * It owns its own state (`useState`) and re-reads on every mount — it caches
 * nothing across mounts, and the server is always the source of truth. It
 * performs no navigation and touches no storage.
 */
export function useBrandList(repository: BrandRepository): UseBrandListResult {
  const [status, setStatus] = useState<BrandListStatus>('loading');
  const [brands, setBrands] = useState<readonly BrandResponse[]>([]);
  const [error, setError] = useState<AppError | null>(null);

  const load = useCallback(async (): Promise<void> => {
    setStatus('loading');
    setError(null);
    try {
      const result = await repository.list();
      setBrands(result);
      setStatus('ready');
    } catch (caught) {
      setError(caught instanceof AppError ? caught : new AppError({ message: UNEXPECTED_MESSAGE }));
      setStatus('error');
    }
  }, [repository]);

  return { status, brands, error, load, retry: load };
}
