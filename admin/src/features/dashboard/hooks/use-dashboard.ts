import { useCallback, useRef, useState } from 'react';

import { AppError } from '@/core/error/app-error';

import type { DashboardResponse } from '../models/dashboard-response';
import type { DashboardRepository } from '../repositories/dashboard-repository';

const UNEXPECTED_MESSAGE = 'An unexpected error occurred';

export type DashboardStatus = 'loading' | 'ready' | 'error';

export interface UseDashboardResult {
  readonly status: DashboardStatus;
  readonly data: DashboardResponse | null;
  readonly error: AppError | null;
  /** Loads (or reloads) the dashboard — called once on page mount. */
  load(): Promise<void>;
  /** Retries the load after an error. */
  retry(): Promise<void>;
}

/**
 * The dashboard's single-read load state machine (react-guidelines §Hook
 * Lifecycle; sprint-13-plan Task 03) — the direct analog of
 * `useOrderDetail`'s load half, reduced to the one ADMIN read with no
 * mutation. It owns its own state (`useState`), calls
 * {@link DashboardRepository.get} only, and re-reads on every mount; it
 * caches nothing across mounts and performs no navigation.
 *
 * `load` is **single-flight**: a call while one is already in flight is a
 * no-op, so a duplicate mount effect or a fast double-click on retry cannot
 * issue two concurrent requests. There is no polling and no auto-refresh —
 * the page reloads only on an explicit `retry` call (Design Notes, §Out of
 * Scope).
 */
export function useDashboard(repository: DashboardRepository): UseDashboardResult {
  const [status, setStatus] = useState<DashboardStatus>('loading');
  const [data, setData] = useState<DashboardResponse | null>(null);
  const [error, setError] = useState<AppError | null>(null);
  const inFlight = useRef(false);

  const load = useCallback(async (): Promise<void> => {
    if (inFlight.current) {
      return;
    }
    inFlight.current = true;
    setStatus('loading');
    setError(null);
    try {
      const result = await repository.get();
      setData(result);
      setStatus('ready');
    } catch (caught) {
      setError(caught instanceof AppError ? caught : new AppError({ message: UNEXPECTED_MESSAGE }));
      setStatus('error');
    } finally {
      inFlight.current = false;
    }
  }, [repository]);

  return { status, data, error, load, retry: load };
}
