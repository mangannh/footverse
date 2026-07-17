import { Box, Button, CircularProgress, Snackbar, Stack, Typography } from '@mui/material';
import { useEffect, useState, type ReactElement } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';

import { ConfirmDialog } from '@/core/components/confirm-dialog';
import { AppError } from '@/core/error/app-error';
import { ROUTES } from '@/core/router/routes';

import { BrandTable } from '../components/brand-table';
import { useBrandList } from '../hooks/use-brand-list';
import { useBrandMutation } from '../hooks/use-brand-mutation';
import type { BrandResponse } from '../models/brand-response';
import type { BrandRepository } from '../repositories/brand-repository';

const UNEXPECTED_MESSAGE = 'An unexpected error occurred';

interface BrandListPageProps {
  readonly repository: BrandRepository;
}

interface NavigationState {
  readonly successMessage?: string;
}

/**
 * The brand list screen — the React analog of the Flutter `AddressListScreen`
 * (sprint-10-plan Task 04). It owns [useBrandList] (the load state machine) and
 * [useBrandMutation] (delete), wiring the mutation's reload to the list's own
 * `load` so a successful delete always re-reads the server-owned list. Create /
 * edit are routed to [ROUTES.brandForm]; that page's own success reload
 * (navigating back here) re-mounts this page, which re-fetches on mount.
 */
export function BrandListPage({ repository }: BrandListPageProps): ReactElement {
  const list = useBrandList(repository);
  const { load } = list;
  const mutation = useBrandMutation(repository, load);
  const navigate = useNavigate();
  const location = useLocation();
  const [deleteTarget, setDeleteTarget] = useState<BrandResponse | null>(null);
  const [errorMessage, setErrorMessage] = useState<string>();
  // Read once at mount: a create/edit success navigates back here with a fresh
  // router state carrying the message (mirrors the Flutter provider's terminal
  // pop-and-refresh, adapted for a routed React page).
  const [successMessage, setSuccessMessage] = useState<string | undefined>(
    (location.state as NavigationState | null)?.successMessage,
  );

  useEffect(() => {
    void load();
  }, [load]);

  async function handleDeleteConfirm(): Promise<void> {
    if (deleteTarget === null) {
      return;
    }
    try {
      await mutation.remove(deleteTarget.id);
      setDeleteTarget(null);
      setSuccessMessage('Brand deleted');
    } catch (error) {
      setErrorMessage(error instanceof AppError ? error.message : UNEXPECTED_MESSAGE);
    }
  }

  return (
    <Box>
      <Stack direction="row" justifyContent="space-between" alignItems="center" sx={{ mb: 2 }}>
        <Typography variant="h4" component="h1">
          Brands
        </Typography>
        <Button
          variant="contained"
          disabled={mutation.isMutating}
          onClick={() => navigate(ROUTES.brandForm)}
        >
          New brand
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

      {list.status === 'ready' && list.brands.length === 0 && (
        <Typography color="text.secondary">No brands yet — create one.</Typography>
      )}

      {list.status === 'ready' && list.brands.length > 0 && (
        <BrandTable
          brands={list.brands}
          disabled={mutation.isMutating}
          onEdit={(brand) => navigate(ROUTES.brandForm, { state: { brand } })}
          onDeleteRequest={setDeleteTarget}
        />
      )}

      <ConfirmDialog
        open={deleteTarget !== null}
        title="Delete brand"
        message={
          deleteTarget !== null ? `Delete "${deleteTarget.name}"? This cannot be undone.` : ''
        }
        confirming={mutation.isMutating}
        onConfirm={() => {
          void handleDeleteConfirm();
        }}
        onCancel={() => setDeleteTarget(null)}
      />

      <Snackbar
        open={successMessage !== undefined}
        autoHideDuration={4000}
        onClose={() => setSuccessMessage(undefined)}
        message={successMessage}
      />
      <Snackbar
        open={errorMessage !== undefined}
        autoHideDuration={6000}
        onClose={() => setErrorMessage(undefined)}
        message={errorMessage}
      />
    </Box>
  );
}
