import axios, {
  AxiosError,
  type AxiosInstance,
  type AxiosRequestConfig,
  type AxiosResponse,
} from "axios";

import type { ApiError, ApiErrorPayload } from "@shared/api";

const API_BASE_URL = import.meta.env.PROD
  ? "https://notes-api.pxxl.click/api"
  : import.meta.env.VITE_API_BASE_URL?.trim() || "http://localhost:8000/api";

const AUTH_TOKEN_STORAGE_KEY = "notes_access_token";

const instance: AxiosInstance = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    "Content-Type": "application/json",
  },
  timeout: 15000,
});

instance.interceptors.request.use((config) => {
  const token = localStorage.getItem(AUTH_TOKEN_STORAGE_KEY);
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

instance.interceptors.response.use(
  (response) => response,
  (error: AxiosError<ApiErrorPayload>) => {
    if (error.response?.status === 401) {
      localStorage.removeItem(AUTH_TOKEN_STORAGE_KEY);
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

export const authStorage = {
  tokenKey: AUTH_TOKEN_STORAGE_KEY,
  getToken: (): string | null => localStorage.getItem(AUTH_TOKEN_STORAGE_KEY),
  setToken: (token: string): void => localStorage.setItem(AUTH_TOKEN_STORAGE_KEY, token),
  clearToken: (): void => localStorage.removeItem(AUTH_TOKEN_STORAGE_KEY),
};

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
