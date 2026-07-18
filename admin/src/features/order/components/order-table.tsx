import {
  Button,
  Paper,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
} from '@mui/material';
import type { ReactElement } from 'react';

import type { AdminOrderSummaryResponse } from '../models/admin-order-summary-response';
import type { OrderStatus } from '../models/order-status';
import type { PaymentStatus } from '../models/payment-status';

interface OrderTableProps {
  readonly orders: readonly AdminOrderSummaryResponse[];
  onView(order: AdminOrderSummaryResponse): void;
}

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

/**
 * The ADMIN order list table — presentational only (react-guidelines
 * §Component Rules), mirroring `ProductTable` (Sprint 11). It renders the
 * page of orders the caller supplies — including the owning customer's
 * identity, the reason the ADMIN DTO exists — and reports view intent
 * upward; it holds no state, calls no repository, and decides nothing. There
 * is no edit or delete action: orders are not admin-CRUD (sprint-12-plan
 * Design Decision 4) — the only row action is "View", which the detail
 * screen (Task 05) uses to drive the status transition.
 */
export function OrderTable({ orders, onView }: OrderTableProps): ReactElement {
  return (
    <TableContainer component={Paper}>
      <Table size="small">
        <TableHead>
          <TableRow>
            <TableCell>Order Code</TableCell>
            <TableCell>Customer</TableCell>
            <TableCell>Status</TableCell>
            <TableCell>Payment Status</TableCell>
            <TableCell align="right">Item Count</TableCell>
            <TableCell align="right">Total</TableCell>
            <TableCell>Placed At</TableCell>
            <TableCell align="right">Actions</TableCell>
          </TableRow>
        </TableHead>
        <TableBody>
          {orders.map((order) => (
            <TableRow key={order.id}>
              <TableCell>{order.orderCode}</TableCell>
              <TableCell>{order.customerFullName}</TableCell>
              <TableCell>{STATUS_LABELS[order.status]}</TableCell>
              <TableCell>{PAYMENT_STATUS_LABELS[order.paymentStatus]}</TableCell>
              <TableCell align="right">{order.itemCount}</TableCell>
              <TableCell align="right">{order.total.toFixed(2)}</TableCell>
              <TableCell>{formatDateTime(order.createdAt)}</TableCell>
              <TableCell align="right">
                <Button size="small" onClick={() => onView(order)}>
                  View
                </Button>
              </TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </TableContainer>
  );
}
