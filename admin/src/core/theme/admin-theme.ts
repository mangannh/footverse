import { createTheme } from '@mui/material/styles';

/**
 * The single central theme for the admin panel (react-guidelines §Theme Rules) —
 * the React analog of the Flutter Material 3 `ThemeData` seeded from
 * `AppColors.seed`. Brand colours are defined here once; pages and components
 * reference the theme rather than hardcoding values.
 *
 * Light mode only for V1 — no dark theme this sprint (mirrors the Flutter V1
 * scope).
 */
const BRAND_SEED = '#2E7D32';

export const adminTheme = createTheme({
  palette: {
    mode: 'light',
    primary: { main: BRAND_SEED },
  },
});
