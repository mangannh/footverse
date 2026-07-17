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

import type { BrandResponse } from '../models/brand-response';

interface BrandTableProps {
  readonly brands: readonly BrandResponse[];
  /** True while a mutation is in flight (disables every row action). */
  readonly disabled: boolean;
  onEdit(brand: BrandResponse): void;
  onDeleteRequest(brand: BrandResponse): void;
}

/**
 * The brand list table — presentational only (react-guidelines §Component
 * Rules). It renders the rows the caller supplies and reports edit / delete
 * intent upward; it holds no state, calls no repository, and decides nothing.
 */
export function BrandTable({
  brands,
  disabled,
  onEdit,
  onDeleteRequest,
}: BrandTableProps): ReactElement {
  return (
    <TableContainer component={Paper}>
      <Table>
        <TableHead>
          <TableRow>
            <TableCell>Name</TableCell>
            <TableCell>Logo URL</TableCell>
            <TableCell>Description</TableCell>
            <TableCell align="right">Actions</TableCell>
          </TableRow>
        </TableHead>
        <TableBody>
          {brands.map((brand) => (
            <TableRow key={brand.id}>
              <TableCell>{brand.name}</TableCell>
              <TableCell>{brand.logoUrl ?? '—'}</TableCell>
              <TableCell>{brand.description ?? '—'}</TableCell>
              <TableCell align="right">
                <Stack direction="row" spacing={1} justifyContent="flex-end">
                  <Button size="small" disabled={disabled} onClick={() => onEdit(brand)}>
                    Edit
                  </Button>
                  <Button
                    size="small"
                    color="error"
                    disabled={disabled}
                    onClick={() => onDeleteRequest(brand)}
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
