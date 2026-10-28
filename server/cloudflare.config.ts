import { bindings, defineConfig } from 'cf/config';

import * as entrypoint from './index.ts' with { type: 'cf-worker' };

export default defineConfig({
  worker: {
    name: 'notes-api',
    entrypoint,
    compatibilityDate: '2026-09-01',
    compatibilityFlags: ['nodejs_compat'],
    observability: { enabled: true },
    env: {
      TURSO_DATABASE_URL: bindings.secret(),
      TURSO_AUTH_TOKEN: bindings.secret(),
      JWT_SECRET: bindings.secret(),
    },
  },
});
