import { Button, Stack, TextField } from '@mui/material';
import type { FormEvent, ReactElement, RefObject } from 'react';

export interface CategoryFormValues {
  readonly name: string;
  readonly description: string;
}

export interface CategoryFormErrors {
  readonly name?: string;
  readonly description?: string;
}

interface CategoryFormProps {
  readonly values: CategoryFormValues;
  readonly errors: CategoryFormErrors;
  /** True while the mutation is in flight (disables every field and action). */
  readonly disabled: boolean;
  readonly submitLabel: string;
  readonly nameInputRef: RefObject<HTMLInputElement>;
  readonly descriptionInputRef: RefObject<HTMLInputElement>;
  onFieldChange(field: keyof CategoryFormValues, value: string): void;
  onSubmit(event: FormEvent<HTMLFormElement>): void;
  onCancel(): void;
}

/**
 * The create / edit category form — presentational and controlled
 * (react-guidelines §Component Rules). Mirrors `BrandForm` (Task 04) verbatim,
 * minus the `logoUrl` field (category has no `logoUrl`). Field state,
 * validation, and submission are owned by the page; this component only
 * renders the inputs and reports change / submit / cancel intent upward.
 */
export function CategoryForm({
  values,
  errors,
  disabled,
  submitLabel,
  nameInputRef,
  descriptionInputRef,
  onFieldChange,
  onSubmit,
  onCancel,
}: CategoryFormProps): ReactElement {
  return (
    <form noValidate onSubmit={onSubmit}>
      <Stack spacing={3} sx={{ maxWidth: 480 }}>
        <TextField
          label="Name"
          value={values.name}
          onChange={(event) => onFieldChange('name', event.target.value)}
          error={errors.name !== undefined}
          helperText={errors.name}
          inputRef={nameInputRef}
          disabled={disabled}
          fullWidth
        />
        <TextField
          label="Description"
          value={values.description}
          onChange={(event) => onFieldChange('description', event.target.value)}
          error={errors.description !== undefined}
          helperText={errors.description}
          inputRef={descriptionInputRef}
          disabled={disabled}
          multiline
          minRows={3}
          fullWidth
        />
        <Stack direction="row" spacing={2}>
          <Button type="submit" variant="contained" disabled={disabled}>
            {submitLabel}
          </Button>
          <Button onClick={onCancel} disabled={disabled}>
            Cancel
          </Button>
        </Stack>
      </Stack>
    </form>
  );
}
