import { useCallback, useRef, useState } from 'react';

import type { CreateProductImageRequest } from '../models/create-product-image-request';
import type { CreateProductRequest } from '../models/create-product-request';
import type { CreateProductVariantRequest } from '../models/create-product-variant-request';
import type { UpdateProductImageRequest } from '../models/update-product-image-request';
import type { UpdateProductRequest } from '../models/update-product-request';
import type { UpdateProductVariantRequest } from '../models/update-product-variant-request';
import type { ProductRepository } from '../repositories/product-repository';

export interface UseProductMutationResult {
  /** True while a mutation is in flight. */
  readonly isMutating: boolean;
  create(request: CreateProductRequest): Promise<void>;
  update(id: number, request: UpdateProductRequest): Promise<void>;
  remove(id: number): Promise<void>;
  createVariant(id: number, request: CreateProductVariantRequest): Promise<void>;
  updateVariant(id: number, variantId: number, request: UpdateProductVariantRequest): Promise<void>;
  createImage(id: number, request: CreateProductImageRequest): Promise<void>;
  updateImage(id: number, imageId: number, request: UpdateProductImageRequest): Promise<void>;
}

/**
 * The product/variant/image mutation actions — the React analog of the
 * Flutter provider mutation half (react-guidelines §Async / Mutation Rules),
 * mirroring `useBrandMutation` (Sprint 10) verbatim, extended for the
 * aggregate (Task 04 adds `create` / `update` / the variant and image
 * actions on top of Task 03's `remove`).
 *
 * Every action is **single-flight** (a concurrent call is a no-op),
 * **rethrows** `AppError` on failure without side effects, and on success
 * invokes the injected [reload] so the server-decided state is re-read — the
 * Flutter reload-after-mutation precedent, wired via a callback (never a call
 * into another hook, so this hook never references `useProductList`). The
 * caller decides what [reload] means: the list page reloads the current page
 * (Task 03); the form page re-fetches the product detail (Task 04) or
 * navigates back to the list, depending on which action it wires.
 */
export function useProductMutation(
  repository: ProductRepository,
  reload: () => Promise<void>,
): UseProductMutationResult {
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
    (request: CreateProductRequest) => run(() => repository.create(request)),
    [run, repository],
  );
  const update = useCallback(
    (id: number, request: UpdateProductRequest) => run(() => repository.update(id, request)),
    [run, repository],
  );
  const remove = useCallback((id: number) => run(() => repository.remove(id)), [run, repository]);
  const createVariant = useCallback(
    (id: number, request: CreateProductVariantRequest) =>
      run(() => repository.createVariant(id, request)),
    [run, repository],
  );
  const updateVariant = useCallback(
    (id: number, variantId: number, request: UpdateProductVariantRequest) =>
      run(() => repository.updateVariant(id, variantId, request)),
    [run, repository],
  );
  const createImage = useCallback(
    (id: number, request: CreateProductImageRequest) =>
      run(() => repository.createImage(id, request)),
    [run, repository],
  );
  const updateImage = useCallback(
    (id: number, imageId: number, request: UpdateProductImageRequest) =>
      run(() => repository.updateImage(id, imageId, request)),
    [run, repository],
  );

  return {
    isMutating,
    create,
    update,
    remove,
    createVariant,
    updateVariant,
    createImage,
    updateImage,
  };
}
