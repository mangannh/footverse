import { createContext } from 'react';

import type { LoginRequest } from '../models/login-request';
import type { UserResponse } from '../models/user-response';

/** The signed-in session state and its actions (react-guidelines §Context). */
export interface SessionContextValue {
  /** The authenticated user, or null when signed out. */
  readonly user: UserResponse | null;
  /** True while a user is signed in. */
  readonly isAuthenticated: boolean;
  /** True while a login request is in flight (drives the submit button). */
  readonly isSubmitting: boolean;
  /**
   * True while the session is being restored from a persisted token at app
   * startup. The guard waits for this to settle before deciding to redirect, so
   * a signed-in visitor is never flashed to the login screen on reload.
   */
  readonly isInitializing: boolean;
  /** Signs in; on a non-ADMIN account clears tokens and throws `AppError`. */
  login(request: LoginRequest): Promise<void>;
  /** Signs out: revokes the refresh token server-side, then always clears locally. */
  logout(): Promise<void>;
}

/**
 * The app-root session Context. It lives in its own module (not the provider
 * file) so React Fast Refresh treats the provider as a pure component boundary.
 */
export const SessionContext = createContext<SessionContextValue | null>(null);
