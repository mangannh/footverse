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

import { ConfirmDialog } from '@/core/components/confirm-dialog';
import { AppError } from '@/core/error/app-error';
import { ROUTES } from '@/core/router/routes';

import { ProductTable } from '../components/product-table';
import { useProductList } from '../hooks/use-product-list';
import { useProductMutation } from '../hooks/use-product-mutation';
import type { AdminProductSummaryResponse } from '../models/admin-product-summary-response';
import type { ProductRepository } from '../repositories/product-repository';

const UNEXPECTED_MESSAGE = 'An unexpected error occurred';

interface ProductListPageProps {
  readonly repository: ProductRepository;
}

interface NavigationState {
  readonly successMessage?: string;
}

/**
 * The product list screen — the React analog of the Flutter product list
 * screen (sprint-11-plan Task 03), mirroring `BrandListPage` (Sprint 10). It
 * owns [useProductList] (the paginated load state machine) and
 * [useProductMutation] (delete), wiring the mutation's reload to the list's
 * own `load` so a successful delete always re-reads the server-owned page in
 * place (no optimistic update, no local removal). Create / edit navigate to
 * [ROUTES.productForm] — that page is Task 04's own scope.
 */
export function ProductListPage({ repository }: ProductListPageProps): ReactElement {
  const list = useProductList(repository);
  const { load } = list;
  const mutation = useProductMutation(repository, load);
  const navigate = useNavigate();
  const location = useLocation();
  const [deleteTarget, setDeleteTarget] = useState<AdminProductSummaryResponse | null>(null);
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
      setSuccessMessage('Product deleted');
    } catch (error) {
      setErrorMessage(error instanceof AppError ? error.message : UNEXPECTED_MESSAGE);
    }
  }

  return (
    <Box>
      <Stack direction="row" justifyContent="space-between" alignItems="center" sx={{ mb: 2 }}>
        <Typography variant="h4" component="h1">
          Products
        </Typography>
        <Button
          variant="contained"
          disabled={mutation.isMutating}
          onClick={() => navigate(ROUTES.productForm)}
        >
          New product
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

      {list.status === 'ready' && list.products.length === 0 && (
        <Typography color="text.secondary">No products yet — create one.</Typography>
      )}

      {list.status === 'ready' && list.products.length > 0 && (
        <>
          <ProductTable
            products={list.products}
            disabled={mutation.isMutating}
            onEdit={(product) => navigate(ROUTES.productForm, { state: { productId: product.id } })}
            onDeleteRequest={setDeleteTarget}
          />
          {list.totalPages > 1 && (
            <Stack alignItems="center" sx={{ mt: 2 }}>
              <Pagination
                count={list.totalPages}
                page={list.page + 1}
                disabled={mutation.isMutating}
                onChange={(_event, page) => void list.goToPage(page - 1)}
              />
            </Stack>
          )}
        </>
      )}

      <ConfirmDialog
        open={deleteTarget !== null}
        title="Delete product"
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
