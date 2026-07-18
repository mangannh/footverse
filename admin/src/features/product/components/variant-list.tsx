import {
  Box,
  Button,
  Paper,
  Stack,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Typography,
} from '@mui/material';
import type { ReactElement } from 'react';

import type { AdminProductVariantResponse } from '../models/admin-product-variant-response';

interface VariantListProps {
  readonly variants: readonly AdminProductVariantResponse[];
  /** True while a mutation is in flight (disables every action). */
  readonly disabled: boolean;
  onAdd(): void;
  onEdit(variant: AdminProductVariantResponse): void;
}

/**
 * The product's variant section — presentational only (react-guidelines
 * §Component Rules). It renders the variants the caller supplies (the
 * server-authoritative effective `price` and the ADMIN-only `costPrice`) and
 * reports add / edit intent upward. There is no delete affordance — the
 * frozen contract has none; a variant is retired via `status = INACTIVE`
 * (edited through the same dialog).
 */
export function VariantList({ variants, disabled, onAdd, onEdit }: VariantListProps): ReactElement {
  return (
    <Box sx={{ mt: 4 }}>
      <Stack direction="row" justifyContent="space-between" alignItems="center" sx={{ mb: 2 }}>
        <Typography variant="h6" component="h2">
          Variants
        </Typography>
        <Button variant="outlined" disabled={disabled} onClick={onAdd}>
          Add variant
        </Button>
      </Stack>

      {variants.length === 0 && (
        <Typography color="text.secondary">No variants yet — add one.</Typography>
      )}

      {variants.length > 0 && (
        <TableContainer component={Paper}>
          <Table size="small">
            <TableHead>
              <TableRow>
                <TableCell>Color</TableCell>
                <TableCell>Size</TableCell>
                <TableCell>SKU</TableCell>
                <TableCell align="right">Stock</TableCell>
                <TableCell>Status</TableCell>
                <TableCell align="right">Price</TableCell>
                <TableCell align="right">Cost Price</TableCell>
                <TableCell align="right">Actions</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {variants.map((variant) => (
                <TableRow key={variant.id}>
                  <TableCell>{variant.color}</TableCell>
                  <TableCell>{variant.size}</TableCell>
                  <TableCell>{variant.sku}</TableCell>
                  <TableCell align="right">{variant.stockQuantity}</TableCell>
                  <TableCell>{variant.status}</TableCell>
                  <TableCell align="right">{variant.price.toFixed(2)}</TableCell>
                  <TableCell align="right">{variant.costPrice.toFixed(2)}</TableCell>
                  <TableCell align="right">
                    <Button size="small" disabled={disabled} onClick={() => onEdit(variant)}>
                      Edit
                    </Button>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </TableContainer>
      )}
    </Box>
  );
}
