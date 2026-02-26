import "@/theme/global.css";
import "react-native-gesture-handler";
import React, { useEffect } from "react";
import { Platform } from "react-native";
import { StatusBar } from "expo-status-bar";
import { SafeAreaProvider } from "react-native-safe-area-context";
import { GestureHandlerRootView } from "react-native-gesture-handler";
import { PersistQueryClientProvider } from "@tanstack/react-query-persist-client";
import * as NavigationBar from "expo-navigation-bar";

import { queryClient, asyncStoragePersister } from "@/api/queryClient";
import { RootNavigator } from "@/navigation";

export default function App() {
  useEffect(() => {
    if (Platform.OS === "android") {
      NavigationBar.setBackgroundColorAsync("#252525");
      NavigationBar.setButtonStyleAsync("light");
    }
  }, []);

  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
      <PersistQueryClientProvider
        client={queryClient}
        persistOptions={{ persister: asyncStoragePersister }}
      >
        <SafeAreaProvider>
          <RootNavigator />
          <StatusBar style="light" backgroundColor="#252525" />
        </SafeAreaProvider>
      </PersistQueryClientProvider>
    </GestureHandlerRootView>
  );
}
