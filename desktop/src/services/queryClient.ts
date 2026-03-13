import { QueryClient } from "@tanstack/react-query";
import { createSyncStoragePersister } from "@tanstack/query-sync-storage-persister";

export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 0, // Always consider data stale so invalidation triggers refetch
      gcTime: 1000 * 60 * 60 * 24,    // 24 hours
      refetchOnWindowFocus: false,
      refetchOnMount: "always", // Always sync with server when screens mount
      refetchOnReconnect: true,
      retry: 1,
    },
    mutations: {
      retry: 0,
      networkMode: "always",
    },
  },
});

export const persister = createSyncStoragePersister({
  storage: window.localStorage,
});
