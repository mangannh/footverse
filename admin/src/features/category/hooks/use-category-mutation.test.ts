import { act, renderHook } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';

import { AppError } from '@/core/error/app-error';

import { useCategoryMutation } from './use-category-mutation';
import type { CategoryResponse } from '../models/category-response';
import type { CategoryRepository } from '../repositories/category-repository';

const category: CategoryResponse = { id: 1, name: 'Running Shoes' };

function fakeRepository(overrides: Partial<CategoryRepository>): CategoryRepository {
  return overrides as unknown as CategoryRepository;
}

describe('useCategoryMutation', () => {
  it('create succeeds and reloads the list from the server', async () => {
    const repository = fakeRepository({ create: vi.fn().mockResolvedValue(category) });
    const reload = vi.fn().mockResolvedValue(undefined);
    const { result } = renderHook(() => useCategoryMutation(repository, reload));

    await act(async () => {
      await result.current.create({ name: 'Running Shoes' });
    });

    expect(repository.create).toHaveBeenCalledWith({ name: 'Running Shoes' });
    expect(reload).toHaveBeenCalledTimes(1);
    expect(result.current.isMutating).toBe(false);
  });

  it('update succeeds and reloads the list from the server', async () => {
    const repository = fakeRepository({ update: vi.fn().mockResolvedValue(category) });
    const reload = vi.fn().mockResolvedValue(undefined);
    const { result } = renderHook(() => useCategoryMutation(repository, reload));

    await act(async () => {
      await result.current.update(1, { name: 'Running Shoes' });
    });

    expect(repository.update).toHaveBeenCalledWith(1, { name: 'Running Shoes' });
    expect(reload).toHaveBeenCalledTimes(1);
  });

  it('remove succeeds and reloads the list from the server', async () => {
    const repository = fakeRepository({ remove: vi.fn().mockResolvedValue(undefined) });
    const reload = vi.fn().mockResolvedValue(undefined);
    const { result } = renderHook(() => useCategoryMutation(repository, reload));

    await act(async () => {
      await result.current.remove(1);
    });

    expect(repository.remove).toHaveBeenCalledWith(1);
    expect(reload).toHaveBeenCalledTimes(1);
  });

  it('rethrows a duplicate-name AppError and does not reload', async () => {
    const duplicateError = new AppError({
      message: 'Category name already exists',
      statusCode: 409,
      errorCode: 'CATEGORY_NAME_DUPLICATED',
    });
    const repository = fakeRepository({ create: vi.fn().mockRejectedValue(duplicateError) });
    const reload = vi.fn().mockResolvedValue(undefined);
    const { result } = renderHook(() => useCategoryMutation(repository, reload));

    await act(async () => {
      await expect(result.current.create({ name: 'Running Shoes' })).rejects.toBe(duplicateError);
    });

    expect(reload).not.toHaveBeenCalled();
    expect(result.current.isMutating).toBe(false);
  });

  it('rethrows an in-use AppError on remove and does not reload', async () => {
    const inUseError = new AppError({
      message: 'Category is still referenced by products',
      statusCode: 409,
      errorCode: 'CATEGORY_IN_USE',
    });
    const repository = fakeRepository({ remove: vi.fn().mockRejectedValue(inUseError) });
    const reload = vi.fn().mockResolvedValue(undefined);
    const { result } = renderHook(() => useCategoryMutation(repository, reload));

    await act(async () => {
      await expect(result.current.remove(1)).rejects.toBe(inUseError);
    });

    expect(reload).not.toHaveBeenCalled();
  });

  it('rethrows a not-found AppError on update and does not reload', async () => {
    const notFoundError = new AppError({
      message: 'Category not found',
      statusCode: 404,
      errorCode: 'CATEGORY_NOT_FOUND',
    });
    const repository = fakeRepository({ update: vi.fn().mockRejectedValue(notFoundError) });
    const reload = vi.fn().mockResolvedValue(undefined);
    const { result } = renderHook(() => useCategoryMutation(repository, reload));

    await act(async () => {
      await expect(result.current.update(999, { name: 'Running Shoes' })).rejects.toBe(
        notFoundError,
      );
    });

    expect(reload).not.toHaveBeenCalled();
  });

  it('is single-flight: a concurrent create is ignored', async () => {
    let resolveCreate: (value: CategoryResponse) => void = () => undefined;
    const create = vi.fn().mockImplementation(
      () =>
        new Promise<CategoryResponse>((resolve) => {
          resolveCreate = resolve;
        }),
    );
    const repository = fakeRepository({ create });
    const reload = vi.fn().mockResolvedValue(undefined);
    const { result } = renderHook(() => useCategoryMutation(repository, reload));

    await act(async () => {
      const first = result.current.create({ name: 'Running Shoes' });
      const second = result.current.create({ name: 'Running Shoes' });
      resolveCreate(category);
      await Promise.all([first, second]);
    });

    expect(create).toHaveBeenCalledTimes(1);
    expect(reload).toHaveBeenCalledTimes(1);
  });
});
