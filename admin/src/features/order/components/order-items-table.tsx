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
} from '@mui/material';
import type { ReactElement } from 'react';

import type { OrderItemResponse } from '../models/order-item-response';

interface OrderItemsTableProps {
  readonly items: readonly OrderItemResponse[];
}

/**
 * The order detail's line-items table — presentational only
 * (react-guidelines §Component Rules). It renders each line's checkout
 * snapshot exactly as persisted (product name / image / color / size / unit
 * price / quantity / line total); it holds no state and calls no
 * repository. It never renders `unitCostPrice` — that field is not on any
 * DTO this sprint (sprint-12-plan Task 02 Assumption 3; the admin order
 * detail is not a margin view).
 */
export function OrderItemsTable({ items }: OrderItemsTableProps): ReactElement {
  return (
    <TableContainer component={Paper}>
      <Table size="small">
        <TableHead>
          <TableRow>
            <TableCell>Product</TableCell>
            <TableCell>Color</TableCell>
            <TableCell>Size</TableCell>
            <TableCell align="right">Unit Price</TableCell>
            <TableCell align="right">Quantity</TableCell>
            <TableCell align="right">Line Total</TableCell>
          </TableRow>
        </TableHead>
        <TableBody>
          {items.map((item) => (
            <TableRow key={item.id}>
              <TableCell>
                <Stack direction="row" spacing={1} alignItems="center">
                  <Avatar src={item.productImageUrl ?? undefined} variant="square">
                    {item.productName.charAt(0)}
                  </Avatar>
                  <span>{item.productName}</span>
                </Stack>
              </TableCell>
              <TableCell>{item.color}</TableCell>
              <TableCell>{item.size}</TableCell>
              <TableCell align="right">{item.unitPrice.toFixed(2)}</TableCell>
              <TableCell align="right">{item.quantity}</TableCell>
              <TableCell align="right">{item.lineTotal.toFixed(2)}</TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </TableContainer>
  );
}
