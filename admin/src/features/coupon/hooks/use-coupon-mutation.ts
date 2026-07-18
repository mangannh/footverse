import { useCallback, useRef, useState } from 'react';

import type { CreateCouponRequest } from '../models/create-coupon-request';
import type { UpdateCouponRequest } from '../models/update-coupon-request';
import type { CouponRepository } from '../repositories/coupon-repository';

export interface UseCouponMutationResult {
  /** True while a create / update is in flight. */
  readonly isMutating: boolean;
  create(request: CreateCouponRequest): Promise<void>;
  update(id: number, request: UpdateCouponRequest): Promise<void>;
}

/**
 * The coupon create / update mutation actions — the React analog of the
 * Flutter provider mutation half (react-guidelines §Async / Mutation Rules).
 * Mirrors `useBrandMutation` (Sprint 10) verbatim; coupons have no delete
 * (Assumption 3), so only `create` / `update` exist.
 *
 * Each action is **single-flight** (a concurrent call is a no-op), **rethrows**
 * `AppError` on failure without side effects — including `COUPON_CODE_DUPLICATED`
 * and `COUPON_INVALID_DATE_RANGE`, both server-authoritative and never
 * re-implemented here — and on success invokes the injected [reload] so the
 * server-decided list is re-read — the Flutter reload-after-mutation
 * precedent, wired via a callback (the Sprint 9 `onReviewsChanged` precedent)
 * rather than a call into another hook, so this hook never references
 * `useCouponList`.
 */
export function useCouponMutation(
  repository: CouponRepository,
  reload: () => Promise<void>,
): UseCouponMutationResult {
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
    (request: CreateCouponRequest) => run(() => repository.create(request)),
    [run, repository],
  );
  const update = useCallback(
    (id: number, request: UpdateCouponRequest) => run(() => repository.update(id, request)),
    [run, repository],
  );

  return { isMutating, create, update };
}
