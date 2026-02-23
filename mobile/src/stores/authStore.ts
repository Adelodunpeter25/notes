import { create } from "zustand";

import type { AuthUser } from "@shared/auth";
import { authStorage } from "@/utils/authStorage";

type AuthState = {
    token: string | null;
    user: AuthUser | null;
    isAuthenticated: boolean;
    setAuth: (payload: { token: string; user: AuthUser }) => void;
    clearAuth: () => void;
};

export const useAuthStore = create<AuthState>((set) => ({
  token: null,
  user: null,
  isAuthenticated: false,
  setAuth: ({ token, user }) => {
    void authStorage.setToken(token);
    set({ token, user, isAuthenticated: true });
  },
  clearAuth: () => {
    void authStorage.clearToken();
    set({ token: null, user: null, isAuthenticated: false });
  },
}));
