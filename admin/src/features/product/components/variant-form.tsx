import {
  Button,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  MenuItem,
  Stack,
  TextField,
} from '@mui/material';
import type { FormEvent, ReactElement, RefObject } from 'react';

import type { ProductVariantStatus } from '../models/product-variant-status';

export interface VariantFormValues {
  readonly color: string;
  readonly size: string;
  readonly sku: string;
  readonly stockQuantity: string;
  readonly status: ProductVariantStatus;
  readonly priceOverride: string;
  readonly costPrice: string;
}

export interface VariantFormErrors {
  readonly color?: string;
  readonly size?: string;
  readonly sku?: string;
  readonly stockQuantity?: string;
  readonly priceOverride?: string;
  readonly costPrice?: string;
}

interface VariantFormProps {
  readonly open: boolean;
  readonly title: string;
  readonly values: VariantFormValues;
  readonly errors: VariantFormErrors;
  /** True while the mutation is in flight (disables every field and action). */
  readonly disabled: boolean;
  readonly submitLabel: string;
  readonly colorInputRef: RefObject<HTMLInputElement>;
  readonly sizeInputRef: RefObject<HTMLInputElement>;
  readonly skuInputRef: RefObject<HTMLInputElement>;
  readonly stockQuantityInputRef: RefObject<HTMLInputElement>;
  readonly priceOverrideInputRef: RefObject<HTMLInputElement>;
  readonly costPriceInputRef: RefObject<HTMLInputElement>;
  onFieldChange(field: keyof VariantFormValues, value: string): void;
  onSubmit(event: FormEvent<HTMLFormElement>): void;
  onCancel(): void;
}

/**
 * The create / edit variant dialog — presentational and controlled
 * (react-guidelines §Component Rules), the feature-local counterpart of
 * `BrandForm` for a product's variants. There is no delete affordance
 * (the frozen contract has none); a variant is retired by editing its
 * `status` to `INACTIVE`. `costPrice` is the ADMIN-only field added in
 * Sprint 11 — required alongside every other write field.
 */
export function VariantForm({
  open,
  title,
  values,
  errors,
  disabled,
  submitLabel,
  colorInputRef,
  sizeInputRef,
  skuInputRef,
  stockQuantityInputRef,
  priceOverrideInputRef,
  costPriceInputRef,
  onFieldChange,
  onSubmit,
  onCancel,
}: VariantFormProps): ReactElement {
  return (
    <Dialog open={open} onClose={disabled ? undefined : onCancel} fullWidth maxWidth="sm">
      <form noValidate onSubmit={onSubmit}>
        <DialogTitle>{title}</DialogTitle>
        <DialogContent>
          <Stack spacing={2} sx={{ mt: 1 }}>
            <TextField
              label="Color"
              value={values.color}
              onChange={(event) => onFieldChange('color', event.target.value)}
              error={errors.color !== undefined}
              helperText={errors.color}
              inputRef={colorInputRef}
              disabled={disabled}
              fullWidth
            />
            <TextField
              label="Size"
              value={values.size}
              onChange={(event) => onFieldChange('size', event.target.value)}
              error={errors.size !== undefined}
              helperText={errors.size}
              inputRef={sizeInputRef}
              disabled={disabled}
              fullWidth
            />
            <TextField
              label="SKU"
              value={values.sku}
              onChange={(event) => onFieldChange('sku', event.target.value)}
              error={errors.sku !== undefined}
              helperText={errors.sku}
              inputRef={skuInputRef}
              disabled={disabled}
              fullWidth
            />
            <TextField
              label="Stock Quantity"
              type="number"
              value={values.stockQuantity}
              onChange={(event) => onFieldChange('stockQuantity', event.target.value)}
              error={errors.stockQuantity !== undefined}
              helperText={errors.stockQuantity}
              inputRef={stockQuantityInputRef}
              disabled={disabled}
              fullWidth
            />
            <TextField
              select
              label="Status"
              value={values.status}
              onChange={(event) => onFieldChange('status', event.target.value)}
              disabled={disabled}
              fullWidth
            >
              <MenuItem value="ACTIVE">ACTIVE</MenuItem>
              <MenuItem value="INACTIVE">INACTIVE</MenuItem>
            </TextField>
            <TextField
              label="Price Override (optional)"
              type="number"
              value={values.priceOverride}
              onChange={(event) => onFieldChange('priceOverride', event.target.value)}
              error={errors.priceOverride !== undefined}
              helperText={errors.priceOverride}
              inputRef={priceOverrideInputRef}
              disabled={disabled}
              fullWidth
            />
            <TextField
              label="Cost Price"
              type="number"
              value={values.costPrice}
              onChange={(event) => onFieldChange('costPrice', event.target.value)}
              error={errors.costPrice !== undefined}
              helperText={errors.costPrice}
              inputRef={costPriceInputRef}
              disabled={disabled}
              fullWidth
            />
          </Stack>
        </DialogContent>
        <DialogActions>
          <Button onClick={onCancel} disabled={disabled}>
            Cancel
          </Button>
          <Button type="submit" variant="contained" disabled={disabled}>
            {submitLabel}
          </Button>
        </DialogActions>
      </form>
    </Dialog>
  );
}
