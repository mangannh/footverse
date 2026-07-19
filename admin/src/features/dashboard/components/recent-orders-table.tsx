import {
  Button,
  Paper,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Typography,
} from '@mui/material';
import type { ReactElement } from 'react';

import type { AdminOrderSummaryResponse } from '@/features/order/models/admin-order-summary-response';

const STATUS_LABELS: Record<AdminOrderSummaryResponse['status'], string> = {
  PENDING: 'Pending',
  CONFIRMED: 'Confirmed',
  SHIPPING: 'Shipping',
  DELIVERED: 'Delivered',
  CANCELLED: 'Cancelled',
};

function formatDateTime(value: string): string {
  return value.replace('T', ' ').slice(0, 16);
}

interface RecentOrdersTableProps {
  readonly orders: readonly AdminOrderSummaryResponse[];
  onView(order: AdminOrderSummaryResponse): void;
}

/**
 * The dashboard's five most-recently-placed orders (sprint-13-plan Task 03),
 * reusing the `order` feature's `AdminOrderSummaryResponse` — the type
 * `DashboardResponse.recentOrders` already carries (Task 02); no
 * near-duplicate row type is declared here. Presentational only: each row's
 * "View" action reports the order upward, and the page — never this
 * component — navigates via `ROUTES.orderDetail(id)` (mirrors
 * `OrderTable`, Sprint 12).
 */
export function RecentOrdersTable({ orders, onView }: RecentOrdersTableProps): ReactElement {
  if (orders.length === 0) {
    return <Typography color="text.secondary">No orders yet.</Typography>;
  }

  return (
    <TableContainer component={Paper}>
      <Table size="small">
        <TableHead>
          <TableRow>
            <TableCell>Order Code</TableCell>
            <TableCell>Customer</TableCell>
            <TableCell>Status</TableCell>
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
