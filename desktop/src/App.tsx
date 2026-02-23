import type { ReactNode } from "react";
import { useEffect } from "react";
import { Navigate, Route, Routes, HashRouter } from "react-router-dom";

import { LoginPage, SignupPage } from "@/pages/auth";
import { DashboardPage } from "@/pages/dashboard";
import { Titlebar } from "@/components/layout";
import { useKeyboardShortcuts } from "@/hooks";
import { useAuthStore } from "@/stores";

const WINDOW_SIZE_STORAGE_KEY = "notes_window_size";

function ProtectedRoute({ children }: { children: ReactNode }) {
  const isAuthenticated = useAuthStore((state) => state.isAuthenticated);

  if (!isAuthenticated) {
    return <Navigate to="/login" replace />;
  }

  return children;
}

function PublicRoute({ children }: { children: ReactNode }) {
  const isAuthenticated = useAuthStore((state) => state.isAuthenticated);

  if (isAuthenticated) {
    return <Navigate to="/" replace />;
  }

  return children;
}

function App() {
  useKeyboardShortcuts();

  useEffect(() => {
    let cleanup: (() => void) | undefined;

    async function setupWindowSizePersistence() {
      try {
        const { getCurrentWindow, LogicalSize } = await import("@tauri-apps/api/window");
        const appWindow = getCurrentWindow();

        const savedRaw = localStorage.getItem(WINDOW_SIZE_STORAGE_KEY);
        if (savedRaw) {
          const saved = JSON.parse(savedRaw) as { width?: number; height?: number };
          if (
            typeof saved.width === "number" &&
            typeof saved.height === "number" &&
            saved.width > 0 &&
            saved.height > 0
          ) {
            await appWindow.setSize(new LogicalSize(saved.width, saved.height));
          }
        }

        const persistSize = async () => {
          const size = await appWindow.innerSize();
          localStorage.setItem(
            WINDOW_SIZE_STORAGE_KEY,
            JSON.stringify({ width: size.width, height: size.height }),
          );
        };

        const unlistenResize = await appWindow.onResized(() => {
          void persistSize();
        });
        const unlistenClose = await appWindow.onCloseRequested(() => {
          void persistSize();
        });

        cleanup = () => {
          unlistenResize();
          unlistenClose();
        };
      } catch {
        // Non-Tauri runtime (e.g. browser preview)
      }
    }

    void setupWindowSizePersistence();

    return () => {
      cleanup?.();
    };
  }, []);

  return (
    <HashRouter>
      <div className="flex bg-background text-text h-screen w-full flex-col overflow-hidden">
        <Titlebar title="Notes" />
        <Routes>
          <Route
            path="/"
            element={
              <ProtectedRoute>
                <DashboardPage />
              </ProtectedRoute>
            }
          />
          <Route
            path="/login"
            element={
              <PublicRoute>
                <LoginPage />
              </PublicRoute>
            }
          />
          <Route
            path="/signup"
            element={
              <PublicRoute>
                <SignupPage />
              </PublicRoute>
            }
          />
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </div>
    </HashRouter>
  );
}

export default App;
