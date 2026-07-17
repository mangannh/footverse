import { CssBaseline, ThemeProvider } from '@mui/material';
import type { ReactElement } from 'react';
import { RouterProvider } from 'react-router-dom';

import { httpClient } from '@/core/api/http-client';
import { router } from '@/core/router';
import { adminTheme } from '@/core/theme/admin-theme';
import { AuthRepository } from '@/features/auth/repositories/auth-repository';
import { SessionProvider } from '@/features/auth/session/session-provider';

// Composition root: construct the auth repository against the single Axios
// instance and inject it into the session, the React analog of the Flutter
// `main.dart` wiring.
const authRepository = new AuthRepository(httpClient);

/**
 * Application root. It wires the MUI theme, the session, and the router —
 * `SessionProvider` outside `RouterProvider` so every routed component (the
 * guard, the login route, the shell) can read the session.
 */
export function App(): ReactElement {
  return (
    <ThemeProvider theme={adminTheme}>
      <CssBaseline />
      <SessionProvider authRepository={authRepository}>
        <RouterProvider router={router} />
      </SessionProvider>
    </ThemeProvider>
  );
}
