import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import { fileURLToPath, URL } from "node:url";

const host = process.env.TAURI_DEV_HOST;

// https://vite.dev/config/
export default defineConfig(async () => ({
  plugins: [react()],
  build: {
    rollupOptions: {
      input: {
        main: fileURLToPath(new URL("./index.html", import.meta.url)),
        "quick-note": fileURLToPath(new URL("./quick-note.html", import.meta.url)),
      },
    },
  },
  resolve: {
    alias: {
      "@": fileURLToPath(new URL("./src", import.meta.url)),
      "@shared": fileURLToPath(new URL("../shared/types", import.meta.url)),
      "@shared-utils": fileURLToPath(new URL("../shared/utils", import.meta.url)),
      "@shared-hooks": fileURLToPath(new URL("../shared/hooks", import.meta.url)),
      clsx: fileURLToPath(new URL("./node_modules/clsx", import.meta.url)),
      "tailwind-merge": fileURLToPath(new URL("./node_modules/tailwind-merge", import.meta.url)),
      "date-fns": fileURLToPath(new URL("./node_modules/date-fns", import.meta.url)),
      "@tanstack/react-query": fileURLToPath(new URL("./node_modules/@tanstack/react-query", import.meta.url)),
      react: fileURLToPath(new URL("./node_modules/react", import.meta.url)),
    },
  },
  optimizeDeps: {
    include: ["clsx", "tailwind-merge", "date-fns"],
  },
  // Vite options tailored for Tauri development and only applied in `tauri dev` or `tauri build`
  //
  // 1. prevent Vite from obscuring rust errors
  clearScreen: false,
  // 2. tauri expects a fixed port, fail if that port is not available
  server: {
    fs: {
      allow: [".."],
    },
    port: 1420,
    strictPort: true,
    host: host || false,
    hmr: host
      ? {
          protocol: "ws",
          host,
          port: 1421,
        }
      : undefined,
    watch: {
      // 3. tell Vite to ignore watching `src-tauri`
      ignored: ["**/src-tauri/**"],
    },
  },
}));
