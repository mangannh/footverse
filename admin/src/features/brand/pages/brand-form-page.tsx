import { Box, Snackbar, Typography } from '@mui/material';
import { useCallback, useRef, useState, type FormEvent, type ReactElement } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';

import { AppError } from '@/core/error/app-error';
import { ROUTES } from '@/core/router/routes';

import { BrandForm, type BrandFormErrors, type BrandFormValues } from '../components/brand-form';
import { useBrandMutation } from '../hooks/use-brand-mutation';
import type { BrandResponse } from '../models/brand-response';
import type { BrandRepository } from '../repositories/brand-repository';
import { brandValidators } from '../validators/brand-validators';

const UNEXPECTED_MESSAGE = 'An unexpected error occurred';

interface BrandFormPageProps {
  readonly repository: BrandRepository;
}

interface NavigationState {
  readonly brand?: BrandResponse;
}

function toValues(brand: BrandResponse | null): BrandFormValues {
  return {
    name: brand?.name ?? '',
    logoUrl: brand?.logoUrl ?? '',
    description: brand?.description ?? '',
  };
}

/**
 * The create / edit brand screen — the React analog of the Flutter
 * `AddressFormScreen` (sprint-10-plan Task 04). Edit mode is carried via router
 * `state` (the `go_router` `extra` analog), never a URL parameter — a fresh
 * visit with no state is create mode, matching the Flutter precedent exactly.
 *
 * On success it navigates back to [ROUTES.brands] with a success message in
 * `state`; the list page remounts fresh there and re-fetches on mount, which
 * *is* the "reload the list from the server" this task requires — no explicit
 * cross-hook reload wiring is needed for create / edit.
 */
export function BrandFormPage({ repository }: BrandFormPageProps): ReactElement {
  const location = useLocation();
  const navigate = useNavigate();
  const editingBrand = (location.state as NavigationState | null)?.brand ?? null;

  const reload = useCallback((): Promise<void> => {
    navigate(ROUTES.brands, {
      state: { successMessage: editingBrand !== null ? 'Brand updated' : 'Brand created' },
    });
    return Promise.resolve();
  }, [navigate, editingBrand]);

  const mutation = useBrandMutation(repository, reload);

  const [values, setValues] = useState<BrandFormValues>(() => toValues(editingBrand));
  const [errors, setErrors] = useState<BrandFormErrors>({});
  const [errorMessage, setErrorMessage] = useState<string>();
  const nameInputRef = useRef<HTMLInputElement>(null);
  const logoUrlInputRef = useRef<HTMLInputElement>(null);
  const descriptionInputRef = useRef<HTMLInputElement>(null);

  function handleFieldChange(field: keyof BrandFormValues, value: string): void {
    setValues((prev) => ({ ...prev, [field]: value }));
  }

  async function handleSubmit(event: FormEvent<HTMLFormElement>): Promise<void> {
    event.preventDefault();
    const nameError = brandValidators.name(values.name);
    const logoUrlError = brandValidators.logoUrl(values.logoUrl);
    const descriptionError = brandValidators.description(values.description);
    setErrors({ name: nameError, logoUrl: logoUrlError, description: descriptionError });
    if (nameError !== undefined) {
      nameInputRef.current?.focus();
      return;
    }
    if (logoUrlError !== undefined) {
      logoUrlInputRef.current?.focus();
      return;
    }
    if (descriptionError !== undefined) {
      descriptionInputRef.current?.focus();
      return;
    }

    const request = {
      name: values.name.trim(),
      logoUrl: values.logoUrl.trim().length > 0 ? values.logoUrl.trim() : undefined,
      description: values.description.trim().length > 0 ? values.description.trim() : undefined,
    };
    try {
      if (editingBrand !== null) {
        await mutation.update(editingBrand.id, request);
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
        {editingBrand !== null ? 'Edit brand' : 'New brand'}
      </Typography>
      <BrandForm
        values={values}
        errors={errors}
        disabled={mutation.isMutating}
        submitLabel={editingBrand !== null ? 'Save' : 'Create'}
        nameInputRef={nameInputRef}
        logoUrlInputRef={logoUrlInputRef}
        descriptionInputRef={descriptionInputRef}
        onFieldChange={handleFieldChange}
        onSubmit={(event) => {
          void handleSubmit(event);
        }}
        onCancel={() => navigate(ROUTES.brands)}
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
