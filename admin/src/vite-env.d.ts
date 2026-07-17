/// <reference types="vite/client" />

interface ImportMetaEnv {
  /** Base URL of the FootVerse backend API (react-guidelines §Networking). */
  readonly VITE_API_BASE_URL: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
