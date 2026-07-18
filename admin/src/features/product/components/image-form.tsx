import {
  Button,
  Checkbox,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  FormControlLabel,
  Stack,
  TextField,
} from '@mui/material';
import type { FormEvent, ReactElement, RefObject } from 'react';

export interface ImageFormValues {
  readonly imageUrl: string;
  readonly displayOrder: string;
  readonly isPrimary: boolean;
}

export interface ImageFormErrors {
  readonly imageUrl?: string;
  readonly displayOrder?: string;
}

interface ImageFormProps {
  readonly open: boolean;
  readonly title: string;
  readonly values: ImageFormValues;
  readonly errors: ImageFormErrors;
  /** True while the mutation is in flight (disables every field and action). */
  readonly disabled: boolean;
  readonly submitLabel: string;
  readonly imageUrlInputRef: RefObject<HTMLInputElement>;
  readonly displayOrderInputRef: RefObject<HTMLInputElement>;
  onFieldChange(field: 'imageUrl' | 'displayOrder', value: string): void;
  onPrimaryChange(isPrimary: boolean): void;
  onSubmit(event: FormEvent<HTMLFormElement>): void;
  onCancel(): void;
}

/**
 * The create / edit image dialog — presentational and controlled
 * (react-guidelines §Component Rules), the feature-local counterpart of
 * `BrandForm` for a product's images. There is no delete affordance (the
 * frozen contract has none); an image is replaced by editing it. Whether
 * this image ends up primary is decided by the server (the one-primary
 * invariant) — the checkbox only expresses the request's `isPrimary`, the
 * page never recomputes it locally.
 */
export function ImageForm({
  open,
  title,
  values,
  errors,
  disabled,
  submitLabel,
  imageUrlInputRef,
  displayOrderInputRef,
  onFieldChange,
  onPrimaryChange,
  onSubmit,
  onCancel,
}: ImageFormProps): ReactElement {
  return (
    <Dialog open={open} onClose={disabled ? undefined : onCancel} fullWidth maxWidth="sm">
      <form noValidate onSubmit={onSubmit}>
        <DialogTitle>{title}</DialogTitle>
        <DialogContent>
          <Stack spacing={2} sx={{ mt: 1 }}>
            <TextField
              label="Image URL"
              value={values.imageUrl}
              onChange={(event) => onFieldChange('imageUrl', event.target.value)}
              error={errors.imageUrl !== undefined}
              helperText={errors.imageUrl}
              inputRef={imageUrlInputRef}
              disabled={disabled}
              fullWidth
            />
            <TextField
              label="Display Order"
              type="number"
              value={values.displayOrder}
              onChange={(event) => onFieldChange('displayOrder', event.target.value)}
              error={errors.displayOrder !== undefined}
              helperText={errors.displayOrder}
              inputRef={displayOrderInputRef}
              disabled={disabled}
              fullWidth
            />
            <FormControlLabel
              control={
                <Checkbox
                  checked={values.isPrimary}
                  onChange={(event) => onPrimaryChange(event.target.checked)}
                  disabled={disabled}
                />
              }
              label="Primary image"
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
