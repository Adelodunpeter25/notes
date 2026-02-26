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

import type { Note, UpdateNotePayload, CreateNotePayload } from "@shared/notes";
import { apiClient } from "@/services/apiClient";

queryClient.setMutationDefaults(['updateNote'], {
  mutationFn: ({ noteId, payload }: { noteId: string; payload: UpdateNotePayload }) =>
    apiClient.patch<Note, UpdateNotePayload>(`/notes/${noteId}`, payload),
  retry: 3,
});

queryClient.setMutationDefaults(['createNote'], {
  mutationFn: (payload: CreateNotePayload) => apiClient.post<Note, CreateNotePayload>("/notes/", payload),
  retry: 3,
});
