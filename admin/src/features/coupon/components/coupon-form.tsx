import { Button, Checkbox, FormControlLabel, MenuItem, Stack, TextField } from '@mui/material';
import type { FormEvent, ReactElement, RefObject } from 'react';

import type { DiscountType } from '../models/discount-type';

export interface CouponFormValues {
  readonly code: string;
  readonly name: string;
  readonly description: string;
  readonly discountType: DiscountType;
  readonly discountValue: string;
  readonly minOrderAmount: string;
  readonly maxDiscountAmount: string;
  readonly startAt: string;
  readonly endAt: string;
  readonly usageLimit: string;
  readonly enabled: boolean;
}

export interface CouponFormErrors {
  readonly code?: string;
  readonly name?: string;
  readonly description?: string;
  readonly discountValue?: string;
  readonly minOrderAmount?: string;
  readonly maxDiscountAmount?: string;
  readonly startAt?: string;
  readonly endAt?: string;
  readonly usageLimit?: string;
}

type CouponFormTextField = Exclude<keyof CouponFormValues, 'discountType' | 'enabled'>;

interface CouponFormProps {
  readonly values: CouponFormValues;
  readonly errors: CouponFormErrors;
  /** True while the mutation is in flight (disables every field and action). */
  readonly disabled: boolean;
  readonly submitLabel: string;
  readonly codeInputRef: RefObject<HTMLInputElement>;
  readonly nameInputRef: RefObject<HTMLInputElement>;
  readonly descriptionInputRef: RefObject<HTMLInputElement>;
  readonly discountValueInputRef: RefObject<HTMLInputElement>;
  readonly minOrderAmountInputRef: RefObject<HTMLInputElement>;
  readonly maxDiscountAmountInputRef: RefObject<HTMLInputElement>;
  readonly startAtInputRef: RefObject<HTMLInputElement>;
  readonly endAtInputRef: RefObject<HTMLInputElement>;
  readonly usageLimitInputRef: RefObject<HTMLInputElement>;
  onFieldChange(field: CouponFormTextField, value: string): void;
  onDiscountTypeChange(discountType: DiscountType): void;
  onEnabledChange(enabled: boolean): void;
  onSubmit(event: FormEvent<HTMLFormElement>): void;
  onCancel(): void;
}

/**
 * The create / edit coupon form — presentational and controlled
 * (react-guidelines §Component Rules), mirroring `BrandForm` (Sprint 10).
 * Field state, validation, and submission are owned by the page; this
 * component only renders the inputs (`code`, `name`, `description`,
 * `discountType`, `discountValue`, `minOrderAmount`, `maxDiscountAmount`,
 * `startAt`, `endAt`, `usageLimit`, `enabled`) and reports change / submit /
 * cancel intent upward. `id` and `usedCount` are server-managed and are
 * never rendered here (`usedCount` is list-only).
 */
export function CouponForm({
  values,
  errors,
  disabled,
  submitLabel,
  codeInputRef,
  nameInputRef,
  descriptionInputRef,
  discountValueInputRef,
  minOrderAmountInputRef,
  maxDiscountAmountInputRef,
  startAtInputRef,
  endAtInputRef,
  usageLimitInputRef,
  onFieldChange,
  onDiscountTypeChange,
  onEnabledChange,
  onSubmit,
  onCancel,
}: CouponFormProps): ReactElement {
  return (
    <form noValidate onSubmit={onSubmit}>
      <Stack spacing={3} sx={{ maxWidth: 480 }}>
        <TextField
          label="Code"
          value={values.code}
          onChange={(event) => onFieldChange('code', event.target.value)}
          error={errors.code !== undefined}
          helperText={errors.code}
          inputRef={codeInputRef}
          disabled={disabled}
          fullWidth
        />
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
          select
          label="Discount Type"
          value={values.discountType}
          onChange={(event) => onDiscountTypeChange(event.target.value as DiscountType)}
          disabled={disabled}
          fullWidth
        >
          <MenuItem value="PERCENT">PERCENT</MenuItem>
          <MenuItem value="FIXED">FIXED</MenuItem>
        </TextField>
        <TextField
          label="Discount Value"
          type="number"
          value={values.discountValue}
          onChange={(event) => onFieldChange('discountValue', event.target.value)}
          error={errors.discountValue !== undefined}
          helperText={errors.discountValue}
          inputRef={discountValueInputRef}
          disabled={disabled}
          fullWidth
        />
        <TextField
          label="Minimum Order Amount"
          type="number"
          value={values.minOrderAmount}
          onChange={(event) => onFieldChange('minOrderAmount', event.target.value)}
          error={errors.minOrderAmount !== undefined}
          helperText={errors.minOrderAmount}
          inputRef={minOrderAmountInputRef}
          disabled={disabled}
          fullWidth
        />
        <TextField
          label="Maximum Discount Amount (optional)"
          type="number"
          value={values.maxDiscountAmount}
          onChange={(event) => onFieldChange('maxDiscountAmount', event.target.value)}
          error={errors.maxDiscountAmount !== undefined}
          helperText={errors.maxDiscountAmount}
          inputRef={maxDiscountAmountInputRef}
          disabled={disabled}
          fullWidth
        />
        <TextField
          label="Start Date"
          type="datetime-local"
          value={values.startAt}
          onChange={(event) => onFieldChange('startAt', event.target.value)}
          error={errors.startAt !== undefined}
          helperText={errors.startAt}
          inputRef={startAtInputRef}
          disabled={disabled}
          InputLabelProps={{ shrink: true }}
          fullWidth
        />
        <TextField
          label="End Date"
          type="datetime-local"
          value={values.endAt}
          onChange={(event) => onFieldChange('endAt', event.target.value)}
          error={errors.endAt !== undefined}
          helperText={errors.endAt}
          inputRef={endAtInputRef}
          disabled={disabled}
          InputLabelProps={{ shrink: true }}
          fullWidth
        />
        <TextField
          label="Usage Limit (optional)"
          type="number"
          value={values.usageLimit}
          onChange={(event) => onFieldChange('usageLimit', event.target.value)}
          error={errors.usageLimit !== undefined}
          helperText={errors.usageLimit}
          inputRef={usageLimitInputRef}
          disabled={disabled}
          fullWidth
        />
        <FormControlLabel
          control={
            <Checkbox
              checked={values.enabled}
              onChange={(event) => onEnabledChange(event.target.checked)}
              disabled={disabled}
            />
          }
          label="Enabled"
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
