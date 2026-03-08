import { useCallback, useEffect, useRef, useState } from "react";
import { useNetInfo } from "@react-native-community/netinfo";
import { useQueryClient } from "@tanstack/react-query";

import { runSyncCycle } from "@/db";
import { useAuthStore } from "@/stores/authStore";

const SYNC_INTERVAL_MS = 10_000;
let globalSyncPromise: Promise<void> | null = null;

export function useSync(options?: { auto?: boolean }) {
  const auto = options?.auto ?? true;
  const token = useAuthStore((state) => state.token);
  const isAuthenticated = useAuthStore((state) => state.isAuthenticated);
  const netInfo = useNetInfo();
  const queryClient = useQueryClient();
  const [isSyncing, setIsSyncing] = useState(false);
  const [lastSyncedAt, setLastSyncedAt] = useState<string | null>(null);
  const activeSyncRef = useRef<Promise<void> | null>(null);

  const syncNow = useCallback(async () => {
    const canSync = Boolean(token) && (isAuthenticated || Boolean(token)) && netInfo.isConnected !== false;
    if (!canSync) {
      return;
    }

    if (globalSyncPromise) {
      return globalSyncPromise;
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
        globalSyncPromise = null;
        activeSyncRef.current = null;
      }
    })();

    globalSyncPromise = pending;
    activeSyncRef.current = pending;
    return pending;
  }, [token, isAuthenticated, netInfo.isConnected, queryClient]);

  useEffect(() => {
    if (!auto) {
      return;
    }
    void syncNow();
  }, [auto, syncNow]);

  useEffect(() => {
    if (!auto) {
      return;
    }
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
