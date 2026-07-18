import { Button, Stack, Typography } from '@mui/material';
import type { ReactElement } from 'react';

import type { OrderStatus } from '../models/order-status';
import { getAllowedTransitions, requiresConfirmation } from '../utils/order-transitions';

interface OrderStatusActionsProps {
  readonly status: OrderStatus;
  /** True while a transition is in flight (disables every action). */
  readonly disabled: boolean;
  onTransition(target: OrderStatus): void;
}

const TRANSITION_LABELS: Record<OrderStatus, string> = {
  PENDING: 'Pending',
  CONFIRMED: 'Confirm',
  SHIPPING: 'Ship',
  DELIVERED: 'Deliver',
  CANCELLED: 'Cancel order',
};

/**
 * The order detail's status-transition actions — presentational only
 * (react-guidelines §Component Rules). It renders exactly one button per
 * status the pure `getAllowedTransitions` helper returns for the order's
 * current status — never a disabled button for a terminal order, and never
 * a button the helper did not return — and reports the requested target
 * upward via `onTransition`; it decides nothing about whether a transition
 * is legal (the server does, sprint-12-plan Design Decision 6) and holds no
 * confirmation logic itself. The caller (the detail page) uses
 * `requiresConfirmation` to gate the destructive `CANCELLED` target behind
 * the shared `ConfirmDialog` before ever executing it; this component only
 * reads that same helper to style the cancel action as destructive.
 */
export function OrderStatusActions({
  status,
  disabled,
  onTransition,
}: OrderStatusActionsProps): ReactElement {
  const allowedTransitions = getAllowedTransitions(status);

  if (allowedTransitions.length === 0) {
    return (
      <Typography color="text.secondary">
        This order is final — no further status change is possible.
      </Typography>
    );
  }

  return (
    <Stack direction="row" spacing={1}>
      {allowedTransitions.map((target) => (
        <Button
          key={target}
          variant="contained"
          color={requiresConfirmation(target) ? 'error' : 'primary'}
          disabled={disabled}
          onClick={() => onTransition(target)}
        >
          {TRANSITION_LABELS[target]}
        </Button>
      ))}
    </Stack>
  );
}
