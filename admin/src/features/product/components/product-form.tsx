import { Button, MenuItem, Stack, TextField } from '@mui/material';
import type { FormEvent, ReactElement, RefObject } from 'react';

import type { BrandResponse } from '@/features/brand/models/brand-response';
import type { CategoryResponse } from '@/features/category/models/category-response';

export interface ProductFormValues {
  readonly name: string;
  readonly description: string;
  readonly basePrice: string;
  readonly categoryId: string;
  readonly brandId: string;
}

export interface ProductFormErrors {
  readonly name?: string;
  readonly description?: string;
  readonly basePrice?: string;
  readonly categoryId?: string;
  readonly brandId?: string;
}

interface ProductFormProps {
  readonly values: ProductFormValues;
  readonly errors: ProductFormErrors;
  /** True while the mutation is in flight (disables every field and action). */
  readonly disabled: boolean;
  readonly submitLabel: string;
  readonly categories: readonly CategoryResponse[];
  readonly brands: readonly BrandResponse[];
  readonly nameInputRef: RefObject<HTMLInputElement>;
  readonly descriptionInputRef: RefObject<HTMLInputElement>;
  readonly basePriceInputRef: RefObject<HTMLInputElement>;
  readonly categoryInputRef: RefObject<HTMLInputElement>;
  readonly brandInputRef: RefObject<HTMLInputElement>;
  onFieldChange(field: keyof ProductFormValues, value: string): void;
  onSubmit(event: FormEvent<HTMLFormElement>): void;
  onCancel(): void;
}

/**
 * The product-core form (name / description / basePrice / category / brand)
 * — presentational and controlled (react-guidelines §Component Rules),
 * mirroring `BrandForm` (Sprint 10). Field state, validation, and submission
 * are owned by the page; this component only renders the inputs and reports
 * change / submit / cancel intent upward. Category and brand options are
 * supplied by the page (read from the reused `CategoryRepository` /
 * `BrandRepository`), never fetched here.
 */
export function ProductForm({
  values,
  errors,
  disabled,
  submitLabel,
  categories,
  brands,
  nameInputRef,
  descriptionInputRef,
  basePriceInputRef,
  categoryInputRef,
  brandInputRef,
  onFieldChange,
  onSubmit,
  onCancel,
}: ProductFormProps): ReactElement {
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
        <TextField
          label="Base Price"
          type="number"
          value={values.basePrice}
          onChange={(event) => onFieldChange('basePrice', event.target.value)}
          error={errors.basePrice !== undefined}
          helperText={errors.basePrice}
          inputRef={basePriceInputRef}
          disabled={disabled}
          fullWidth
        />
        <TextField
          select
          label="Category"
          value={values.categoryId}
          onChange={(event) => onFieldChange('categoryId', event.target.value)}
          error={errors.categoryId !== undefined}
          helperText={errors.categoryId}
          inputRef={categoryInputRef}
          disabled={disabled}
          fullWidth
        >
          {categories.map((category) => (
            <MenuItem key={category.id} value={String(category.id)}>
              {category.name}
            </MenuItem>
          ))}
        </TextField>
        <TextField
          select
          label="Brand"
          value={values.brandId}
          onChange={(event) => onFieldChange('brandId', event.target.value)}
          error={errors.brandId !== undefined}
          helperText={errors.brandId}
          inputRef={brandInputRef}
          disabled={disabled}
          fullWidth
        >
          {brands.map((brand) => (
            <MenuItem key={brand.id} value={String(brand.id)}>
              {brand.name}
            </MenuItem>
          ))}
        </TextField>
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
