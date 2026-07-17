import { Box, Snackbar, Typography } from '@mui/material';
import { useCallback, useRef, useState, type FormEvent, type ReactElement } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';

import { AppError } from '@/core/error/app-error';
import { ROUTES } from '@/core/router/routes';

import {
  CategoryForm,
  type CategoryFormErrors,
  type CategoryFormValues,
} from '../components/category-form';
import { useCategoryMutation } from '../hooks/use-category-mutation';
import type { CategoryResponse } from '../models/category-response';
import type { CategoryRepository } from '../repositories/category-repository';
import { categoryValidators } from '../validators/category-validators';

const UNEXPECTED_MESSAGE = 'An unexpected error occurred';

interface CategoryFormPageProps {
  readonly repository: CategoryRepository;
}

interface NavigationState {
  readonly category?: CategoryResponse;
}

function toValues(category: CategoryResponse | null): CategoryFormValues {
  return {
    name: category?.name ?? '',
    description: category?.description ?? '',
  };
}

/**
 * The create / edit category screen — the React analog of the Flutter
 * `AddressFormScreen` (sprint-10-plan Task 05). Mirrors `BrandFormPage`
 * (Task 04) verbatim for the category domain. Edit mode is carried via router
 * `state` (the `go_router` `extra` analog), never a URL parameter — a fresh
 * visit with no state is create mode, matching the Flutter precedent exactly.
 *
 * On success it navigates back to [ROUTES.categories] with a success message
 * in `state`; the list page remounts fresh there and re-fetches on mount,
 * which *is* the "reload the list from the server" this task requires — no
 * explicit cross-hook reload wiring is needed for create / edit.
 */
export function CategoryFormPage({ repository }: CategoryFormPageProps): ReactElement {
  const location = useLocation();
  const navigate = useNavigate();
  const editingCategory = (location.state as NavigationState | null)?.category ?? null;

  const reload = useCallback((): Promise<void> => {
    navigate(ROUTES.categories, {
      state: { successMessage: editingCategory !== null ? 'Category updated' : 'Category created' },
    });
    return Promise.resolve();
  }, [navigate, editingCategory]);

  const mutation = useCategoryMutation(repository, reload);

  const [values, setValues] = useState<CategoryFormValues>(() => toValues(editingCategory));
  const [errors, setErrors] = useState<CategoryFormErrors>({});
  const [errorMessage, setErrorMessage] = useState<string>();
  const nameInputRef = useRef<HTMLInputElement>(null);
  const descriptionInputRef = useRef<HTMLInputElement>(null);

  function handleFieldChange(field: keyof CategoryFormValues, value: string): void {
    setValues((prev) => ({ ...prev, [field]: value }));
  }

  async function handleSubmit(event: FormEvent<HTMLFormElement>): Promise<void> {
    event.preventDefault();
    const nameError = categoryValidators.name(values.name);
    const descriptionError = categoryValidators.description(values.description);
    setErrors({ name: nameError, description: descriptionError });
    if (nameError !== undefined) {
      nameInputRef.current?.focus();
      return;
    }
    if (descriptionError !== undefined) {
      descriptionInputRef.current?.focus();
      return;
    }

    const request = {
      name: values.name.trim(),
      description: values.description.trim().length > 0 ? values.description.trim() : undefined,
    };
    try {
      if (editingCategory !== null) {
        await mutation.update(editingCategory.id, request);
      } else {
        await mutation.create(request);
      }
    } catch (error) {
      setErrorMessage(error instanceof AppError ? error.message : UNEXPECTED_MESSAGE);
    }
  }

  return (
    <Box>
      <Typography variant="h4" component="h1" gutterBottom>
        {editingCategory !== null ? 'Edit category' : 'New category'}
      </Typography>
      <CategoryForm
        values={values}
        errors={errors}
        disabled={mutation.isMutating}
        submitLabel={editingCategory !== null ? 'Save' : 'Create'}
        nameInputRef={nameInputRef}
        descriptionInputRef={descriptionInputRef}
        onFieldChange={handleFieldChange}
        onSubmit={(event) => {
          void handleSubmit(event);
        }}
        onCancel={() => navigate(ROUTES.categories)}
      />
      <Snackbar
        open={errorMessage !== undefined}
        autoHideDuration={6000}
        onClose={() => setErrorMessage(undefined)}
        message={errorMessage}
      />
    </Box>
  );
}
