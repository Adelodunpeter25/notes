import { QueryClient } from "@tanstack/react-query";
import { createSyncStoragePersister } from "@tanstack/query-sync-storage-persister";

export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 1000 * 60 * 60 * 24 * 7, // 1 week
      gcTime: 1000 * 60 * 60 * 24 * 7,    // 1 week
      refetchOnWindowFocus: false,
      refetchOnMount: true, // Allow refetching on mount to sync with server
      refetchOnReconnect: true,
      retry: 1,
    },
    mutations: {
      retry: 0,
    },
  },
});

export const persister = createSyncStoragePersister({
  storage: window.localStorage,
});
