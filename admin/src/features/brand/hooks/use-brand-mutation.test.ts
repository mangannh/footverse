import { act, renderHook } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';

import { AppError } from '@/core/error/app-error';

import { useBrandMutation } from './use-brand-mutation';
import type { BrandResponse } from '../models/brand-response';
import type { BrandRepository } from '../repositories/brand-repository';

const brand: BrandResponse = { id: 1, name: 'Nike' };

function fakeRepository(overrides: Partial<BrandRepository>): BrandRepository {
  return overrides as unknown as BrandRepository;
}

describe('useBrandMutation', () => {
  it('create succeeds and reloads the list from the server', async () => {
    const repository = fakeRepository({ create: vi.fn().mockResolvedValue(brand) });
    const reload = vi.fn().mockResolvedValue(undefined);
    const { result } = renderHook(() => useBrandMutation(repository, reload));

    await act(async () => {
      await result.current.create({ name: 'Nike' });
    });

    expect(repository.create).toHaveBeenCalledWith({ name: 'Nike' });
    expect(reload).toHaveBeenCalledTimes(1);
    expect(result.current.isMutating).toBe(false);
  });

  it('update succeeds and reloads the list from the server', async () => {
    const repository = fakeRepository({ update: vi.fn().mockResolvedValue(brand) });
    const reload = vi.fn().mockResolvedValue(undefined);
    const { result } = renderHook(() => useBrandMutation(repository, reload));

    await act(async () => {
      await result.current.update(1, { name: 'Nike' });
    });

    expect(repository.update).toHaveBeenCalledWith(1, { name: 'Nike' });
    expect(reload).toHaveBeenCalledTimes(1);
  });

  it('remove succeeds and reloads the list from the server', async () => {
    const repository = fakeRepository({ remove: vi.fn().mockResolvedValue(undefined) });
    const reload = vi.fn().mockResolvedValue(undefined);
    const { result } = renderHook(() => useBrandMutation(repository, reload));

    await act(async () => {
      await result.current.remove(1);
    });

    expect(repository.remove).toHaveBeenCalledWith(1);
    expect(reload).toHaveBeenCalledTimes(1);
  });

  it('rethrows a duplicate-name AppError and does not reload', async () => {
    const duplicateError = new AppError({
      message: 'Brand name already exists',
      statusCode: 409,
      errorCode: 'BRAND_NAME_DUPLICATED',
    });
    const repository = fakeRepository({ create: vi.fn().mockRejectedValue(duplicateError) });
    const reload = vi.fn().mockResolvedValue(undefined);
    const { result } = renderHook(() => useBrandMutation(repository, reload));

    await act(async () => {
      await expect(result.current.create({ name: 'Nike' })).rejects.toBe(duplicateError);
    });

    expect(reload).not.toHaveBeenCalled();
    expect(result.current.isMutating).toBe(false);
  });

  it('rethrows an in-use AppError on remove and does not reload', async () => {
    const inUseError = new AppError({
      message: 'Brand is still referenced by products',
      statusCode: 409,
      errorCode: 'BRAND_IN_USE',
    });
    const repository = fakeRepository({ remove: vi.fn().mockRejectedValue(inUseError) });
    const reload = vi.fn().mockResolvedValue(undefined);
    const { result } = renderHook(() => useBrandMutation(repository, reload));

    await act(async () => {
      await expect(result.current.remove(1)).rejects.toBe(inUseError);
    });

    expect(reload).not.toHaveBeenCalled();
  });

  it('is single-flight: a concurrent create is ignored', async () => {
    let resolveCreate: (value: BrandResponse) => void = () => undefined;
    const create = vi.fn().mockImplementation(
      () =>
        new Promise<BrandResponse>((resolve) => {
          resolveCreate = resolve;
        }),
    );
    const repository = fakeRepository({ create });
    const reload = vi.fn().mockResolvedValue(undefined);
    const { result } = renderHook(() => useBrandMutation(repository, reload));

    await act(async () => {
      const first = result.current.create({ name: 'Nike' });
      const second = result.current.create({ name: 'Nike' });
      resolveCreate(brand);
      await Promise.all([first, second]);
    });

    expect(create).toHaveBeenCalledTimes(1);
    expect(reload).toHaveBeenCalledTimes(1);
  });
});
