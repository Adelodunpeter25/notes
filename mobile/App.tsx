import "@/theme/global.css";
import "react-native-gesture-handler";
import React, { useEffect, useState } from "react";
import { Platform, View } from "react-native";
import { StatusBar } from "expo-status-bar";
import { SafeAreaProvider } from "react-native-safe-area-context";
import { GestureHandlerRootView } from "react-native-gesture-handler";
import { PersistQueryClientProvider } from "@tanstack/react-query-persist-client";
import * as NavigationBar from "expo-navigation-bar";
import * as SplashScreen from "expo-splash-screen";

SplashScreen.preventAutoHideAsync();

import { queryClient, asyncStoragePersister } from "@/api/queryClient";
import { RootNavigator } from "@/navigation";
import { initializeLocalDatabase } from "@/db";

export default function App() {
  const [isReady, setIsReady] = useState(false);

  useEffect(() => {
    async function bootstrap() {
      try {
        await initializeLocalDatabase();
      } finally {
        setIsReady(true);
        await SplashScreen.hideAsync();
      }

      if (Platform.OS === "android") {
        NavigationBar.setBackgroundColorAsync("#252525");
        NavigationBar.setButtonStyleAsync("light");
      }
    }

    void bootstrap();
  }, []);

  if (!isReady) {
    return <View style={{ flex: 1, backgroundColor: "#252525" }} />;
  }

  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
      <PersistQueryClientProvider
        client={queryClient}
        persistOptions={{
          persister: asyncStoragePersister,
          dehydrateOptions: {
            shouldDehydrateMutation: () => true,
          },
        }}
      >
        <SafeAreaProvider>
          <RootNavigator />
          <StatusBar style="light" backgroundColor="#252525" />
        </SafeAreaProvider>
      </PersistQueryClientProvider>
    </GestureHandlerRootView>
  );
}
