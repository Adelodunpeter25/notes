import { defineConfig } from 'vite';
import { cloudflare } from '@cloudflare/vite-plugin';

const r = (p: string) => new URL(p, import.meta.url).pathname;

export default defineConfig({
  plugins: [cloudflare()],
  resolve: {
    alias: {
      '@db': r('./db'),
      '@services': r('./services'),
      '@routes': r('./routes'),
      '@custom-types': r('./types'),
      '@middleware': r('./middleware'),
    },
  },
});
