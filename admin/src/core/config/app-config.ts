/**
 * Application configuration resolved at build/run time — the analog of the
 * Flutter `AppConfig` (flutter-guidelines §Configuration).
 *
 * The API base URL is supplied per environment via `VITE_API_BASE_URL` (read
 * through `import.meta.env`); no URL is hardcoded in the app. It is the single
 * place the base URL is read.
 */
interface AppConfig {
  readonly apiBaseUrl: string;
}

export const appConfig: AppConfig = {
  apiBaseUrl: import.meta.env.VITE_API_BASE_URL,
};
