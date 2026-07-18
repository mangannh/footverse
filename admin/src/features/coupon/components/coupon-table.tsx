import {
  Button,
  Paper,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
} from '@mui/material';
import type { ReactElement } from 'react';

import type { CouponResponse } from '../models/coupon-response';
import { getCouponStatus } from '../utils/coupon-status';

interface CouponTableProps {
  readonly coupons: readonly CouponResponse[];
  onEdit(coupon: CouponResponse): void;
}

function formatDateTime(value: string): string {
  return value.replace('T', ' ').slice(0, 16);
}

function formatDiscount(coupon: CouponResponse): string {
  return coupon.discountType === 'PERCENT'
    ? `${coupon.discountValue}%`
    : coupon.discountValue.toFixed(2);
}

/**
 * The coupon list table — presentational only (react-guidelines §Component
 * Rules), mirroring `BrandTable` (Sprint 10). It renders the page of coupons
 * the caller supplies — including the server-managed `usedCount` — and
 * reports edit intent upward; it holds no state, calls no repository, and
 * decides nothing. There is no delete action: coupons have no delete
 * endpoint (a coupon is retired by editing `enabled = false`).
 */
export function CouponTable({ coupons, onEdit }: CouponTableProps): ReactElement {
  return (
    <TableContainer component={Paper}>
      <Table size="small">
        <TableHead>
          <TableRow>
            <TableCell>Code</TableCell>
            <TableCell>Name</TableCell>
            <TableCell>Discount</TableCell>
            <TableCell align="right">Min Order</TableCell>
            <TableCell>Start</TableCell>
            <TableCell>End</TableCell>
            <TableCell align="right">Used</TableCell>
            <TableCell>Status</TableCell>
            <TableCell align="right">Actions</TableCell>
          </TableRow>
        </TableHead>
        <TableBody>
          {coupons.map((coupon) => (
            <TableRow key={coupon.id}>
              <TableCell>{coupon.code}</TableCell>
              <TableCell>{coupon.name}</TableCell>
              <TableCell>{formatDiscount(coupon)}</TableCell>
              <TableCell align="right">{coupon.minOrderAmount.toFixed(2)}</TableCell>
              <TableCell>{formatDateTime(coupon.startAt)}</TableCell>
              <TableCell>{formatDateTime(coupon.endAt)}</TableCell>
              <TableCell align="right">
                {coupon.usedCount}
                {coupon.usageLimit !== undefined && coupon.usageLimit !== null
                  ? ` / ${coupon.usageLimit}`
                  : ''}
              </TableCell>
              <TableCell>{getCouponStatus(coupon)}</TableCell>
              <TableCell align="right">
                <Button size="small" onClick={() => onEdit(coupon)}>
                  Edit
                </Button>
              </TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </TableContainer>
  );
}
