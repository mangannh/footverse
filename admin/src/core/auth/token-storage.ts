const ACCESS_TOKEN_KEY = 'auth.access_token';
const REFRESH_TOKEN_KEY = 'auth.refresh_token';

/**
 * The token wrapper contract — the React analog of the Flutter `TokenStorage`
 * (react-guidelines §Authentication). Injected into the auth interceptor so the
 * dependency is explicit and mockable.
 */
export interface TokenStorage {
  saveTokens(accessToken: string, refreshToken: string): void;
  readAccessToken(): string | null;
  readRefreshToken(): string | null;
  clearTokens(): void;
}

/**
 * The sole reader and writer of the persisted access/refresh token pair over
 * `localStorage` (react-guidelines §Authentication / §Security Rules).
 *
 * No component, hook, or repository touches `localStorage` directly — they go
 * through this wrapper. It stores exactly the two tokens and nothing else: no
 * TTL and no expiry. The access-token lifetime is carried by
 * `AuthResponse.expiresIn` (dto-spec §6) and handled by the auth layer, never
 * persisted here.
 */
export const tokenStorage: TokenStorage = {
  saveTokens(accessToken, refreshToken) {
    localStorage.setItem(ACCESS_TOKEN_KEY, accessToken);
    localStorage.setItem(REFRESH_TOKEN_KEY, refreshToken);
  },

  readAccessToken() {
    return localStorage.getItem(ACCESS_TOKEN_KEY);
  },

  readRefreshToken() {
    return localStorage.getItem(REFRESH_TOKEN_KEY);
  },

  clearTokens() {
    localStorage.removeItem(ACCESS_TOKEN_KEY);
    localStorage.removeItem(REFRESH_TOKEN_KEY);
  },
};
