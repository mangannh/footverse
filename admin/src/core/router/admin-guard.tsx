import { Box, CircularProgress } from '@mui/material';
import type { ReactElement } from 'react';
import { Navigate, useLocation } from 'react-router-dom';

import { useSession } from '@/features/auth/session/use-session';

import { ROUTES } from './routes';

interface AdminGuardProps {
  readonly children: ReactElement;
}

/**
 * The ADMIN-only route guard — the React analog of the Flutter `go_router`
 * redirect (react-guidelines §Routing).
 *
 * It reads the session only (no business logic, no side effects) and mirrors the
 * Flutter guard's algorithm: an unauthenticated **or** non-ADMIN visitor is
 * redirected to the login route, preserving the intended location so the login
 * route can return them after an ADMIN sign-in. Protected content is never
 * rendered before the redirect. Authorization stays server-enforced; this gate
 * is presentation only.
 *
 * While the session is still being restored ([useSession].`isInitializing`),
 * it renders a loading state instead of deciding — redirecting before restore
 * settles would flash a signed-in visitor to the login screen on every reload.
 */
export function AdminGuard({ children }: AdminGuardProps): ReactElement {
  const { user, isAuthenticated, isInitializing } = useSession();
  const location = useLocation();

  if (isInitializing) {
    return (
      <Box
        sx={{ display: 'flex', justifyContent: 'center', alignItems: 'center', minHeight: '100vh' }}
      >
        <CircularProgress />
      </Box>
    );
  }

  const isAdmin = isAuthenticated && user?.role === 'ADMIN';
  if (!isAdmin) {
    return <Navigate to={ROUTES.login} replace state={{ from: location }} />;
  }
  return children;
}
