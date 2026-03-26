import { useState } from "react";
import { Settings, X, RefreshCw, LogOut } from "lucide-react";
import { useAuthStore } from "@/stores";

type SettingsModalProps = {
  isOpen: boolean;
  onClose: () => void;
  onResetSyncCursor: () => void;
  onSyncNow: () => Promise<void> | void;
  isSyncing: boolean;
};

export function SettingsModal({
  isOpen,
  onClose,
  onResetSyncCursor,
  onSyncNow,
  isSyncing,
}: SettingsModalProps) {
  const clearAuth = useAuthStore((state) => state.clearAuth);
  const [resetDone, setResetDone] = useState(false);

  if (!isOpen) return null;

  const handleResetSyncTime = async () => {
    onResetSyncCursor();
    setResetDone(true);
    // Auto-trigger sync after reset
    await onSyncNow();
    setTimeout(() => setResetDone(false), 3000);
  };

  const handleLogout = () => {
    clearAuth();
    onClose();
  };

  return (
    <div
      className="fixed inset-0 z-[100] flex items-center justify-center bg-black/50"
      onClick={onClose}
    >
      <div
        className="w-[360px] rounded-xl border border-border bg-[#1e1e1e] shadow-2xl"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Header */}
        <div className="flex items-center justify-between border-b border-border px-5 py-3">
          <div className="flex items-center gap-2">
            <Settings size={16} className="text-muted" />
            <span className="text-sm font-semibold text-text">Settings</span>
          </div>
          <button
            onClick={onClose}
            className="flex size-6 items-center justify-center rounded-md text-muted transition-colors hover:bg-white/10 hover:text-text"
          >
            <X size={14} />
          </button>
        </div>

        {/* Content */}
        <div className="p-5 space-y-5">
          {/* Sync Section */}
          <div>
            <p className="mb-2.5 text-[11px] font-semibold uppercase tracking-wider text-muted">
              Sync
            </p>
            <button
              onClick={handleResetSyncTime}
              disabled={isSyncing}
              className="flex w-full items-center gap-3 rounded-lg border border-border/60 bg-[#2a2a2a] px-3.5 py-3 text-left transition-colors hover:border-border hover:bg-[#333] disabled:opacity-50"
            >
              <div className="flex size-8 items-center justify-center rounded-md bg-accent/15">
                <RefreshCw
                  size={14}
                  className={isSyncing ? "animate-spin text-accent" : "text-accent"}
                />
              </div>
              <div className="flex-1">
                <p className="text-[13px] font-medium text-text">
                  Reset Last Sync Time
                </p>
                <p className="text-[11px] text-muted">
                  {resetDone
                    ? "✓ Cursor cleared — full sync triggered"
                    : "Clear cursor so next sync pushes all data"}
                </p>
              </div>
            </button>
          </div>

          {/* Account Section */}
          <div>
            <p className="mb-2.5 text-[11px] font-semibold uppercase tracking-wider text-muted">
              Account
            </p>
            <button
              onClick={handleLogout}
              className="flex w-full items-center gap-3 rounded-lg border border-red-500/30 bg-red-500/10 px-3.5 py-3 text-left transition-colors hover:bg-red-500/20"
            >
              <div className="flex size-8 items-center justify-center rounded-md bg-red-500/15">
                <LogOut size={14} className="text-red-400" />
              </div>
              <p className="text-[13px] font-medium text-red-400">Log Out</p>
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
