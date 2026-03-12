import { useCallback, useEffect, useRef, useState } from "react";
import { useNetInfo } from "@react-native-community/netinfo";
import { useQueryClient } from "@tanstack/react-query";

import { runSyncCycle } from "@/db";
import { useAuthStore } from "@/stores/authStore";

const SYNC_INTERVAL_MS = 15_000;
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
        const nextSyncAt = await runSyncCycle(null);
        setLastSyncedAt(nextSyncAt);
        await Promise.all([
          queryClient.invalidateQueries({ queryKey: ["notes"] }),
          queryClient.invalidateQueries({ queryKey: ["folders"] }),
          queryClient.invalidateQueries({ queryKey: ["tasks"] }),
          queryClient.refetchQueries({ queryKey: ["notes"] }),
          queryClient.refetchQueries({ queryKey: ["folders"] }),
          queryClient.refetchQueries({ queryKey: ["tasks"] }),
        ]);
      } catch (error) {
        console.error("Sync failed:", error);
      } finally {
        setIsSyncing(false);
        globalSyncPromise = null;
        activeSyncRef.current = null;
      }
    })();

    globalSyncPromise = pending;
    activeSyncRef.current = pending;
    return pending;
  }, [token, isAuthenticated, netInfo.isConnected, queryClient, lastSyncedAt]);

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
