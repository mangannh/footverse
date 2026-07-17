import type { ReactElement } from 'react';
import { Navigate, useLocation, type Location } from 'react-router-dom';

import { LoginPage } from '@/features/auth/pages/login-page';
import { useSession } from '@/features/auth/session/use-session';

import { ROUTES } from './routes';

/**
 * The login route element. It mirrors the second half of the Flutter router
 * guard: an already-signed-in ADMIN on the login screen is redirected to the
 * intended location (`from`, preserved by the `AdminGuard`) or the shell root.
 * Otherwise it renders the login page.
 */
export function LoginRoute(): ReactElement {
  const { user, isAuthenticated } = useSession();
  const location = useLocation();

  if (isAuthenticated && user?.role === 'ADMIN') {
    const from = (location.state as { from?: Location } | null)?.from;
    const target = from ? `${from.pathname}${from.search}` : ROUTES.root;
    return <Navigate to={target} replace />;
  }
  return <LoginPage />;
}
