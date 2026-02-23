export type ApiErrorPayload = {
  message?: string;
  error?: string;
};

export type ApiError = {
  status?: number;
  message: string;
  raw?: unknown;
};
