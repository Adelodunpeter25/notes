import { Platform } from "react-native";
import axios, {
  AxiosError,
  type AxiosInstance,
  type AxiosRequestConfig,
  type AxiosResponse,
} from "axios";
import { useAuthStore } from "@/stores/authStore";

import type { ApiError, ApiErrorPayload } from "@shared/api";

// For Android emulator, use IP address of your computer instead of localhost
// For real devices, replace with your computer's local IP (e.g., 192.168.1.5)
const API_BASE_URL = __DEV__
  ? Platform.OS === "android"
    ? "http://10.0.2.2:8000/api"
    : "http://192.168.1.107:8000/api"
  : "https://notes-api.scaleitpro.com/api";

const instance: AxiosInstance = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    "Content-Type": "application/json",
  },
  timeout: 15000,
});

instance.interceptors.request.use((config) => {
  const token = useAuthStore.getState().token;
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

instance.interceptors.response.use(
  (response) => response,
  async (error: AxiosError<ApiErrorPayload>) => {
    if (error.response?.status === 401) {
      useAuthStore.getState().clearAuth();
    }

    const normalizedError: ApiError = {
      status: error.response?.status,
      message:
        error.response?.data?.message ||
        error.response?.data?.error ||
        error.message ||
        "Request failed",
      raw: error,
    };

    return Promise.reject(normalizedError);
  },
);

const unwrapResponse = <T>(response: AxiosResponse<T>): T => response.data;

export const apiClient = {
  instance,
  get: <T>(url: string, config?: AxiosRequestConfig): Promise<T> =>
    instance.get<T>(url, config).then(unwrapResponse),
  post: <T, B = unknown>(
    url: string,
    body?: B,
    config?: AxiosRequestConfig,
  ): Promise<T> => instance.post<T>(url, body, config).then(unwrapResponse),
  put: <T, B = unknown>(
    url: string,
    body?: B,
    config?: AxiosRequestConfig,
  ): Promise<T> => instance.put<T>(url, body, config).then(unwrapResponse),
  patch: <T, B = unknown>(
    url: string,
    body?: B,
    config?: AxiosRequestConfig,
  ): Promise<T> => instance.patch<T>(url, body, config).then(unwrapResponse),
  delete: <T>(url: string, config?: AxiosRequestConfig): Promise<T> =>
    instance.delete<T>(url, config).then(unwrapResponse),
};

export { API_BASE_URL };
