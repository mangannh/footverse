import { AxiosError, type AxiosInstance } from 'axios';

const LOG_PREFIX = '[network]';

/**
 * Installs a dev-only logging interceptor — the React analog of the Flutter
 * `LoggingInterceptor` (react-guidelines §Networking).
 *
 * It is registered only under `import.meta.env.DEV`, so no network logging ships
 * in a production build. It observes traffic only — method, URL, and status —
 * and carries no authentication or business logic. This is the single sanctioned
 * place `console` output is emitted (react-guidelines §Code Style).
 */
export function installLoggingInterceptor(client: AxiosInstance): void {
  if (!import.meta.env.DEV) {
    return;
  }

  client.interceptors.request.use((config) => {
    console.info(`${LOG_PREFIX} --> ${config.method?.toUpperCase() ?? ''} ${config.url ?? ''}`);
    return config;
  });

  client.interceptors.response.use(
    (response) => {
      console.info(`${LOG_PREFIX} <-- ${response.status} ${response.config.url ?? ''}`);
      return response;
    },
    (error: unknown) => {
      const status = error instanceof AxiosError ? error.response?.status : undefined;
      const url = error instanceof AxiosError ? (error.config?.url ?? '') : '';
      console.info(`${LOG_PREFIX} <-- ERROR ${status ?? ''} ${url}`);
      return Promise.reject(error);
    },
  );
}
