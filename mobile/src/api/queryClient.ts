import { QueryClient, focusManager, onlineManager } from "@tanstack/react-query";
import { AppState, type AppStateStatus, Platform } from "react-native";
import NetInfo from "@react-native-community/netinfo";

onlineManager.setEventListener((setOnline) => {
    return NetInfo.addEventListener((state) => {
        setOnline(!!state.isConnected);
    });
});

export const queryClient = new QueryClient({
    defaultOptions: {
        queries: {
            staleTime: 0,
            gcTime: 0,
            retry: 1,
            networkMode: "always",
            refetchOnWindowFocus: Platform.OS === 'web',
            refetchOnMount: "always",
            refetchOnReconnect: true,
        },
        mutations: {
            retry: 0,
            networkMode: "always",
        },
    },
});

// Handle refetch on app focus for mobile
function onAppStateChange(status: AppStateStatus) {
    if (Platform.OS !== "web") {
        focusManager.setFocused(status === "active");
    }
}

AppState.addEventListener("change", onAppStateChange);
