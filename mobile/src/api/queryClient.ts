import { QueryClient, focusManager, onlineManager } from "@tanstack/react-query";
import { AppState, type AppStateStatus, Platform } from "react-native";
import NetInfo from "@react-native-community/netinfo";
import AsyncStorage from "@react-native-async-storage/async-storage";
import { createAsyncStoragePersister } from "@tanstack/query-async-storage-persister";
import type { Note, UpdateNotePayload, CreateNotePayload } from "@shared/notes";
import { apiClient } from "@/api/apiClient";

onlineManager.setEventListener((setOnline) => {
    return NetInfo.addEventListener((state) => {
        setOnline(!!state.isConnected);
    });
});

export const queryClient = new QueryClient({
    defaultOptions: {
        queries: {
            staleTime: 1000 * 60 * 60 * 24 * 7, // 1 week
            gcTime: 1000 * 60 * 60 * 24 * 7, // 1 week
            retry: 1,
            refetchOnWindowFocus: Platform.OS === 'web',
            refetchOnMount: "always", // always sync with server when screens mount
            refetchOnReconnect: true,
        },
        mutations: {
            retry: 0,
        },
    },
});

export const asyncStoragePersister = createAsyncStoragePersister({
    storage: AsyncStorage,
});

// Handle refetch on app focus for mobile
function onAppStateChange(status: AppStateStatus) {
    if (Platform.OS !== "web") {
        focusManager.setFocused(status === "active");
    }
}

AppState.addEventListener("change", onAppStateChange);

queryClient.setMutationDefaults(['updateNote'], {
    mutationFn: ({ noteId, payload }: { noteId: string; payload: UpdateNotePayload }) =>
        apiClient.patch<Note, UpdateNotePayload>(`/notes/${noteId}`, payload),
    retry: 3,
});

queryClient.setMutationDefaults(['createNote'], {
    mutationFn: (payload: CreateNotePayload) => apiClient.post<Note, CreateNotePayload>("/notes/", payload),
    retry: 3,
});
