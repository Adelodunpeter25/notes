import { useCallback, useEffect, useRef, useState } from "react";
import { useQueryClient } from "@tanstack/react-query";

import { runSyncCycle } from "@/db";
import { useAuthStore } from "@/stores";

const SYNC_INTERVAL_MS = 10_000;
let activeSync: Promise<void> | null = null;

export function useSync(options?: { auto?: boolean }) {
  const auto = options?.auto ?? true;
  const token = useAuthStore((state) => state.token);
  const isAuthenticated = useAuthStore((state) => state.isAuthenticated);
  const queryClient = useQueryClient();
  const [isSyncing, setIsSyncing] = useState(false);
  const [lastSyncedAt, setLastSyncedAt] = useState<string | null>(null);
  const currentSyncRef = useRef<Promise<void> | null>(null);

  const syncNow = useCallback(async () => {
    if (!token || !isAuthenticated) {
      return;
    }

    if (activeSync) {
      return activeSync;
    }

    const pending = (async () => {
      setIsSyncing(true);
      try {
        await runSyncCycle();
        setLastSyncedAt(new Date().toISOString());
        await queryClient.invalidateQueries({ queryKey: ["notes"] });
        await queryClient.invalidateQueries({ queryKey: ["folders"] });
      } finally {
        setIsSyncing(false);
        activeSync = null;
        currentSyncRef.current = null;
      }
    })();

    activeSync = pending;
    currentSyncRef.current = pending;
    return pending;
  }, [token, isAuthenticated, queryClient]);

  useEffect(() => {
    if (!auto) return;
    void syncNow();
  }, [auto, syncNow]);

  useEffect(() => {
    if (!auto) return;

    const interval = setInterval(() => {
      void syncNow();
    }, SYNC_INTERVAL_MS);

    return () => {
      clearInterval(interval);
    };
  }, [auto, syncNow]);

  return {
    isSyncing,
    lastSyncedAt,
    syncNow,
  };
}

