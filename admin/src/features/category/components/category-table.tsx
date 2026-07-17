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

import type { CategoryResponse } from '../models/category-response';

interface CategoryTableProps {
  readonly categories: readonly CategoryResponse[];
  /** True while a mutation is in flight (disables every row action). */
  readonly disabled: boolean;
  onEdit(category: CategoryResponse): void;
  onDeleteRequest(category: CategoryResponse): void;
}

/**
 * The category list table — presentational only (react-guidelines §Component
 * Rules). Mirrors `BrandTable` (Task 04) verbatim, minus the `logoUrl` column
 * (category has no `logoUrl`). It renders the rows the caller supplies and
 * reports edit / delete intent upward; it holds no state, calls no repository,
 * and decides nothing.
 */
export function CategoryTable({
  categories,
  disabled,
  onEdit,
  onDeleteRequest,
}: CategoryTableProps): ReactElement {
  return (
    <TableContainer component={Paper}>
      <Table>
        <TableHead>
          <TableRow>
            <TableCell>Name</TableCell>
            <TableCell>Description</TableCell>
            <TableCell align="right">Actions</TableCell>
          </TableRow>
        </TableHead>
        <TableBody>
          {categories.map((category) => (
            <TableRow key={category.id}>
              <TableCell>{category.name}</TableCell>
              <TableCell>{category.description ?? '—'}</TableCell>
              <TableCell align="right">
                <Stack direction="row" spacing={1} justifyContent="flex-end">
                  <Button size="small" disabled={disabled} onClick={() => onEdit(category)}>
                    Edit
                  </Button>
                  <Button
                    size="small"
                    color="error"
                    disabled={disabled}
                    onClick={() => onDeleteRequest(category)}
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
