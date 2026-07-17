import axios from 'axios';

import { tokenStorage } from '@/core/auth/token-storage';
import { appConfig } from '@/core/config/app-config';
import { ROUTES } from '@/core/router/routes';

import { installAuthInterceptor } from './auth-interceptor';
import { installErrorInterceptor } from './error-interceptor';
import { installLoggingInterceptor } from './logging-interceptor';

/**
 * The single Axios instance shared across the admin panel — the React analog of
 * the single Flutter `Dio` (react-guidelines §Networking). No component, hook,
 * or repository constructs its own instance; every HTTP call goes through this
 * one, configured with the externalised base URL.
 *
 * Interceptors are registered in order so each runs in its intended place: the
 * auth interceptor gets the first attempt at a `401` (refresh-and-retry), and
 * the error interceptor maps any final rejection to `AppError` last.
 */
export const httpClient = axios.create({
  baseURL: appConfig.apiBaseUrl,
  headers: { 'Content-Type': 'application/json' },
});

installLoggingInterceptor(httpClient);
installAuthInterceptor(httpClient, {
  tokenStorage,
  onSessionExpired: () => {
    window.location.assign(ROUTES.login);
  },
});
installErrorInterceptor(httpClient);
