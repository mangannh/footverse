import path from 'node:path';

import react from '@vitejs/plugin-react';
import { defineConfig } from 'vitest/config';

// Single Vite + Vitest configuration for the admin panel. The `@` alias mirrors
// the Flutter `package:` import root so `core` / `shared` are imported absolutely.
export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@': path.resolve(import.meta.dirname, 'src'),
    },
  },
  test: {
    environment: 'jsdom',
    // The API base URL is externalised (VITE_API_BASE_URL); tests provide a
    // fixed value so no real URL is hardcoded in source.
    env: {
      VITE_API_BASE_URL: 'http://localhost:8080',
    },
  },
});
