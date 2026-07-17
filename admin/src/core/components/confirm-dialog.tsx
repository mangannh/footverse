import {
  Button,
  CircularProgress,
  Dialog,
  DialogActions,
  DialogContent,
  DialogContentText,
  DialogTitle,
} from '@mui/material';
import type { ReactElement } from 'react';

interface ConfirmDialogProps {
  readonly open: boolean;
  readonly title: string;
  readonly message: string;
  /** True while the confirmed action is running (disables both actions). */
  readonly confirming: boolean;
  readonly confirmLabel?: string;
  onConfirm(): void;
  onCancel(): void;
}

/**
 * A shared confirmation dialog (react-guidelines §Component Rules) — generic
 * enough to be reused by any feature's delete confirmation (Task 05 reuses it
 * verbatim), but coupled to no feature. It stays open and disabled while
 * [confirming]; the caller closes it only once the server confirms.
 */
export function ConfirmDialog({
  open,
  title,
  message,
  confirming,
  confirmLabel = 'Delete',
  onConfirm,
  onCancel,
}: ConfirmDialogProps): ReactElement {
  return (
    <Dialog open={open} onClose={confirming ? undefined : onCancel}>
      <DialogTitle>{title}</DialogTitle>
      <DialogContent>
        <DialogContentText>{message}</DialogContentText>
      </DialogContent>
      <DialogActions>
        <Button onClick={onCancel} disabled={confirming}>
          Cancel
        </Button>
        <Button onClick={onConfirm} disabled={confirming} color="error" variant="contained">
          {confirming ? <CircularProgress size={20} color="inherit" /> : confirmLabel}
        </Button>
      </DialogActions>
    </Dialog>
  );
}
