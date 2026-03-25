import "@/theme/global.css";
import "react-native-gesture-handler";
import React, { useEffect, useState } from "react";
import { Platform, View } from "react-native";
import { StatusBar } from "expo-status-bar";
import { SafeAreaProvider } from "react-native-safe-area-context";
import { GestureHandlerRootView } from "react-native-gesture-handler";
import { QueryClientProvider } from "@tanstack/react-query";
import * as NavigationBar from "expo-navigation-bar";
import * as SplashScreen from "expo-splash-screen";

SplashScreen.preventAutoHideAsync();

import { queryClient } from "@/api/queryClient";
import { RootNavigator } from "@/navigation";
import { initializeLocalDatabase } from "@/db";
import { authStorage } from "@/utils/authStorage";
import { useAuthStore } from "@/stores/authStore";

export default function App() {
  const [isReady, setIsReady] = useState(false);

  useEffect(() => {
    async function bootstrap() {
      try {
        await initializeLocalDatabase();
        const token = await authStorage.getToken();
        if (token) {
          useAuthStore.getState().rehydrate(token);
        }
      } finally {
        setIsReady(true);
        await SplashScreen.hideAsync();
      }

      if (Platform.OS === "android") {
        void NavigationBar.setButtonStyleAsync("light");
      }
    }

    void bootstrap();
  }, []);

  if (!isReady) {
    return <View style={{ flex: 1, backgroundColor: "#252525" }} />;
  }

  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
      <QueryClientProvider client={queryClient}>
        <SafeAreaProvider>
          <RootNavigator />
          <StatusBar style="light" backgroundColor="#252525" />
        </SafeAreaProvider>
      </QueryClientProvider>
    </GestureHandlerRootView>
  );
}
