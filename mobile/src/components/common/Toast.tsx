import React, { useEffect, useRef } from "react";
import { Text, View } from "react-native";
import Animated, { FadeInDown, FadeOutDown, useSharedValue, withTiming, useAnimatedStyle } from "react-native-reanimated";

export type ToastVariant = "success" | "error" | "info";

export interface ToastMessage {
  id: string;
  message: string;
  variant?: ToastVariant;
  duration?: number; // ms, default 3000
}

interface ToastItemProps {
  toast: ToastMessage;
  onDismiss: (id: string) => void;
}

const VARIANT_STYLES: Record<ToastVariant, { container: string; text: string }> = {
  success: { container: "bg-green-900/90 border border-green-600/40", text: "text-green-200" },
  error:   { container: "bg-red-900/90 border border-red-600/40",   text: "text-red-200" },
  info:    { container: "bg-zinc-800/90 border border-white/10",    text: "text-zinc-100" },
};

function ToastItem({ toast, onDismiss }: ToastItemProps) {
  const { container, text } = VARIANT_STYLES[toast.variant ?? "info"];
  const timerRef = useRef<ReturnType<typeof setTimeout>>();

  useEffect(() => {
    timerRef.current = setTimeout(() => {
      onDismiss(toast.id);
    }, toast.duration ?? 3000);
    return () => clearTimeout(timerRef.current);
  }, [toast.id, toast.duration, onDismiss]);

  return (
    <Animated.View
      entering={FadeInDown.duration(250).springify().damping(18)}
      exiting={FadeOutDown.duration(200)}
      className={`mb-2 rounded-xl px-4 py-3 shadow-lg ${container}`}
    >
      <Text className={`text-sm font-medium ${text}`}>{toast.message}</Text>
    </Animated.View>
  );
}

interface ToastContainerProps {
  toasts: ToastMessage[];
  onDismiss: (id: string) => void;
}

export function ToastContainer({ toasts, onDismiss }: ToastContainerProps) {
  if (toasts.length === 0) return null;
  return (
    <View className="absolute bottom-20 left-4 right-4 z-50 items-center" pointerEvents="none">
      {toasts.map((t) => (
        <ToastItem key={t.id} toast={t} onDismiss={onDismiss} />
      ))}
    </View>
  );
}
