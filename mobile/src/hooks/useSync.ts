import { useCallback, useEffect, useRef, useState } from "react";
import { useNetInfo } from "@react-native-community/netinfo";
import { useQueryClient } from "@tanstack/react-query";

import { runSyncCycle } from "@/db";
import { useAuthStore } from "@/stores/authStore";

export function useSync() {
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

    if (activeSyncRef.current) {
      return activeSyncRef.current;
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
        activeSyncRef.current = null;
      }
    })();

    activeSyncRef.current = pending;
    return pending;
  }, [token, isAuthenticated, netInfo.isConnected, queryClient]);

  useEffect(() => {
    void syncNow();
  }, [syncNow]);

  useEffect(() => {
    const interval = setInterval(() => {
      void syncNow();
    }, 10_000);

    return () => {
      clearInterval(interval);
    };
  }, [syncNow]);

  return {
    isSyncing,
    lastSyncedAt,
    syncNow,
  };
}

