import React from "react";
import ReactDOM from "react-dom/client";
import { QueryClientProvider } from "@tanstack/react-query";

import App from "@/App";
import { queryClient } from "@/services/queryClient";
import "@/animations.css";
import "@/styles.css";

// Polyfill for WebKit (Tauri/macOS WKWebView): `new CSSStyleSheet()` is not
// supported, but react-resizable-panels v4 uses Constructable Stylesheets.
// Fall back to a <style> element so the constructor never throws.
if (typeof CSSStyleSheet !== "undefined") {
  try {
    new CSSStyleSheet();
  } catch {
    const OriginalCSSStyleSheet = CSSStyleSheet;
    // @ts-expect-error – patching the global for WebKit compatibility
    window.CSSStyleSheet = class PatchedCSSStyleSheet extends OriginalCSSStyleSheet {
      constructor() {
        const style = document.createElement("style");
        document.head.appendChild(style);
        return style.sheet as unknown as CSSStyleSheet;
      }
    };
  }
}

document.documentElement.classList.add("dark");

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <QueryClientProvider client={queryClient}>
      <App />
    </QueryClientProvider>
  </React.StrictMode>,
);
