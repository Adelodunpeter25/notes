import { create } from "zustand";

import type { AuthUser } from "@shared/auth";
import { authStorage } from "@/services";

type AuthState = {
  token: string | null;
  user: AuthUser | null;
  isAuthenticated: boolean;
  setAuth: (payload: { token: string; user: AuthUser }) => void;
  clearAuth: () => void;
};

export const useAuthStore = create<AuthState>((set) => {
  const token = authStorage.getToken();

  return {
    token,
    user: null,
    isAuthenticated: Boolean(token),
    setAuth: ({ token: nextToken, user }) => {
      authStorage.setToken(nextToken);
      set({ token: nextToken, user, isAuthenticated: true });
    },
    clearAuth: () => {
      authStorage.clearToken();
      set({ token: null, user: null, isAuthenticated: false });
    },
  };
});
