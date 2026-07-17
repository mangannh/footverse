import { useCallback, useRef, useState } from 'react';

import type { CreateCategoryRequest } from '../models/create-category-request';
import type { UpdateCategoryRequest } from '../models/update-category-request';
import type { CategoryRepository } from '../repositories/category-repository';

export interface UseCategoryMutationResult {
  /** True while a create / update / remove is in flight. */
  readonly isMutating: boolean;
  create(request: CreateCategoryRequest): Promise<void>;
  update(id: number, request: UpdateCategoryRequest): Promise<void>;
  remove(id: number): Promise<void>;
}

/**
 * The category create / update / remove mutation actions — the React analog of
 * the Flutter `AddressProvider` mutation half (react-guidelines §Async /
 * Mutation Rules). Mirrors `useBrandMutation` (Task 04) verbatim for the
 * category domain.
 *
 * Each action is **single-flight** (a concurrent call is a no-op), **rethrows**
 * `AppError` on failure without side effects, and on success invokes the
 * injected [reload] so the server-decided list is re-read — the Flutter
 * reload-after-mutation precedent, wired via a callback (the Sprint 9
 * `onReviewsChanged` precedent) rather than a call into another hook, so this
 * hook never references `useCategoryList`.
 */
export function useCategoryMutation(
  repository: CategoryRepository,
  reload: () => Promise<void>,
): UseCategoryMutationResult {
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
    (request: CreateCategoryRequest) => run(() => repository.create(request)),
    [run, repository],
  );
  const update = useCallback(
    (id: number, request: UpdateCategoryRequest) => run(() => repository.update(id, request)),
    [run, repository],
  );
  const remove = useCallback((id: number) => run(() => repository.remove(id)), [run, repository]);

  return { isMutating, create, update, remove };
}
