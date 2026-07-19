import { Card, CardContent, Typography } from '@mui/material';
import type { ReactElement } from 'react';

interface KpiCardProps {
  readonly label: string;
  readonly value: string;
  readonly caveat?: string;
}

/**
 * One headline figure with its label — the dashboard's smallest building
 * block (sprint-13-plan Task 03), reused for total revenue, total orders,
 * gross profit, and each of the five per-status order counts.
 * Presentational only (react-guidelines §Component Rules): it renders
 * exactly the string it is given and performs no formatting or computation
 * of its own — every figure already comes from the server, formatted by the
 * page.
 *
 * `caveat`, when supplied, renders as visible supporting text directly
 * beneath the value — never a tooltip, hidden text, or a footnote
 * (sprint-13-plan Task 03 UX Requirements). Used only by the Gross Profit
 * card, and only when the server's profit figure does not cover every
 * delivered order line.
 */
export function KpiCard({ label, value, caveat }: KpiCardProps): ReactElement {
  return (
    <Card variant="outlined">
      <CardContent>
        <Typography color="text.secondary" gutterBottom>
          {label}
        </Typography>
        <Typography variant="h5" component="div">
          {value}
        </Typography>
        {caveat !== undefined && (
          <Typography variant="body2" color="warning.main" sx={{ mt: 1 }}>
            {caveat}
          </Typography>
        )}
      </CardContent>
    </Card>
  );
}
