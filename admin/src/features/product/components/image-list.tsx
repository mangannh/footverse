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

import type { ProductImageResponse } from '../models/product-image-response';

interface ImageListProps {
  readonly images: readonly ProductImageResponse[];
  /** True while a mutation is in flight (disables every action). */
  readonly disabled: boolean;
  onAdd(): void;
  onEdit(image: ProductImageResponse): void;
}

/**
 * The product's image section — presentational only (react-guidelines
 * §Component Rules). It renders the images the caller supplies — including
 * the server-decided primary marker — and reports add / edit intent upward.
 * There is no delete affordance; an image is replaced by editing it. The
 * one-primary-per-product invariant is server-enforced: this component never
 * recomputes which image is primary, it only renders what the server last
 * returned.
 */
export function ImageList({ images, disabled, onAdd, onEdit }: ImageListProps): ReactElement {
  return (
    <Box sx={{ mt: 4 }}>
      <Stack direction="row" justifyContent="space-between" alignItems="center" sx={{ mb: 2 }}>
        <Typography variant="h6" component="h2">
          Images
        </Typography>
        <Button variant="outlined" disabled={disabled} onClick={onAdd}>
          Add image
        </Button>
      </Stack>

      {images.length === 0 && (
        <Typography color="text.secondary">No images yet — add one.</Typography>
      )}

      {images.length > 0 && (
        <TableContainer component={Paper}>
          <Table size="small">
            <TableHead>
              <TableRow>
                <TableCell>Image URL</TableCell>
                <TableCell align="right">Order</TableCell>
                <TableCell>Primary</TableCell>
                <TableCell align="right">Actions</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {images.map((image) => (
                <TableRow key={image.id}>
                  <TableCell>{image.imageUrl}</TableCell>
                  <TableCell align="right">{image.displayOrder}</TableCell>
                  <TableCell>{image.isPrimary ? 'Primary' : '—'}</TableCell>
                  <TableCell align="right">
                    <Button size="small" disabled={disabled} onClick={() => onEdit(image)}>
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
