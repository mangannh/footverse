import { AxiosError, type AxiosInstance, type InternalAxiosRequestConfig } from 'axios';

import type { TokenStorage } from '@/core/auth/token-storage';
import type { ApiResponse } from '@/shared/types/api-response';

const AUTHORIZATION_HEADER = 'Authorization';
const REFRESH_PATH = '/api/v1/auth/refresh';

interface AuthInterceptorDeps {
  readonly tokenStorage: TokenStorage;
  /** Signals the signed-out state after a failed refresh (the router redirects). */
  readonly onSessionExpired: () => void;
}

/** The subset of the rotated token pair the refresh response carries. */
interface RefreshedTokens {
  readonly accessToken: string;
  readonly refreshToken: string;
}

/** Request config flagged once it has been retried, so it never re-refreshes. */
interface RetriableConfig extends InternalAxiosRequestConfig {
  retried?: boolean;
}

/**
 * Installs the auth interceptor — the React analog of the Flutter
 * `AuthInterceptor` (react-guidelines §Networking; security-spec §1).
 *
 * On every request it attaches `Authorization: Bearer <accessToken>` from the
 * token wrapper. On a `401` it refreshes the token pair **once** via
 * `POST /auth/refresh`, saves the rotated pair, and retries the original request
 * **once**; a failed refresh clears the tokens and signals the signed-out state
 * through [AuthInterceptorDeps.onSessionExpired].
 *
 * The refresh is **single-flight**: concurrent `401`s share one in-flight
 * refresh via [ongoingRefresh]. No refresh loop can occur — the auth endpoints
 * are never refreshed and a request that has already been retried is terminal.
 * A single Axios instance is used throughout (sprint-10-plan Task 01); the
 * auth-endpoint guard, not a second instance, prevents re-entrancy.
 */
export function installAuthInterceptor(client: AxiosInstance, deps: AuthInterceptorDeps): void {
  const { tokenStorage, onSessionExpired } = deps;

  // The single in-flight refresh; null when none is running.
  let ongoingRefresh: Promise<string | null> | null = null;

  client.interceptors.request.use((config) => {
    const accessToken = tokenStorage.readAccessToken();
    if (accessToken !== null) {
      config.headers.set(AUTHORIZATION_HEADER, `Bearer ${accessToken}`);
    }
    return config;
  });

  client.interceptors.response.use(
    (response) => response,
    async (error: unknown) => {
      if (!(error instanceof AxiosError)) {
        return Promise.reject(error);
      }
      const config = error.config as RetriableConfig | undefined;
      if (config === undefined || !shouldRefresh(error, config)) {
        return Promise.reject(error);
      }

      const newAccessToken = await refreshSession();
      if (newAccessToken === null) {
        // Tokens are already cleared and the signed-out state is signalled.
        // Propagate the original error; never retry.
        return Promise.reject(error);
      }

      config.retried = true;
      return client(config);
    },
  );

  function shouldRefresh(error: AxiosError, config: RetriableConfig): boolean {
    if (error.response?.status !== 401) {
      return false;
    }
    if (config.retried === true) {
      return false;
    }
    return !isAuthEndpoint(config.url ?? '');
  }

  function isAuthEndpoint(url: string): boolean {
    return (
      url.endsWith('/auth/login') || url.endsWith('/auth/refresh') || url.endsWith('/auth/logout')
    );
  }

  /**
   * Returns the shared in-flight refresh, starting one only if none is running
   * (single-flight). The slot is cleared on completion so a later, genuinely
   * separate cycle can refresh again.
   */
  function refreshSession(): Promise<string | null> {
    if (ongoingRefresh !== null) {
      return ongoingRefresh;
    }
    const refresh = performRefresh();
    ongoingRefresh = refresh;
    void refresh.finally(() => {
      ongoingRefresh = null;
    });
    return refresh;
  }

  async function performRefresh(): Promise<string | null> {
    const refreshToken = tokenStorage.readRefreshToken();
    if (refreshToken === null) {
      signOut();
      return null;
    }
    try {
      const response = await client.post<ApiResponse<RefreshedTokens>>(REFRESH_PATH, {
        refreshToken,
      });
      const tokens = response.data.data;
      if (tokens === undefined || tokens === null) {
        signOut();
        return null;
      }
      tokenStorage.saveTokens(tokens.accessToken, tokens.refreshToken);
      return tokens.accessToken;
    } catch {
      signOut();
      return null;
    }
  }

  function signOut(): void {
    tokenStorage.clearTokens();
    onSessionExpired();
  }
}
