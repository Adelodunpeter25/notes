import { create } from "zustand";
import { persist, createJSONStorage } from "zustand/middleware";
import AsyncStorage from "@react-native-async-storage/async-storage";

import type { AuthUser } from "@shared/auth";

type AuthState = {
    token: string | null;
    user: AuthUser | null;
    isAuthenticated: boolean;
    hasHydrated: boolean;
    setAuth: (payload: { token: string; user: AuthUser }) => void;
    clearAuth: () => void;
    setHasHydrated: (state: boolean) => void;
};

export const useAuthStore = create<AuthState>()(
    persist(
        (set) => ({
            token: null,
            user: null,
            isAuthenticated: false,
            hasHydrated: false,
            setAuth: ({ token, user }) => {
                set({ token, user, isAuthenticated: true });
            },
            clearAuth: () => {
                set({ token: null, user: null, isAuthenticated: false });
            },
            setHasHydrated: (state) => set({ hasHydrated: state }),
        }),
        {
            name: "auth-storage",
            storage: createJSONStorage(() => AsyncStorage),
            onRehydrateStorage: () => (state) => {
                state?.setHasHydrated(true);
            },
        }
    )
);
