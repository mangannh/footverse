import {
  Box,
  Button,
  CircularProgress,
  Pagination,
  Snackbar,
  Stack,
  Typography,
} from '@mui/material';
import { useEffect, useState, type ReactElement } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';

import { ROUTES } from '@/core/router/routes';

import { CouponTable } from '../components/coupon-table';
import { useCouponList } from '../hooks/use-coupon-list';
import type { CouponResponse } from '../models/coupon-response';
import type { CouponRepository } from '../repositories/coupon-repository';

const UNEXPECTED_MESSAGE = 'An unexpected error occurred';

interface CouponListPageProps {
  readonly repository: CouponRepository;
}

interface NavigationState {
  readonly successMessage?: string;
}

/**
 * The coupon list screen — the React analog of the Flutter coupon list
 * screen (sprint-11-plan Task 05), mirroring `ProductListPage` (Sprint 11
 * Task 03) — the paginated read shape `BrandListPage` (Sprint 10) does not
 * need. It owns [useCouponList] (the paginated load state machine). There is
 * no delete affordance (coupons have no delete endpoint), so this page has
 * no mutation hook and no `ConfirmDialog` — only "New coupon" and "Edit".
 */
export function CouponListPage({ repository }: CouponListPageProps): ReactElement {
  const list = useCouponList(repository);
  const { load } = list;
  const navigate = useNavigate();
  const location = useLocation();
  // Read once at mount: a create/edit success navigates back here with a fresh
  // router state carrying the message (mirrors the Flutter provider's terminal
  // pop-and-refresh, adapted for a routed React page).
  const [successMessage, setSuccessMessage] = useState<string | undefined>(
    (location.state as NavigationState | null)?.successMessage,
  );

  useEffect(() => {
    void load();
  }, [load]);

  return (
    <Box>
      <Stack direction="row" justifyContent="space-between" alignItems="center" sx={{ mb: 2 }}>
        <Typography variant="h4" component="h1">
          Coupons
        </Typography>
        <Button variant="contained" onClick={() => navigate(ROUTES.couponForm)}>
          New coupon
        </Button>
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

      {list.status === 'ready' && list.coupons.length === 0 && (
        <Typography color="text.secondary">No coupons yet — create one.</Typography>
      )}

      {list.status === 'ready' && list.coupons.length > 0 && (
        <>
          <CouponTable
            coupons={list.coupons}
            onEdit={(coupon: CouponResponse) => navigate(ROUTES.couponForm, { state: { coupon } })}
          />
          {list.totalPages > 1 && (
            <Stack alignItems="center" sx={{ mt: 2 }}>
              <Pagination
                count={list.totalPages}
                page={list.page + 1}
                onChange={(_event, page) => void list.goToPage(page - 1)}
              />
            </Stack>
          )}
        </>
      )}

      <Snackbar
        open={successMessage !== undefined}
        autoHideDuration={4000}
        onClose={() => setSuccessMessage(undefined)}
        message={successMessage}
      />
    </Box>
  );
}
