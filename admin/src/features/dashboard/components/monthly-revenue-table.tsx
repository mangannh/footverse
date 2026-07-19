import {
  Box,
  Paper,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
} from '@mui/material';
import type { ReactElement } from 'react';

import type { MonthlyRevenueResponse } from '../models/monthly-revenue-response';
import { formatMonthLabel, toBarPercentages } from '../utils/dashboard-format';

interface MonthlyRevenueTableProps {
  readonly rows: readonly MonthlyRevenueResponse[];
}

/**
 * The dashboard's trailing twelve-month revenue series, rendered exactly in
 * the order the server sent it — oldest to newest (sprint-13-plan Task 03).
 * Each row's bar is built from a plain MUI `Box`, sized by the pure
 * {@link toBarPercentages} helper — **no charting library** (Design
 * Decision 9). The bar is a visual aid only: the month label, the exact
 * revenue, and the order count are always readable as text beside it, so no
 * figure is ever encoded by bar length or colour alone.
 */
export function MonthlyRevenueTable({ rows }: MonthlyRevenueTableProps): ReactElement {
  const percentages = toBarPercentages(rows.map((row) => row.revenue));

  return (
    <TableContainer component={Paper}>
      <Table size="small">
        <TableHead>
          <TableRow>
            <TableCell>Month</TableCell>
            <TableCell align="right">Revenue</TableCell>
            <TableCell align="right">Orders</TableCell>
            <TableCell sx={{ width: 200 }}>Trend</TableCell>
          </TableRow>
        </TableHead>
        <TableBody>
          {rows.map((row, index) => (
            <TableRow key={`${row.year}-${row.month}`}>
              <TableCell>{formatMonthLabel(row.year, row.month)}</TableCell>
              <TableCell align="right">{row.revenue.toFixed(2)}</TableCell>
              <TableCell align="right">{row.orderCount}</TableCell>
              <TableCell>
                <Box sx={{ bgcolor: 'action.hover', borderRadius: 1, height: 8, width: '100%' }}>
                  <Box
                    sx={{
                      bgcolor: 'primary.main',
                      borderRadius: 1,
                      height: 8,
                      width: `${percentages[index] ?? 0}%`,
                    }}
                  />
                </Box>
              </TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </TableContainer>
  );
}
