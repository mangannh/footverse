import { Box, Typography } from '@mui/material';
import type { ReactElement } from 'react';

interface SectionPlaceholderProps {
  readonly title: string;
  readonly description: string;
}

/**
 * A minimal content placeholder rendered inside the shell (react-guidelines
 * §Component Rules). It hosts the empty state before a section is chosen and the
 * not-yet-built Brands / Categories sections; Tasks 04 / 05 replace the section
 * routes with the real feature pages.
 */
export function SectionPlaceholder({ title, description }: SectionPlaceholderProps): ReactElement {
  return (
    <Box>
      <Typography variant="h4" component="h1" gutterBottom>
        {title}
      </Typography>
      <Typography color="text.secondary">{description}</Typography>
    </Box>
  );
}
