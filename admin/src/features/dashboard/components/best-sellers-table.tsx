import {
  Avatar,
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

import type { BestSellingProductResponse } from '../models/best-selling-product-response';

interface BestSellersTableProps {
  readonly products: readonly BestSellingProductResponse[];
}

/**
 * The dashboard's top best-selling products, rendered exactly in the order
 * the server ranked them — presentational only, no client-side sort or
 * recomputation (sprint-13-plan Task 03). A product with no
 * `productImageUrl` falls back to a plain initial-letter avatar rather than
 * a broken image. An empty list (an empty store, or simply no delivered
 * sales yet) renders a clear empty state, never a blank area.
 */
export function BestSellersTable({ products }: BestSellersTableProps): ReactElement {
  if (products.length === 0) {
    return <Typography color="text.secondary">No sales yet.</Typography>;
  }

  return (
    <TableContainer component={Paper}>
      <Table size="small">
        <TableHead>
          <TableRow>
            <TableCell>Product</TableCell>
            <TableCell align="right">Units Sold</TableCell>
            <TableCell align="right">Revenue</TableCell>
          </TableRow>
        </TableHead>
        <TableBody>
          {products.map((product) => (
            <TableRow key={product.productId}>
              <TableCell>
                <Stack direction="row" spacing={1} alignItems="center">
                  <Avatar
                    src={product.productImageUrl ?? undefined}
                    alt={product.productName}
                    variant="rounded"
                  >
                    {product.productName.charAt(0)}
                  </Avatar>
                  <Typography variant="body2">{product.productName}</Typography>
                </Stack>
              </TableCell>
              <TableCell align="right">{product.quantitySold}</TableCell>
              <TableCell align="right">{product.revenue.toFixed(2)}</TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </TableContainer>
  );
}
