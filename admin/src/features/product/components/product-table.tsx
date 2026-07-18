import {
  Button,
  Paper,
  Stack,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
} from '@mui/material';
import type { ReactElement } from 'react';

import type { AdminProductSummaryResponse } from '../models/admin-product-summary-response';

interface ProductTableProps {
  readonly products: readonly AdminProductSummaryResponse[];
  /** True while a mutation is in flight (disables every row action). */
  readonly disabled: boolean;
  onEdit(product: AdminProductSummaryResponse): void;
  onDeleteRequest(product: AdminProductSummaryResponse): void;
}

/**
 * The ADMIN product list table — presentational only (react-guidelines
 * §Component Rules), mirroring `BrandTable` (Sprint 10). It renders the page
 * of products the caller supplies and reports edit / delete intent upward; it
 * holds no state, calls no repository, and decides nothing — the caller owns
 * pagination and mutation.
 */
export function ProductTable({
  products,
  disabled,
  onEdit,
  onDeleteRequest,
}: ProductTableProps): ReactElement {
  return (
    <TableContainer component={Paper}>
      <Table>
        <TableHead>
          <TableRow>
            <TableCell>Name</TableCell>
            <TableCell>Brand</TableCell>
            <TableCell>Category</TableCell>
            <TableCell align="right">Base Price</TableCell>
            <TableCell align="right">Rating</TableCell>
            <TableCell>Available</TableCell>
            <TableCell align="right">Actions</TableCell>
          </TableRow>
        </TableHead>
        <TableBody>
          {products.map((product) => (
            <TableRow key={product.id}>
              <TableCell>{product.name}</TableCell>
              <TableCell>{product.brandName}</TableCell>
              <TableCell>{product.categoryName}</TableCell>
              <TableCell align="right">{product.basePrice.toFixed(2)}</TableCell>
              <TableCell align="right">{product.averageRating.toFixed(1)}</TableCell>
              <TableCell>{product.available ? 'Yes' : 'No'}</TableCell>
              <TableCell align="right">
                <Stack direction="row" spacing={1} justifyContent="flex-end">
                  <Button size="small" disabled={disabled} onClick={() => onEdit(product)}>
                    Edit
                  </Button>
                  <Button
                    size="small"
                    color="error"
                    disabled={disabled}
                    onClick={() => onDeleteRequest(product)}
                  >
                    Delete
                  </Button>
                </Stack>
              </TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </TableContainer>
  );
}
