import React from "react";
import ReactDOM from "react-dom/client";
import { QueryClientProvider } from "@tanstack/react-query";

import { QuickNoteApp } from "@/components/quick-note/QuickNoteApp";
import { queryClient } from "@/services/queryClient";
import "@/animations.css";
import "@/styles.css";

document.documentElement.classList.add("dark");

ReactDOM.createRoot(document.getElementById("quick-note-root")!).render(
  <React.StrictMode>
    <QueryClientProvider client={queryClient}>
      <QuickNoteApp />
    </QueryClientProvider>
  </React.StrictMode>,
);
