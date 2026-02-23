import "@/theme/global.css";
import "react-native-gesture-handler";
import React, { useEffect } from "react";
import { View, Text, Platform } from "react-native";
import { StatusBar } from "expo-status-bar";
import { SafeAreaProvider, SafeAreaView } from "react-native-safe-area-context";
import { GestureHandlerRootView } from "react-native-gesture-handler";
import { QueryClientProvider } from "@tanstack/react-query";
import * as NavigationBar from "expo-navigation-bar";
import { cssInterop } from "nativewind";

import { queryClient } from "@/api/queryClient";

// Fix for className on SafeAreaView
cssInterop(SafeAreaView, { className: "style" });

export default function App() {
  useEffect(() => {
    if (Platform.OS === "android") {
      NavigationBar.setBackgroundColorAsync("#252525");
      NavigationBar.setButtonStyleAsync("light");
    }
  }, []);

  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
      <QueryClientProvider client={queryClient}>
        <SafeAreaProvider>
          <SafeAreaView className="flex-1 bg-surface">
            <View className="flex-1 items-center justify-center bg-background">
              <Text className="text-3xl font-bold text-accent">
                Notes App
              </Text>
              <Text className="mt-2 text-textMuted">
                Mobile development started!
              </Text>
            </View>
            <StatusBar style="light" backgroundColor="#252525" />
          </SafeAreaView>
        </SafeAreaProvider>
      </QueryClientProvider>
    </GestureHandlerRootView>
  );
}
