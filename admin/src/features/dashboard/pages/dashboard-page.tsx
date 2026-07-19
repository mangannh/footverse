import { Box, Button, CircularProgress, Typography } from '@mui/material';
import { useEffect, type ReactElement } from 'react';
import { useNavigate } from 'react-router-dom';

import { ROUTES } from '@/core/router/routes';
import type { AdminOrderSummaryResponse } from '@/features/order/models/admin-order-summary-response';

import { BestSellersTable } from '../components/best-sellers-table';
import { KpiCard } from '../components/kpi-card';
import { MonthlyRevenueTable } from '../components/monthly-revenue-table';
import { RecentOrdersTable } from '../components/recent-orders-table';
import { useDashboard } from '../hooks/use-dashboard';
import type { OrderStatus } from '../models/order-status-count-response';
import type { DashboardRepository } from '../repositories/dashboard-repository';

const UNEXPECTED_MESSAGE = 'An unexpected error occurred';

const STATUS_LABELS: Record<OrderStatus, string> = {
  PENDING: 'Pending',
  CONFIRMED: 'Confirmed',
  SHIPPING: 'Shipping',
  DELIVERED: 'Delivered',
  CANCELLED: 'Cancelled',
};

interface DashboardPageProps {
  readonly repository: DashboardRepository;
}

/**
 * The admin panel's landing screen (sprint-13-plan Task 03) — the store's
 * core operating figures, assembled entirely by the server
 * (react-guidelines §Server Authoritative). This page renders; it computes
 * nothing. It owns {@link useDashboard} (this task) and reads from the
 * `dashboard` feature's own {@link DashboardRepository} (Task 02); the only
 * value derived on the client is the monthly-revenue bar width, computed by
 * the pure `toBarPercentages` helper the {@link MonthlyRevenueTable} calls.
 *
 * Every window is fixed by the server: no date range, filter, comparison
 * period, or pagination is offered here, and there is no polling or
 * auto-refresh — the page reloads only on mount or an explicit retry
 * (Design Notes, §Out of Scope).
 */
export function DashboardPage({ repository }: DashboardPageProps): ReactElement {
  const dashboard = useDashboard(repository);
  const { load } = dashboard;
  const navigate = useNavigate();

  useEffect(() => {
    void load();
  }, [load]);

  function handleViewOrder(order: AdminOrderSummaryResponse): void {
    navigate(ROUTES.orderDetail(order.id));
  }

  if (dashboard.status === 'loading') {
    return (
      <Box sx={{ display: 'flex', justifyContent: 'center', p: 4 }}>
        <CircularProgress />
      </Box>
    );
  }

  if (dashboard.status === 'error') {
    return (
      <Box sx={{ textAlign: 'center', p: 4 }}>
        <Typography color="text.secondary" sx={{ mb: 2 }}>
          {dashboard.error?.message ?? UNEXPECTED_MESSAGE}
        </Typography>
        <Button variant="contained" onClick={() => void dashboard.retry()}>
          Retry
        </Button>
      </Box>
    );
  }

  const { data } = dashboard;
  if (data === null) {
    return <></>;
  }

  // Profit coverage is stated, never hidden (Design Decision 2): the caveat
  // renders as visible supporting text beside the figure only when the
  // server's profit sum does not cover every delivered order line — never a
  // tooltip, hidden text, or a footnote.
  const profitCaveat =
    data.profitLinesWithCost < data.profitLinesTotal
      ? `Based on ${data.profitLinesWithCost} of ${data.profitLinesTotal} delivered order lines with a recorded cost.`
      : undefined;

  return (
    <Box>
      <Typography variant="h4" component="h1" sx={{ mb: 3 }}>
        Dashboard
      </Typography>

      <Box
        sx={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))',
          gap: 2,
          mb: 2,
        }}
      >
        <KpiCard label="Total Revenue" value={data.totalRevenue.toFixed(2)} />
        <KpiCard label="Total Orders" value={String(data.totalOrders)} />
        <KpiCard
          label="Gross Profit (before discount & shipping)"
          value={data.grossProfit.toFixed(2)}
          caveat={profitCaveat}
        />
      </Box>

      <Typography variant="h6" component="h2" sx={{ mb: 1 }}>
        Orders by Status
      </Typography>
      <Box
        sx={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))',
          gap: 2,
          mb: 4,
        }}
      >
        {data.ordersByStatus.map((row) => (
          <KpiCard key={row.status} label={STATUS_LABELS[row.status]} value={String(row.count)} />
        ))}
      </Box>

      <Typography variant="h6" component="h2" sx={{ mb: 1 }}>
        Monthly Revenue
      </Typography>
      <Box sx={{ mb: 4 }}>
        <MonthlyRevenueTable rows={data.monthlyRevenue} />
      </Box>

      <Typography variant="h6" component="h2" sx={{ mb: 1 }}>
        Best Sellers
      </Typography>
      <Box sx={{ mb: 4 }}>
        <BestSellersTable products={data.bestSellingProducts} />
      </Box>

      <Typography variant="h6" component="h2" sx={{ mb: 1 }}>
        Recent Orders
      </Typography>
      <RecentOrdersTable orders={data.recentOrders} onView={handleViewOrder} />
    </Box>
  );
}
