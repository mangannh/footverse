import {
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
  type ReactElement,
  type ReactNode,
} from 'react';

import { tokenStorage } from '@/core/auth/token-storage';
import { AppError } from '@/core/error/app-error';

import { SessionContext, type SessionContextValue } from './session-context';
import type { LoginRequest } from '../models/login-request';
import type { Role } from '../models/role';
import type { UserResponse } from '../models/user-response';
import type { AuthRepository } from '../repositories/auth-repository';

const ADMIN_ROLE: Role = 'ADMIN';
const NON_ADMIN_MESSAGE = 'This account is not authorized to access the admin panel.';

interface SessionProviderProps {
  readonly authRepository: AuthRepository;
  readonly children: ReactNode;
}

/**
 * Owns the signed-in state machine — the React analog of the Flutter
 * `AuthProvider` (react-guidelines §Context / §Authentication).
 *
 * It drives login / logout through the injected [AuthRepository], persisting the
 * token pair through the token wrapper only (never touching `localStorage`
 * directly). It performs no navigation; the router redirects off the session
 * state (Task 03). The client-side ADMIN gate is presentation only — the server
 * stays authoritative (every admin endpoint `403`s a non-ADMIN token).
 *
 * On mount it restores the session from a persisted access token: with no
 * token it stays signed out; with a token it calls `GET /users/me` (the
 * backend is the source of truth — no JWT is decoded) and either hydrates
 * [user] on success or clears the token pair and stays signed out on failure
 * (an expired/invalid token, already given a refresh attempt by the Task 01
 * auth interceptor). [isInitializing] is true until this settles, so a guard
 * reading it never redirects a signed-in visitor before their session is
 * restored.
 */
export function SessionProvider({ authRepository, children }: SessionProviderProps): ReactElement {
  const [user, setUser] = useState<UserResponse | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [isInitializing, setIsInitializing] = useState(true);
  // Single-flight guard: synchronous so a rapid second submit is a no-op before
  // the `isSubmitting` state has propagated.
  const loginInFlight = useRef(false);

  useEffect(() => {
    const accessToken = tokenStorage.readAccessToken();
    if (accessToken === null) {
      setIsInitializing(false);
      return;
    }
    // Guards against setting state after this provider is gone (the
    // Flutter `_disposed` precedent) — SessionProvider lives for the app's
    // lifetime, but the guard is cheap and keeps the idiom consistent.
    let cancelled = false;
    authRepository
      .getCurrentUser()
      .then((currentUser) => {
        if (!cancelled) {
          setUser(currentUser);
        }
      })
      .catch(() => {
        tokenStorage.clearTokens();
      })
      .finally(() => {
        if (!cancelled) {
          setIsInitializing(false);
        }
      });
    return () => {
      cancelled = true;
    };
  }, [authRepository]);

  const login = useCallback(
    async (request: LoginRequest): Promise<void> => {
      if (loginInFlight.current) {
        return;
      }
      loginInFlight.current = true;
      setIsSubmitting(true);
      try {
        const auth = await authRepository.login(request);
        if (auth.user.role !== ADMIN_ROLE) {
          // Client-side ADMIN gate: reject before any admin call, tokens cleared.
          tokenStorage.clearTokens();
          throw new AppError({ message: NON_ADMIN_MESSAGE });
        }
        tokenStorage.saveTokens(auth.accessToken, auth.refreshToken);
        setUser(auth.user);
      } finally {
        loginInFlight.current = false;
        setIsSubmitting(false);
      }
    },
    [authRepository],
  );

  const logout = useCallback(async (): Promise<void> => {
    const refreshToken = tokenStorage.readRefreshToken();
    try {
      if (refreshToken !== null) {
        await authRepository.logout({ refreshToken });
      }
    } catch {
      // Server-side revocation is best-effort; local sign-out always proceeds.
    } finally {
      tokenStorage.clearTokens();
      setUser(null);
    }
  }, [authRepository]);

  const value = useMemo<SessionContextValue>(
    () => ({ user, isAuthenticated: user !== null, isSubmitting, isInitializing, login, logout }),
    [user, isSubmitting, isInitializing, login, logout],
  );

  return <SessionContext.Provider value={value}>{children}</SessionContext.Provider>;
}
