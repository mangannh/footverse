import { useCallback, useRef, useState } from 'react';

import type { CreateBrandRequest } from '../models/create-brand-request';
import type { UpdateBrandRequest } from '../models/update-brand-request';
import type { BrandRepository } from '../repositories/brand-repository';

export interface UseBrandMutationResult {
  /** True while a create / update / remove is in flight. */
  readonly isMutating: boolean;
  create(request: CreateBrandRequest): Promise<void>;
  update(id: number, request: UpdateBrandRequest): Promise<void>;
  remove(id: number): Promise<void>;
}

/**
 * The brand create / update / remove mutation actions — the React analog of the
 * Flutter `AddressProvider` mutation half (react-guidelines §Async / Mutation
 * Rules).
 *
 * Each action is **single-flight** (a concurrent call is a no-op), **rethrows**
 * `AppError` on failure without side effects, and on success invokes the
 * injected [reload] so the server-decided list is re-read — the Flutter
 * reload-after-mutation precedent, wired via a callback (the Sprint 9
 * `onReviewsChanged` precedent) rather than a call into another hook, so this
 * hook never references `useBrandList`.
 */
export function useBrandMutation(
  repository: BrandRepository,
  reload: () => Promise<void>,
): UseBrandMutationResult {
  const [isMutating, setIsMutating] = useState(false);
  const inFlight = useRef(false);

  const run = useCallback(
    async (action: () => Promise<unknown>): Promise<void> => {
      if (inFlight.current) {
        return;
      }
      inFlight.current = true;
      setIsMutating(true);
      try {
        await action();
        await reload();
      } finally {
        inFlight.current = false;
        setIsMutating(false);
      }
    },
    [reload],
  );

  const create = useCallback(
    (request: CreateBrandRequest) => run(() => repository.create(request)),
    [run, repository],
  );
  const update = useCallback(
    (id: number, request: UpdateBrandRequest) => run(() => repository.update(id, request)),
    [run, repository],
  );
  const remove = useCallback((id: number) => run(() => repository.remove(id)), [run, repository]);

  return { isMutating, create, update, remove };
}
