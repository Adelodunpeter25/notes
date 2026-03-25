import { useMutation } from "@tanstack/react-query";

import type { AuthResponse, LoginPayload, SignupPayload } from "@shared/auth";
import { apiClient } from "@/api/apiClient";
import { useAuthStore } from "@/stores/authStore";

export function useSignupMutation() {
  const setAuth = useAuthStore((state) => state.setAuth);

  return useMutation({
    mutationFn: (payload: SignupPayload) =>
      apiClient.post<AuthResponse, SignupPayload>("/auth/signup", payload),
    onSuccess: (data) => {
      setAuth({ token: data.token, user: data.user });
    },
  });
}

export function useLoginMutation() {
  const setAuth = useAuthStore((state) => state.setAuth);

  return useMutation({
    mutationFn: (payload: LoginPayload) =>
      apiClient.post<AuthResponse, LoginPayload>("/auth/login", payload),
    onSuccess: (data) => {
      setAuth({ token: data.token, user: data.user });
    },
  });
}

export function useLogout() {
  const clearAuth = useAuthStore((state) => state.clearAuth);

  return {
    logout: clearAuth,
  };
}
