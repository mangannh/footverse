import { Box, Button, CircularProgress, Divider, Snackbar, Stack, Typography } from '@mui/material';
import { useEffect, useState, type ReactElement } from 'react';
import { useParams } from 'react-router-dom';

import { ConfirmDialog } from '@/core/components/confirm-dialog';
import { AppError } from '@/core/error/app-error';

import { OrderItemsTable } from '../components/order-items-table';
import { OrderStatusActions } from '../components/order-status-actions';
import { useOrderDetail } from '../hooks/use-order-detail';
import type { AdminOrderDetailResponse } from '../models/admin-order-detail-response';
import type { OrderStatus } from '../models/order-status';
import type { PaymentStatus } from '../models/payment-status';
import type { OrderRepository } from '../repositories/order-repository';
import { requiresConfirmation } from '../utils/order-transitions';

const UNEXPECTED_MESSAGE = 'An unexpected error occurred';

const STATUS_LABELS: Record<OrderStatus, string> = {
  PENDING: 'Pending',
  CONFIRMED: 'Confirmed',
  SHIPPING: 'Shipping',
  DELIVERED: 'Delivered',
  CANCELLED: 'Cancelled',
};

const PAYMENT_STATUS_LABELS: Record<PaymentStatus, string> = {
  UNPAID: 'Unpaid',
  PAID: 'Paid',
};

function formatDateTime(value: string): string {
  return value.replace('T', ' ').slice(0, 16);
}

interface OrderDetailPageProps {
  readonly repository: OrderRepository;
}

/**
 * The order detail screen — the React analog of the Flutter order detail
 * screen, the admin panel's first read-detail page (sprint-12-plan Task 05,
 * Design Decision 5). It reads `:id` from the route and loads its own
 * detail via [useOrderDetail] — it never depends on state handed over from
 * the list, so the page is directly linkable and refreshable. It renders
 * the full order (header, customer contact, shipping snapshot, money
 * breakdown, coupon, note, line items) and drives the frozen status machine
 * through [OrderStatusActions]; only the destructive `CANCELLED` target is
 * gated behind the shared `ConfirmDialog` (reused unchanged) — the three
 * forward transitions run immediately on click. Every transition replaces
 * the page's state with the server's returned detail; nothing is computed
 * client-side.
 */
export function OrderDetailPage({ repository }: OrderDetailPageProps): ReactElement {
  const { id } = useParams<{ id: string }>();
  const orderId = Number(id);
  const detail = useOrderDetail(repository, orderId);
  const { load } = detail;
  const [pendingTarget, setPendingTarget] = useState<OrderStatus | null>(null);
  const [transitionErrorMessage, setTransitionErrorMessage] = useState<string>();
  const [successMessage, setSuccessMessage] = useState<string>();

  useEffect(() => {
    void load();
  }, [load]);

  async function runTransition(target: OrderStatus): Promise<void> {
    try {
      await detail.updateStatus(target);
      setPendingTarget(null);
      setSuccessMessage(`Order marked ${STATUS_LABELS[target]}`);
    } catch (error) {
      // The confirm dialog (if open) stays open on failure — it closes only
      // on success — so the admin sees the rejection without losing context.
      setTransitionErrorMessage(error instanceof AppError ? error.message : UNEXPECTED_MESSAGE);
    }
  }

  function handleTransitionClick(target: OrderStatus): void {
    setTransitionErrorMessage(undefined);
    if (requiresConfirmation(target)) {
      setPendingTarget(target);
      return;
    }
    void runTransition(target);
  }

  return (
    <Box>
      <Typography variant="h4" component="h1" sx={{ mb: 2 }}>
        Order Detail
      </Typography>

      {detail.status === 'loading' && (
        <Box sx={{ display: 'flex', justifyContent: 'center', p: 4 }}>
          <CircularProgress />
        </Box>
      )}

      {detail.status === 'error' && (
        <Box sx={{ textAlign: 'center', p: 4 }}>
          <Typography color="text.secondary" sx={{ mb: 2 }}>
            {detail.error?.errorCode === 'ORDER_NOT_FOUND'
              ? 'This order could not be found.'
              : (detail.error?.message ?? UNEXPECTED_MESSAGE)}
          </Typography>
          <Button variant="contained" onClick={() => void detail.retry()}>
            Retry
          </Button>
        </Box>
      )}

      {detail.status === 'ready' && detail.order !== null && (
        <OrderDetailContent
          order={detail.order}
          isUpdatingStatus={detail.isUpdatingStatus}
          transitionErrorMessage={transitionErrorMessage}
          onTransitionClick={handleTransitionClick}
        />
      )}

      <ConfirmDialog
        open={pendingTarget !== null}
        title="Cancel order"
        message="Cancelling restores stock and coupon usage for this order. This cannot be undone."
        confirmLabel="Cancel order"
        confirming={detail.isUpdatingStatus}
        onConfirm={() => {
          if (pendingTarget !== null) {
            void runTransition(pendingTarget);
          }
        }}
        onCancel={() => setPendingTarget(null)}
      />

      <Snackbar
        open={successMessage !== undefined}
        autoHideDuration={4000}
        onClose={() => setSuccessMessage(undefined)}
        message={successMessage}
      />
    </Box>
  );
}

