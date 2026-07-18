import {
  Box,
  Button,
  CircularProgress,
  MenuItem,
  Pagination,
  Stack,
  TextField,
  Typography,
} from '@mui/material';
import { useEffect, useState, type FormEvent, type ReactElement } from 'react';
import { useNavigate } from 'react-router-dom';

import { ROUTES } from '@/core/router/routes';

import { OrderTable } from '../components/order-table';
import { useOrderList } from '../hooks/use-order-list';
import type { AdminOrderSummaryResponse } from '../models/admin-order-summary-response';
import type { OrderStatus } from '../models/order-status';
import type { OrderRepository } from '../repositories/order-repository';

const UNEXPECTED_MESSAGE = 'An unexpected error occurred';

/** The frozen `OrderStatus` values (dto-spec §4), plus the client-only "All" filter option. */
const STATUS_FILTER_OPTIONS: readonly { value: OrderStatus | 'ALL'; label: string }[] = [
  { value: 'ALL', label: 'All' },
  { value: 'PENDING', label: 'Pending' },
  { value: 'CONFIRMED', label: 'Confirmed' },
  { value: 'SHIPPING', label: 'Shipping' },
  { value: 'DELIVERED', label: 'Delivered' },
  { value: 'CANCELLED', label: 'Cancelled' },
];

interface OrderListPageProps {
  readonly repository: OrderRepository;
}

/**
 * The order management list screen — the React analog of the Flutter order
 * list screen, mirroring `ProductListPage` (Sprint 11) adapted for a
 * read-only, server-filtered, server-searched list with no row-level
 * mutation (sprint-12-plan Task 04). It owns [useOrderList] (the paginated,
 * status-filtered, order-code-searchable load state machine). There is no
 * "New order" action and no delete — orders originate at customer checkout,
 * not admin CRUD (Design Decision 4). "View" navigates to
 * [ROUTES.orderDetail] — that screen is Task 05's own scope.
 */
export function OrderListPage({ repository }: OrderListPageProps): ReactElement {
  const list = useOrderList(repository);
  const { load } = list;
  const navigate = useNavigate();
  // The search field's draft text, committed to the hook only on submit
  // (explicit-submit search, sprint-12-plan Task 04 — never search-as-you-type).
  const [orderCodeDraft, setOrderCodeDraft] = useState('');

  useEffect(() => {
    void load();
  }, [load]);

  function handleStatusFilterChange(value: OrderStatus | 'ALL'): void {
    void list.setStatusFilter(value === 'ALL' ? undefined : value);
  }

  function handleSearchSubmit(event: FormEvent<HTMLFormElement>): void {
    event.preventDefault();
    void list.setOrderCodeSearch(orderCodeDraft.trim());
  }

  function handleSearchClear(): void {
    setOrderCodeDraft('');
    void list.setOrderCodeSearch('');
  }

  function handleView(order: AdminOrderSummaryResponse): void {
    navigate(ROUTES.orderDetail(order.id));
  }

  const isFiltered = list.statusFilter !== undefined || list.orderCodeSearch !== '';
  const isBusy = list.status === 'loading';

  return (
    <Box>
      <Typography variant="h4" component="h1" sx={{ mb: 2 }}>
        Orders
      </Typography>

      <Stack direction="row" spacing={2} alignItems="flex-start" sx={{ mb: 2 }}>
        <TextField
          select
          label="Status"
          value={list.statusFilter ?? 'ALL'}
          onChange={(event) => handleStatusFilterChange(event.target.value as OrderStatus | 'ALL')}
          disabled={isBusy}
          sx={{ minWidth: 180 }}
        >
          {STATUS_FILTER_OPTIONS.map((option) => (
            <MenuItem key={option.value} value={option.value}>
              {option.label}
            </MenuItem>
          ))}
        </TextField>

        <Box component="form" onSubmit={handleSearchSubmit}>
          <Stack direction="row" spacing={1}>
            <TextField
              label="Search by order code"
              helperText="Searches order code only"
              value={orderCodeDraft}
              onChange={(event) => setOrderCodeDraft(event.target.value)}
              disabled={isBusy}
            />
            <Button type="submit" variant="outlined" disabled={isBusy}>
              Search
            </Button>
            {list.orderCodeSearch !== '' && (
              <Button disabled={isBusy} onClick={handleSearchClear}>
                Clear
              </Button>
            )}
          </Stack>
        </Box>
      </Stack>

      {list.status === 'loading' && (
        <Box sx={{ display: 'flex', justifyContent: 'center', p: 4 }}>
          <CircularProgress />
        </Box>
      )}

      {list.status === 'error' && (
        <Box sx={{ textAlign: 'center', p: 4 }}>
          <Typography color="text.secondary" sx={{ mb: 2 }}>
            {list.error?.message ?? UNEXPECTED_MESSAGE}
          </Typography>
          <Button variant="contained" onClick={() => void list.retry()}>
            Retry
          </Button>
        </Box>
      )}

      {list.status === 'ready' && list.orders.length === 0 && (
        <Typography color="text.secondary">
          {isFiltered ? 'No orders match this filter or search.' : 'No orders yet.'}
        </Typography>
      )}

      {list.status === 'ready' && list.orders.length > 0 && (
        <>
          <OrderTable orders={list.orders} onView={handleView} />
          {list.totalPages > 1 && (
            <Stack alignItems="center" sx={{ mt: 2 }}>
              <Pagination
                count={list.totalPages}
                page={list.page + 1}
                disabled={isBusy}
                onChange={(_event, page) => void list.goToPage(page - 1)}
              />
            </Stack>
          )}
        </>
      )}
    </Box>
  );
}
