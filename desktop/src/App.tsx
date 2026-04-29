import { type ReactNode, useState } from "react";
import { Navigate, Route, Routes, HashRouter } from "react-router-dom";

import { LoginPage, SignupPage } from "@/pages/auth";
import { DashboardPage } from "@/pages/dashboard";
import { Titlebar } from "@/components/layout";
import { SearchModal } from "@/components/search";
import { SettingsModal } from "@/components/common/SettingsModal";
import { useKeyboardShortcuts, useWindowSizePersist, useSync } from "@/hooks";
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
  const { syncNow, isSyncing, resetSyncCursor } = useSync({ auto: true });
  const [settingsOpen, setSettingsOpen] = useState(false);

  return (
    <HashRouter>
      <div className="flex bg-background text-text h-screen w-full flex-col overflow-hidden">
        <Titlebar
          syncNow={syncNow}
          isSyncing={isSyncing}
          onSettingsOpen={() => setSettingsOpen(true)}
        />
        <SearchModal />
        <SettingsModal
          isOpen={settingsOpen}
          onClose={() => setSettingsOpen(false)}
          onResetSyncCursor={resetSyncCursor}
          onSyncNow={syncNow}
          isSyncing={isSyncing}
        />
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