interface OrderDetailContentProps {
  readonly order: AdminOrderDetailResponse;
  readonly isUpdatingStatus: boolean;
  readonly transitionErrorMessage: string | undefined;
  onTransitionClick(target: OrderStatus): void;
}

/**
 * The loaded order's read-only content plus the status actions — split out
 * of [OrderDetailPage] only so the parent's loading/error branches stay
 * flat; it still composes only feature-local components and owns no state
 * of its own (react-guidelines §Component Rules).
 */
function OrderDetailContent({
  order,
  isUpdatingStatus,
  transitionErrorMessage,
  onTransitionClick,
}: OrderDetailContentProps): ReactElement {
  return (
    <Stack spacing={3}>
      <Box>
        <Typography variant="h6">{order.orderCode}</Typography>
        <Typography color="text.secondary">
          {STATUS_LABELS[order.status]} · {PAYMENT_STATUS_LABELS[order.paymentStatus]}
        </Typography>
        <Typography color="text.secondary">Placed {formatDateTime(order.createdAt)}</Typography>
        {order.deliveredAt !== null && order.deliveredAt !== undefined && (
          <Typography color="text.secondary">
            Delivered {formatDateTime(order.deliveredAt)}
          </Typography>
        )}
        {order.cancelledAt !== null && order.cancelledAt !== undefined && (
          <Typography color="text.secondary">
            Cancelled {formatDateTime(order.cancelledAt)}
          </Typography>
        )}
      </Box>

      <Divider />

      <Stack direction={{ xs: 'column', md: 'row' }} spacing={4}>
        <Box sx={{ flex: 1 }}>
          <Typography variant="subtitle1" gutterBottom>
            Customer
          </Typography>
          <Typography>{order.customerFullName}</Typography>
          <Typography color="text.secondary">{order.customerEmail}</Typography>
          <Typography color="text.secondary">{order.customerPhone}</Typography>
        </Box>

        <Box sx={{ flex: 1 }}>
          <Typography variant="subtitle1" gutterBottom>
            Delivery Address
          </Typography>
          <Typography>{order.shippingRecipientName}</Typography>
          <Typography color="text.secondary">{order.shippingRecipientPhone}</Typography>
          <Typography color="text.secondary">
            {order.shippingStreetAddress}, {order.shippingWard}, {order.shippingDistrict},{' '}
            {order.shippingProvince}
          </Typography>
        </Box>
      </Stack>

      <Divider />

      <Box>
        <Typography variant="subtitle1" gutterBottom>
          Payment
        </Typography>
        <Typography>Subtotal: {order.subtotal.toFixed(2)}</Typography>
        <Typography>Discount: {order.discountAmount.toFixed(2)}</Typography>
        <Typography>Shipping fee: {order.shippingFee.toFixed(2)}</Typography>
        <Typography variant="subtitle1">Total: {order.total.toFixed(2)}</Typography>
        <Typography color="text.secondary">
          Coupon:{' '}
          {order.couponCode !== null && order.couponCode !== undefined ? order.couponCode : 'None'}
        </Typography>
      </Box>

      {order.note !== null && order.note !== undefined && (
        <Box>
          <Typography variant="subtitle1" gutterBottom>
            Note
          </Typography>
          <Typography color="text.secondary">{order.note}</Typography>
        </Box>
      )}

      <Divider />

      <Box>
        <Typography variant="subtitle1" gutterBottom>
          Items
        </Typography>
        <OrderItemsTable items={order.items} />
      </Box>

      <Divider />

      <Box>
        <Typography variant="subtitle1" gutterBottom>
          Status
        </Typography>
        {transitionErrorMessage !== undefined && (
          <Typography color="error" sx={{ mb: 1 }}>
            {transitionErrorMessage}
          </Typography>
        )}
        <OrderStatusActions
          status={order.status}
          disabled={isUpdatingStatus}
          onTransition={onTransitionClick}
        />
      </Box>
    </Stack>
  );
}
