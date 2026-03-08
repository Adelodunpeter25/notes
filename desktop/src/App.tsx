import type { ReactNode } from "react";
import { Navigate, Route, Routes, HashRouter } from "react-router-dom";

import { LoginPage, SignupPage } from "@/pages/auth";
import { DashboardPage } from "@/pages/dashboard";
import { Titlebar } from "@/components/layout";
import { useKeyboardShortcuts, useSync, useWindowSizePersist } from "@/hooks";
import { useAuthStore } from "@/stores";

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
  useWindowSizePersist();
  useSync({ auto: true });

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
