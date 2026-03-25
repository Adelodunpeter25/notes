import { QueryClient } from "@tanstack/react-query";

export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 0,
      gcTime: 0,
      networkMode: "always",
      refetchOnWindowFocus: false,
      refetchOnMount: "always",
      refetchOnReconnect: true,
      retry: 1,
    },
    mutations: {
      retry: 0,
      networkMode: "always",
    },
  },
});
